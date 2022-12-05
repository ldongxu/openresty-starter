local _M = {}

_M.redis = {
    timeout = 1000,
    max_idle_timeout = 100000,
    pool_size = 10,
    host =  "127.0.0.1",
    port = 6300,
    password = nil
}

_M.mysql = {
    host = "127.0.0.1",
    port = 3306,
    database = "im_xplatform",
    user = "root",
    password = "123456789",
    charset = "utf8"
}

return _M