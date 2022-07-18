local sse_forward = require("sse_forward")

local function return_client_res(res)
    ngx.status = res.status
    for k, v in pairs(res.header) do
        ngx.header[k] = v
    end
    ngx.say(res.body)
    return ngx.exit(ngx.status)
end

if sse_forward:is_sse_accept() then
    local path = ngx.var.b_scheme .. "://" .. ngx.var.b_host .. ngx.var.b_uri
    sse_forward:sse_req(path)
else
    local start_time = ngx.now()
    local res = ngx.location.capture('/forward',
            { method = HTTP_METHOD_MAP[ngx.req.get_method()],
              args = { target_scheme = ngx.var.b_scheme,
                       target_host = ngx.var.b_host, target_url = ngx.var.b_uri },
              body = ngx.req.get_body_data()
            })

    local forwardurl = ngx.var.b_host .. ngx.var.b_uri
    ngx.update_time()
    local cost = (ngx.now() * 1000 - start_time * 1000)
    ngx.log(ngx.NOTICE, " ======= forward=", forwardurl, ", status=", res.status, ", cost=", cost, ", ", ngx.req.get_method(), "|", HTTP_METHOD_MAP[ngx.req.get_method()])
    return return_client_res(res)
end


