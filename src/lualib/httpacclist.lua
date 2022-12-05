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

return _M

