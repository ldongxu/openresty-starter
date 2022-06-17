#!/bin/bash

readonly PROJECT_PATH=/Users/liudongxu03/Documents/IdeaProjects/openresty-starter
readonly ORIGIN_PATH=${PROJECT_PATH}/origin/
# readonly SRC_PATH=${PROJECT_PATH}/src
readonly OUTPUT_PATH=${PROJECT_PATH}/output
readonly INSTALL_OPENRESTY_NAME="openresty-1.21.4.1"
readonly OPENSSL_NAME="openssl-1.1.1m"
readonly PCRE_NAME="pcre-8.45"
readonly SUFFIX=".tar.gz"
readonly RELEASE_DIR="openresty"

function copy_files() {
    cp -rf $1 $2 || {
        echo "Failed to copy from $1 to $2"
        exit 1
    }
}

function build_openresty() {

    tar xzf ${ORIGIN_PATH}${OPENSSL_NAME}${SUFFIX}
    tar xzf ${ORIGIN_PATH}${INSTALL_OPENRESTY_NAME}${SUFFIX}
    tar xzf ${ORIGIN_PATH}${PCRE_NAME}${SUFFIX}
    cd ${ORIGIN_PATH}${INSTALL_OPENRESTY_NAME}

    mkdir ${OUTPUT_PATH}/${RELEASE_DIR}

    ./configure -j24 --prefix=${OUTPUT_PATH}/${RELEASE_DIR} \
        --with-debug \
        --with-luajit \
        --with-threads \
        --with-stream  \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --with-http_ssl_module  \
        --with-mail  \
        --with-mail_ssl_module \
        --with-http_slice_module  \
        --with-ipv6 \
        --with-http_stub_status_module  \
        --with-http_v2_module \
        --with-poll_module  \
        --with-http_realip_module \
        --with-http_addition_module \
        --with-http_sub_module  \
        --with-http_random_index_module \
        --with-http_gzip_static_module  \
        --with-http_gunzip_module \
        --with-openssl=${ORIGIN_PATH}${OPENSSL_NAME} --with-openssl-opt='no-shared threads -fPIC' \
        --with-pcre --with-pcre=${ORIGIN_PATH}${PCRE_NAME} --with-pcre-jit \
        --with-cc-opt='-DNGX_LUA_USE_ASSERT -DNGX_LUA_ABORT_AT_PANIC -O2 -fPIC -pipe -O0 -Wno-error' \
        || {

        echo "Failed to configure openresty"
        exit 1
    }
    make -j24 || {
        echo "Failed to make openresty"
        exit 1
    }
    make install || {
        echo "Failed to install openresty"
        exit 1
    }
    cd ..
    rm -rf ${INSTALL_OPENRESTY_NAME} ${OPENSSL_NAME} ${PCRE_NAME}
}
function install_third_deps() {
    cd ${OUTPUT_PATH}/${RELEASE_DIR}/bin
    ./opm get ledgetech/lua-resty-http
}

# compile & build
build_openresty
install_third_deps
# 覆盖配置文件
# copy_files ${SRC_PATH}/conf ${OUTPUT_PATH}/${RELEASE_DIR}/nginx
# copy_files ${SRC_PATH}/lualib/ ${OUTPUT_PATH}/${RELEASE_DIR}/nginx/lua

echo "success"

#        --with-file-aio
#        --add-module=../ngx_devel_kit-0.3.1rc1
#        --add-module=../iconv-nginx-module-0.14
#        --add-module=../echo-nginx-module-0.61
#        --add-module=../xss-nginx-module-0.06
#        --add-module=../ngx_coolkit-0.2
#        --add-module=../set-misc-nginx-module-0.32
#        --add-module=../form-input-nginx-module-0.12
#        --add-module=../encrypted-session-nginx-module-0.08
#        --add-module=../drizzle-nginx-module-0.1.11
#        --add-module=../srcache-nginx-module-0.31
#        --add-module=../ngx_lua-0.10.15
#        --add-module=../ngx_lua_upstream-0.07
#        --add-module=../headers-more-nginx-module-0.33
#        --add-module=../array-var-nginx-module-0.05
#        --add-module=../memc-nginx-module-0.19
#        --add-module=../redis2-nginx-module-0.15
#        --add-module=../-nginx-module-0.3.7
#        --add-module=../rds-json-nginx-module-0.15
#        --add-module=../rds-csv-nginx-module-0.09
#        --add-module=../ngx_stream_lua-0.0.7