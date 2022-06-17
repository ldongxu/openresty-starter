#!/bin/sh

readonly PROJECT_PATH=/Users/liudongxu03/Documents/IdeaProjects/openresty-starter
readonly SRC_PATH=${PROJECT_PATH}/src
readonly OUTPUT_PATH=${PROJECT_PATH}/output
readonly RELEASE_DIR="openresty"

function copy_files() {
    cp -rf $1 $2 || {
        echo "Failed to copy from $1 to $2"
        exit 1
    }
}
rm -rf ${OUTPUT_PATH}/${RELEASE_DIR}/nginx/lua
# 覆盖配置文件
copy_files ${SRC_PATH}/conf ${OUTPUT_PATH}/${RELEASE_DIR}/nginx
copy_files ${SRC_PATH}/lualib/ ${OUTPUT_PATH}/${RELEASE_DIR}/nginx/lua
copy_files ${SRC_PATH}/html ${OUTPUT_PATH}/${RELEASE_DIR}/nginx


DESC="nginx daemon"
NAME=nginx

NGX_ROOT=${OUTPUT_PATH}/${RELEASE_DIR}
NGX_PATH=${NGX_ROOT}/nginx
DAEMON=${NGX_PATH}/sbin/nginx
CONFIGFILE=${NGX_PATH}/conf/nginx.conf
PIDFILE=${NGX_PATH}/conf/$NAME.pid
echo "pid_file: $PIDFILE "

cmd="$DAEMON -p $NGX_PATH -c $CONFIGFILE "

do_start() {
	op=""
	$cmd $op
}

do_stop() {
	#kill -INT `cat $PIDFILE` || echo -n "nginx not running"
	# 快速关闭
	op="-s stop"
	$cmd $op
}

do_reload() {
	op="-s reload"
	$cmd $op
}

do_check() {
	op="-t"
	$cmd $op 
}

do_restart() {
	op="-s quit"
	$cmd $op
	sleep 1
	op=""
	$cmd $op
}

do_reopen() {
	op="-s repoen"
	$cmd $op
}

do_docker() {
	$cmd  -g  "daemon off;"
}

case "$1" in
start)
	echo  "Starting $DESC: $NAME"
	do_start
	;;
stop)
	echo  "Stopping $DESC: $NAME"
	do_stop
	;;
reload|graceful)
	echo  "Reloading $DESC configuration..."
	do_reload
	;;
restart)
	echo  "Restarting $DESC: $NAME"
	do_restart
	;;
chk|check)
	echo  "Checking $DESC: $NAME config file..."
	do_check
	;;
reopen)
	echo  "reopen logs $DESC: $NAME ..."
	do_reopen
	;;
docker)
	echo  "start in docker env $DESC: $NAME ..."
	do_docker
	;;
*)
	echo "Usage: $SCRIPTNAME {start|stop|reload|restart|chk|check|reopen|docker}" >&2
	exit 3
	;;
esac

exit 0
