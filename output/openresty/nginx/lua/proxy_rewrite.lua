
local req_headers = ngx.req.get_headers()
ngx.var.b_uri           = req_headers["im_proxy_location"]
ngx.var.b_host          = req_headers["im_proxy_host"]
ngx.var.b_scheme        = req_headers["im_proxy_scheme"] or ngx.var.scheme
ngx.ctx.cookie          = req_headers["cookie"]
ngx.ctx.im_proxy_cookie = req_headers["im_proxy_cookie"]
ngx.log(ngx.NOTICE,req_headers["x-logid"])
ngx.log(ngx.NOTICE, "=========req-headers=", ngx.req.raw_header())
if not ngx.var.b_uri or not ngx.var.b_host then
    ngx.log(ngx.ERR, "im_proxy_location or im_proxy_host not found")
    return ngx.exit(400)
end

local ua = req_headers['user_agent']

local function get_app_version(user_agent)
    local match,err = ngx.re.match(user_agent,"AppVersion/([^ ]+)","jo")
    if not match then
      return nil
    end
    local v = match[1]
    local start =1
    local len = #v
    local tab = {}
    while start<=len do
        local s = string.find(v,".", start,true)
        if not s then
            local n = string.sub(v,start)
            table.insert(tab,n)
            break
        end
        local num = string.sub(v,start,s-1)
        table.insert(tab,num)
        start = s+1
    end
    return tab
end

local function version_is_old(versionTab, first, second, third)
    for i,v in ipairs(versionTab) do
        local v_num = tonumber(v)
        if i ==1 then
            if v_num < first then
                return true
            end
            if v_num > first then
                return false
            end
        end
        if i == 2 then
            if v_num < second then
                return true
            end
            if v_num > second then
                return false
            end
        end
        if i == 3 then
            if v_num < third then
                return true
            end
            if v_num > third then
                return false
            end
        end
    end
    return false
end

local function is_old_version(user_agent)
    local version = get_app_version(user_agent)
    if not version then
        return false
    end
    return version_is_old(version,8, 18, 0)
end



-- process headers
local a,b = nil,nil
for k, v in pairs(req_headers) do
    repeat
        if k == "im_proxy_location" or k == "im_proxy_scheme" then
            ngx.req.set_header(k, nil)
            break
        end
        -- for cookie ,merge them
        if k == "im_proxy_cookie" then
            -- local new_cookie = ngx.var.http_cookie.."; "..ngx.var.http_im_proxy_cookie
            local new_cookie = ngx.var.http_im_proxy_cookie
            ngx.req.set_header("cookie", new_cookie )
            ngx.req.set_header(k, nil)
            break
        end
        a,b = string.find(k, "im_proxy_", 1, true)
        -- ngx.log(ngx.INFO, "header-key:", k, ",header-value:", v)
        if nil ~= a then
            ngx.req.set_header(string.sub(k,a+b) , v)
            ngx.req.set_header(k, nil)
        end
    until true
end

--ngx.ctx.deviceid = ngx.var.cookie_device_id
req_headers = ngx.req.get_headers()
ngx.log(ngx.NOTICE, "http_host=", ngx.var.http_host, ",http_method=", ngx.var.request_method, "|", ngx.req.get_method(),
        ",host=", ngx.var.host,",bscheme=", ngx.var.b_scheme,
        ",bhost=",ngx.var.b_host, ",buri=", ngx.var.b_uri,
        ",deviceid=",ngx.ctx.deviceid )
       --  ",up-headers=", dump(req_headers))

