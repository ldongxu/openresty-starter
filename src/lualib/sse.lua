local http = require "resty.http" -- https://github.com/ledgetech/lua-resty-http

local _M = {_VERSION = '0.0.2'}
_M.__index = _M

-- variable caching (https://www.cryptobells.com/properly-scoping-lua-nginx-modules-ngx-ctx/)
local str_find   = string.find
local str_sub    = string.sub
local str_gfind  = string.gfind or string.gmatch -- http://lua-users.org/lists/lua-l/2013-04/msg00117.html
local tbl_insert = table.insert
local ngx_log = ngx.log
local ngx_ERR = ngx.ERR

local user_agent_header = "lua-resty-sse-v ".._M._VERSION

local function str_ltrim(s) -- remove leading whitespace from string.
  return (s:gsub("^%s*", ""))
end

local function str_split(str, delim)
    local result    = {}
    local pat       = "(.-)"..delim.."()"
    local lastPos   = 1

    for part, pos in str_gfind(str, pat) do
        tbl_insert(result, part)
        lastPos = pos
    end -- for
    tbl_insert(result, str_sub(str, lastPos))
    return result
end -- split


-- Returns a new table, recursively copied from the one given.
--
-- @param   table   table to be copied
-- @return  table
local function tbl_copy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == "table" then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[tbl_copy(orig_key)] = tbl_copy(orig_value)
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

function _M.new()
    local httpc, err = http.new()
    if not httpc then return nil, err end
    local that = {httpc=httpc,buffer=''}
    setmetatable(that, _M)
    return that
end -- new

function _M.set_timeout(self, timeout)
    return self.httpc:set_timeout(timeout)
end -- set_timeout

function _M.set_keepalive(self, ...)
    return self.httpc:set_keepalive(...)
end -- set_keepalive

function _M.get_reused_times(self, ...)
    return self.httpc:get_reused_times(...)
end -- get_reused_times

function _M.close(self)
    self.httpc:close()
end -- close

function _M.transfer_encoding_is_chunked(self)
    local headers = self.res.headers
    if self.httpc.transfer_encoding_is_chunked(headers) then
        self.res.headers["Transfer-Encoding"]=nil
    end
end

local function _headers_format_request(headers)
    if type(headers) ~= "table" then headers = {} end

    headers['Accept'] = "text/event-stream"

    if not headers['User-Agent'] then headers['User-Agent'] = user_agent_header end

    return headers
end -- headers_format_request


local function _read_body(self,params)
    local body, err = self.res:read_body()
    if not body then
        self:close()
        return nil, err
    end

    self.res.body = body

    return self.res, nil
end

function _M.request_uri(self, uri, params)
    params = tbl_copy(params or {}) -- Take by value
    if self.httpc.proxy_opts then
        params.proxy_opts = tbl_copy(self.httpc.proxy_opts or {})
    end

    do
        local parsed_uri, err = self.httpc:parse_uri(uri, false)
        if not parsed_uri then
            return nil, err
        end

        local path, query
        params.scheme, params.host, params.port, path, query = unpack(parsed_uri)
        params.path = params.path or path
        params.query = params.query or query
        params.ssl_server_name = params.ssl_server_name or params.host
    end

    do
        local proxy_auth = (params.headers or {})["Proxy-Authorization"]
        if proxy_auth and params.proxy_opts then
            params.proxy_opts.https_proxy_authorization = proxy_auth
            params.proxy_opts.http_proxy_authorization = proxy_auth
        end
    end

    local ok, err = self.httpc:connect(params)
    if not ok then
        return nil, err
    end

    local res, err = self.httpc:request(params)
    if not res then
        self.httpc:close()
        return nil, err
    end

    self.res = res
    local is_sse_resp = self:headers_check_response()
    if not is_sse_resp then
        _read_body(self,params)
    end

    if params.keepalive == false then
        local ok, err = self:close()
        if not ok then
            ngx_log(ngx_ERR, err)
        end

    else
        local ok, err = self:set_keepalive(params.keepalive_timeout, params.keepalive_pool)
        if not ok then
            ngx_log(ngx_ERR, err)
        end

    end
    return self.res, err, is_sse_resp
end -- request_uri



-- It parses until a full frame of an SSE event if found and decoded
local function _parse_sse(buffer)
    local struct         = { event = nil, id = nil, data = {} }
    local struct_started = false
    local frame_break   = str_find(buffer, "\n\n") -- make sure we have at least one frame ini this
    local buffer_lines

    if frame_break ~= nil then
        buffer_lines = str_split(str_sub(buffer, 1, frame_break), "\n") -- get one frame from the buffer and split it into lines
    else
        return nil, buffer, nil
    end -- if

    for _, dat in pairs(buffer_lines) do
        local s1, _ = str_find(dat, ":") -- find where the cut point is

        if s1 and s1 ~= 1 then
            local field = str_sub(dat, 1, s1-1) -- returns "data " from data: hello world
            local value = str_ltrim(str_sub(dat, s1+1)) -- returns "hello world" from data: hello world

            if field then struct_started = true end

            -- for now not checking if the value is already been set
            if     field == "event" then struct.event = value
            elseif field == "id"    then struct.id = value
            elseif field == "data"  then tbl_insert(struct.data, value)
            end -- if
        end -- if
    end -- for

    -- reply back with the rest of the buffer
    buffer = str_sub(buffer, frame_break+2) -- +2 because we want to be on the other side of \n\n

    if struct_started then
        return struct, buffer
    end
    return nil, buffer
end -- parse_sse

local function _struct_sse(self, chunk)
    self.buffer = self.buffer .. chunk

    local frame_break   = str_find(self.buffer, "\n\n") -- make sure we have at least one frame ini this
    local buffer_lines

    if frame_break ~= nil then
        buffer_lines = self.buffer
        self.buffer = str_sub(self.buffer, frame_break+2) -- +2 because we want to be on the other side of \n\n
        return buffer_lines, self.buffer
    else
        return nil, self.buffer, nil
    end -- if
end

function _M.headers_check_response(self)
    -- check to make sure the status code that came back is the coorect range
    if self.res.status < 200 or self.res.status > 299 then
        return nil, "Status Non-200 ("..self.res.status..")"
    end -- if

    -- make sure we got the right content type back in the headers
    local find_mime, _ = str_find(self.res.headers["Content-Type"], "text/event-stream",1,true)
    if find_mime == nil then
        return nil, "Content Type not text/event-stream ("..self.res.headers["Content-Type"]..")"
    end

    return true
end -- headers_check_response

function _M.receive(self)
    local reader = self.res.body_reader

    if not reader then
        -- Most likely HEAD or 304 etc.
        return nil, "no body to be read"
    end

    local chunk, err, struct, parse_err
    repeat
        chunk, err = reader()
        if chunk then
            struct, self.buffer, parse_err = _struct_sse(self,chunk) -- parse the data that is in the buffer
            if parse_err then return struct, parse_err end
        end
    until err or struct or not chunk

    if err then
        self:close()
    end

    return struct, err

end

return _M
