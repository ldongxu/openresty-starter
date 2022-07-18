local sse = require("sse")

local _M = {}

local function my_cleanup()
    -- custom cleanup work goes here, like cancelling a pending DB transaction
    -- now abort all the "light threads" running in the current request handler
    -- need config lua_check_client_abort on;
    ngx.log(ngx.NOTICE, "onabort exit 499")
    ngx.exit(499)
end

function _M.is_sse_accept(self)
    local req_headers = ngx.req.get_headers()
    local accept = req_headers['Accept']
    return accept and string.find(accept, "text/event-stream", 1, true)
end

function _M.sse_req(self, req_path)
    local ok, err0 = ngx.on_abort(my_cleanup)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err0)
    end

    local conn, err = sse.new()
    if not conn then
        ngx.log(ngx.ERR, "failed to get connection: ", err)
        return
    end
    --conn:set_timeout(50000)
    local req_headers = ngx.req.get_headers()
    ngx.log(ngx.NOTICE, "sse request path=" .. req_path .. ", header=" .. cjson.encode(req_headers))
    local res, err2, is_sse_resp = conn:request_uri(req_path, {
        headers = req_headers,
        ssl_verify = false
    })
    if not res then
        ngx.log(ngx.ERR, "failed to request: ", err2)
        return
    end

    conn:transfer_encoding_is_chunked() --处理 Transfer-Encoding:chunked
    for k, v in pairs(res.headers) do
        ngx.header[k] = v
    end
    ngx.log(ngx.NOTICE,"is sse",is_sse_resp)
    while is_sse_resp
    do
        local event, err3 = conn:receive()
        if err3 then
            ngx.log(ngx.ERR, "sse request over, msg=" .. err3)
            return ngx.exit(ngx.HTTP_OK)
        end
        if event then
            ngx.log(ngx.NOTICE, "sse received success, event=" .. event)
            ngx.print(event)
            ngx.flush()
        end
    end
    ngx.status=res.status
    ngx.say(res.body)
    return ngx.exit(res.status)
end

return _M