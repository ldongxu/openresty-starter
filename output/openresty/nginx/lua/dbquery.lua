-- 引入mysql模块
local mysql = require("resty.mysql")
local db_conf = require("dbconf").mysql
local new_tab = require "table.new"

-- 定义关闭mysql的连接
local function close_db(db)
    if not db then
        return
    end
    db:close()
end

local function execute(sql)
    -- 创建实例
    local db,err = mysql:new()
    if not db then
        ngx.say("new mysql error:", err)
        return
    end
    -- 设置超时时间(毫秒)
    db:set_timeout(1000)
    -- 连接属性定义
    local props = {
        host = db_conf.host,
        port = db_conf.port,
        database = db_conf.database,
        user = db_conf.user,
        password = db_conf.password,
        charset = db_conf.charset
    }
    local conn_res,error = db:connect(props)
    if not conn_res then
        ngx.log(ngx.ERR,"connect to mysql error:",error)
        return close_db(db)
    end
   local res,q_err = db:query(sql)
   db:set_keepalive(10000, 10)
    if not res then
        ngx.log(ngx.ERR,"query error:",q_err,", sql:",sql)
        return nil, q_err
    end
    return res

end

local _M = {}

function _M.query_whitelist()
    local commend = "select host from proxy_whitelist"
    local res,err = execute(commend)
    if not res then
        return nil
    end
    local whitelist = new_tab(#res,0)
    for i, row in ipairs(res) do
        local host = row['host']
        whitelist[i]=host
    end
    return whitelist
end

return _M
