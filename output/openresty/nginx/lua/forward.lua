local sse = require("sse")

local start_time = ngx.now()
local req_headers = ngx.req.get_headers()
local accept = req_headers['Accept']

local function return_client_res(res)
    ngx.status = res.status
    for k, v in pairs(res.header)  do
        ngx.header[k] = v
    end
    ngx.say(res.body)
    return ngx.exit(ngx.status)
end


if (string.find(accept, "text/event-stream", 1, true)) then
    local function my_cleanup()
        -- custom cleanup work goes here, like cancelling a pending DB transaction
        -- now abort all the "light threads" running in the current request handler
        -- need config lua_check_client_abort on;
        ngx.log(ngx.NOTICE,"onabort exit 499")
        ngx.exit(499)
    end

    local ok, err0 = ngx.on_abort(my_cleanup)
    if not ok then
        ngx.log(ngx.ERR, "failed to register the on_abort callback: ", err0)
    end

    local conn, err = sse.new()
    if not conn then
        ngx.log(ngx.ERR,"failed to get connection: ", err)
        return
    end
    --conn:set_timeout(50000)
    local path =  ngx.var.b_scheme.."://"..ngx.var.b_host..ngx.var.b_uri

    ngx.log(ngx.NOTICE,"sse request path="..path..", header="..cjson.encode(req_headers))
    local res, err2, is_sse_resp = conn:request_uri(path,{
        headers = req_headers,
        ssl_verify = false
    })
    if not res then
        ngx.log(ngx.ERR,"failed to request: ", err2)
        return
    end

    conn:transfer_encoding_is_chunked() --处理 Transfer-Encoding:chunked
    for k, v in pairs(res.headers)  do
        ngx.header[k] = v
    end

    while is_sse_resp
    do
        local event, err3 = conn:receive()
        if err3 then
            ngx.log(ngx.ERR,"sse request over"..err3)
            return ngx.exit(ngx.HTTP_OK)
        end
        if event then
            ngx.log(ngx.NOTICE,"sse received success, event="..event)
            ngx.print(event)
            ngx.flush()
        end
    end
    ngx.say(res.body)
    return ngx.exit(ngx.status)
else
    local res = ngx.location.capture('/forward',
            {   method=HTTP_METHOD_MAP[ngx.req.get_method()],
                args = {target_scheme= ngx.var.b_scheme,
                        target_host = ngx.var.b_host, target_url = ngx.var.b_uri},
                body = ngx.req.get_body_data()
            })

    local forwardurl = ngx.var.b_host .. ngx.var.b_uri
    ngx.update_time()
    local cost = (ngx.now() * 1000-start_time * 1000)
    ngx.log(ngx.NOTICE, " ======= forward=", forwardurl , ", status=", res.status,", cost=", cost  ,", ", ngx.req.get_method(), "|", HTTP_METHOD_MAP[ngx.req.get_method()])
    return return_client_res(res)

end