# openresty-project

## 介绍
openresty开发代理服务，包括http、websocket、SSE。



## 目录说明

origin --- 资源包目录

        -- build.sh  //源码编译脚本

        -- openresty-1.21.4.1.tar.gz  //openresty源码包

        -- openssl-1.1.1m.tar.gz  //依赖的openssl包
        
        -- pcre-8.45.tar.gz  //增加pcre依赖包，macOS升级后系统中缺失pcre包，不能用pcre2，会编译不过


output --- 编译产出目标目录

        -- openresty  //编译产出的根目录，该目录初始情况应该是个空目录，执行build.sh脚本，执行编译后产出不同编译环境的产出。也可以删除该目录原有内容后自行编译产出。



src    --- 开发者开发目录

        -- conf   //nginx配置目录

        -- lualib   //lua代码目录
        
        -- html  //html目录


nginx.sh  --- 启动脚本



## 如何使用

1. 执行/origin/build.sh重新编译安装适合自己系统环境的openresty到/output目录（/output目录下原油内容可以删除）。
2. 到/output/openresty/bin目录，执行`./opm get ledgetech/lua-resty-http`，安装resty-http。
3. 在/src目录下进行开发。/src/conf是nginx配置目录，/src/lualib是开发者自己的lua文件目录。
4. `sh nginx.sh start` 启动服务。

## 使用说明

1.  当前工程里output/openresty目录里是mac系统下的编译产出
2.  build.sh和nginx.sh脚本执行时均会同步src目录下的文件到output/openresty执行目录，conf目录的文件同步到output/openresty/nginx/conf目录，lualib目录的文件会完全同步覆盖到output/openresty/nginx/lua目录。


## SSE代理

### lua-resty-sse
Lua Server Side Events client cosocket driver for OpenResty.

**SSE cosocket实现：sse.lua，使用demo见：forward.lua**

### SSE使用概要:
````
location /sse_proxy {
      lua_check_client_abort on;
      content_by_lua_block {
                local sse = require("sse")

                local function return_client_res(res)
                    ngx.status = res.status
                    for k, v in pairs(res.header)  do
                        ngx.header[k] = v
                    end
                    ngx.say(res.body)
                    return ngx.exit(ngx.status)
                end

                local function my_cleanup()
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
                local path = 'http://127.0.0.1:8080/events/123'
            
                local res, err2, is_sse_resp = conn:request_uri(path,{
                    headers = req_headers,
                    ssl_verify = false
                })
                if not res then
                    ngx.log(ngx.ERR,"failed to request: ", err2)
                    return
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
                        ngx.flush()   -- 一定要flush
                    end
                end
                return return_client_res(res)
      }
}
````

### 体验测试

SSE server测试项目地址：

gitee：[https://gitee.com/liu_dongxu/springboot-demo](https://gitee.com/liu_dongxu/springboot-demo)

github：[https://github.com/ldongxu/springboot_mybatis-starter](https://github.com/ldongxu/springboot_mybatis-starter)


1. `java -jar demo-0.0.1-SNAPSHOT.jar` 启动SSE server。
2. `sh nginx.sh start` 脚本启动openresty。
3. 打开一个终端，`curl -i http://localhost/ssev2`，请求SSE。
4. 打开另一个终端，`curl -i http://localhost:8080/send/123`，从server端推送数据。


````
//curl https时一定需要加上 -k
curl -H 'Accept:text/event-stream' -H 'X-LOGID:12345678' -H "im_proxy_scheme:http" -H 'im_proxy_host:127.0.0.1' -H 'im_proxy_location:/sse/123' 'https://localhost/proxy-123' -i -k
````


## 配置SSL使得Nginx支持HTTPS协议
一、生成私钥(server.key)及crt证书(server.crt)

首先需要创建一个目录来存放SSL证书相关文件
````
$ cd conf/ssl
````
1. 生成server.key

```
$ openssl genrsa -des3 -out server.key 2048
```

以上命令是基于des3算法生成的rsa私钥，在生成私钥时必须输入至少4位的密码。

2. 生成无密码的server.key

```
$ openssl rsa -in server.key -out server.key
```
3. 生成CA的crt
````
$ openssl req -new -x509 -key server.key -out ca.crt -days 3650 
````
4. 基于ca.crt生成csr
````
$ openssl req -new -key server.key -out server.csr
````
命令的执行过程中依次输入国家(CN)、省份(Beijing)、城市(Beijing)、公司(TEST)、部门(test)及邮箱(liudongxu@test.com)等信息。

5. 生成crt（已认证）
````
$ openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey server.key -CAcreateserial -out server.crt
````
二、配置Nginx并支持HTTPS协议

前面我们已经生成的用于支持HTTPS协议的SSL相关证书，接下来我们需要添加Nginx配置使得其能够真正支持HTTPS协议。

支持HTTPS协议的Nginx配置如下所示：

````
server {
    listen                      80;
    server_name                 localhost;
    listen                      443 ssl;
    ssl_certificate             ssl/server.crt;
    ssl_certificate_key         ssl/server.key;
    ssl_session_cache           shared:SSL:1m;
    ssl_session_timeout         5m;
    ssl_protocols               SSLv2 SSLv3 TLSv1.2;
    ssl_ciphers                 HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers   on;
}
````







