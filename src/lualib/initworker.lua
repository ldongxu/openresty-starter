local dbquery = require("dbquery")
local ev = require "events"
local cjson = require("cjson")
local conf = require "httpacclist"
local process = require "ngx.process"

local handler = function(data, event, source, pid)
    ngx.log(ngx.ERR,"received event; source=",source,
            ", event=",event,
            ", data=", cjson.encode(data),
            ", from process ",pid)
    conf:reload(data)
end

ev.register(handler,"httpacclist","reload")

local ok, err = ev.configure {
    shm = "process_events", -- defined by "lua_shared_dict"
    timeout = 2,            -- life time of unique event data in shm
    interval = 1,           -- poll interval (seconds)

    wait_interval = 0.010,  -- wait before retry fetching event data
    wait_max = 0.5,         -- max wait time before discarding event
    shm_retries = 999,      -- retries for shm fragmentation (no memory)
}
if not ok then
    ngx.log(ngx.ERR, "failed to start event system: ", err)
    return
end

local timer_handler = function()
        local whitelist = dbquery.query_whitelist()
        ev.post("httpacclist","reload", whitelist)
        ngx.log(ngx.ERR, "event post,data=", cjson.encode(whitelist))

end
ngx.timer.at(0.1,function()
    local whitelist = dbquery.query_whitelist()
    conf:reload(whitelist)
end
)
if process.type() == "privileged agent"  then
    ngx.timer.every(120,timer_handler)
end


