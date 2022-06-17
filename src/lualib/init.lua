local process = require "ngx.process"

-- 启用特权进程
local ok, err = process.enable_privileged_agent()
if not ok then
    ngx.log(ngx.ERR, "enables privileged agent failed error:", err)
end

HTTP_METHOD_MAP =
{
    GET = ngx.HTTP_GET
, POST = ngx.HTTP_POST
, HEAD = ngx.HTTP_HEAD
, PUT = ngx.HTTP_PUT
, DELETE = ngx.HTTP_DELETE
, OPTIONS = ngx.HTTP_OPTIONS
, MKCOL = ngx.HTTP_MKCOL
, COPY = ngx.HTTP_COPY
, MOVE = ngx.HTTP_MOVE
, PROPFIND = ngx.HTTP_PROPFIND
, PROPPATCH = ngx.HTTP_PROPPATCH
, LOCK = ngx.HTTP_LOCK
, UNLOCK  = ngx.HTTP_UNLOCK
, PATCH  = ngx.HTTP_PATCH
, TRACE = ngx.HTTP_TRACE
}

cjson = require "cjson"
