local process = require "ngx.process"
local cjson = require("cjson")
cjson.encode_empty_table_as_object(false)

local _M={
    version = 0,
    data = {}
}

function _M:reload(data)
    if not data then
        ngx.log(ngx.ERR,"data is nil, not reload")
        return
    end
    self.version = self.version+1
    self.data = data
    ngx.log(ngx.NOTICE,"process=",process.type(),"-",ngx.worker.id(),", version=",self.version,", data=",cjson.encode(self.data))
end


function _M:get_acclist()
    return self.data
end


function _M:get_acclist_str()
    return cjson.encode(self.data)
end

local function do_acc_check(item, acc_list)
    if not item or item == "" or not acc_list then
        return false
    end
    local in_whitelist = false
    for _, elm in pairs(acc_list)
    do
        if item == elm then
            -- if string.find(item, elm, 1, true) then
            in_whitelist = true
            break
        end
    end
    return in_whitelist
end

function _M:acc_check(item)
    local acc_list = self.data
    if not item or item == "" or not acc_list then
        return false
    end
    local in_whitelist = false
    for _, elm in pairs(acc_list)
    do
        if item == elm then
            -- if string.find(item, elm, 1, true) then
            in_whitelist = true
            break
        end
    end
    return in_whitelist
end

return _M

