. ./common.sh

INSTALL_DIR="/www/server"
LOCK_DIR="$ROOT/lock"
SRC_DIR="$ROOT/src"
SRC_SUFFIX=".tar.gz"
# dependency of nginx
PCRE_DOWN="ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.40.tar.gz"
PCRE_SRC="pcre-8.40"
PCRE_LOCK="$LOCK_DIR/pcre.lock"
# nginx source
NGINX_VERSION="nginx-1.16.0"
NGINX_FILE="$NGINX_VERSION$SRC_SUFFIX"
NGINX_DOWN="http://nginx.org/download/$NGINX_FILE"
NGINX_DIR="$INSTALL_DIR/$NGINX_VERSION"
NGINX_LOCK="$LOCK_DIR/nginx.lock"
# common dependency for nginx
COMMON_LOCK="$LOCK_DIR/nginx.common.lock"

# nginx install function
function install_nginx {
    [ -f $NGINX_LOCK ] && return
     
    echo "install nginx..."
    cd $SRC_DIR
    [ ! -f $NGINX_FILE ] && wget $NGINX_DOWN
    tar -zxvf $NGINX_FILE
    cd $NGINX_VERSION
    make clean > /dev/null 2>&1
    sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc
    # configure see : https://nginx.org/en/docs/configure.html
    ./configure --user=www --group=www \
        --prefix=$NGINX_DIR \
        --http-client-body-temp-path=$NGINX_DIR/temp/client_body \
        --http-proxy-temp-path=$NGINX_DIR/temp/proxy \
        --http-fastcgi-temp-path=$NGINX_DIR/temp/fcgi \
        --http-uwsgi-temp-path=$NGINX_DIR/temp/uwsgi \
        --http-scgi-temp-path=$NGINX_DIR/temp/scgi \
        --with-http_stub_status_module \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_ssl_module \
        --with-http_image_filter_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module
    [ $? != 0 ] && error_exit "nginx configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "nginx make err"
    make install
    [ $? != 0 ] && error_exit "nginx install err"
    [ -L $INSTALL_DIR/nginx ] && rm -fr $INSTALL_DIR/nginx
    ln -sf $NGINX_DIR $INSTALL_DIR/nginx
    ln -sf $NGINX_DIR/sbin/nginx /usr/local/bin/nginx
    mkdir -p $INSTALL_DIR/nginx/conf/{vhost,rewrite}
    # for nginx temp
    mkdir -p $NGINX_DIR/temp
    # default web dir
    [ -d /www/web ] && chown -h www:www /www/web
    # cp default conf and tp rewrite rule 
    cp -f $ROOT/nginx.conf/nginx.conf $INSTALL_DIR/nginx/conf/nginx.conf
    cp -f $ROOT/nginx.conf/rule.conf $INSTALL_DIR/nginx/conf/rewrite/rule.conf
    if [ $R7 == 1 ]
    then
        # auto start script for centos7
        cp -f $ROOT/nginx.conf/nginx.init.R7 /usr/lib/systemd/system/nginxd.service
        systemctl daemon-reload
        systemctl start nginxd.service
        # auto start when start system 
        systemctl enable nginxd.service
    else
        # auto start script for centos6
        cp -f $ROOT/nginx.conf/nginx.init.R6 /etc/init.d/nginxd
        chmod +x /etc/init.d/nginxd
        # auto start when start system
        chkconfig --add nginxd
        chkconfig --level 35 nginxd on
        service nginxd start
    fi
    
    echo  
    echo "install nginx complete."
    touch $NGINX_LOCK
}

# pcre install function
# nginx rewrite depend pcre
# pcre_dir=/usr
function install_pcre {
    [ -f $PCRE_LOCK ] && return
    
    echo "install pcre..."
    cd $SRC_DIR
    [ ! -f $PCRE_SRC$SRC_SUFFIX ] && wget $PCRE_DOWN
    tar -zxvf $PCRE_SRC$SRC_SUFFIX
    cd $PCRE_SRC
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "pcre configure err"
    make
    [ $? != 0 ] && error_exit "pcre make err"
    make install
    [ $? != 0 ] && error_exit "pcre install err"
    # refresh active lib
    ldconfig
    cd $SRC_DIR 
    rm -fr $PCRE_SRC
    
    echo
    echo "install pcre complete."
    touch $PCRE_LOCK
}

# install common dependency
# nginx gzip depend zlib zlib-devel
# nginx ssl depend openssl openssl-devel
# nginx image_filter module denpend gd gd-devel
# nginx user:group is www:www
function install_common {
    [ -f $COMMON_LOCK ] && return
    # iptables-services for R7
    yum install -y sudo wget gcc gcc-c++ make cmake autoconf automake \
        zlib zlib-devel openssl openssl-devel gd gd-devel \
        telnet tcpdump ipset lsof iptables iptables-services \
        ntp ntpdate
    [ $? != 0 ] && error_exit "common dependence install err"
    # create user for nginx and php
    #groupadd -g 1000 www > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    #useradd -g 1000 -u 1000 -d /www -s /sbin/nologin www > /dev/null 2>&1
    
    # -U create a group with the same name as the user. so it can instead groupadd and useradd
    useradd -U -d /www -s /sbin/nologin www > /dev/null 2>&1
    # set local timezone
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    # syn system time to sina time
    ntpdate tiger.sina.com.cn
    # syn hardware time to system time
    hwclock -w
   
    echo 
    echo "install common dependency complete."
    touch $COMMON_LOCK
}

# add nginx push stream module
function add_push_stream {
    echo "install push stream module..."
    cd $SRC_DIR
    git clone http://github.com/wandenberg/nginx-push-stream-module.git
    cd $NGINX_VERSION
    ./configure --user=www --group=www \
        --prefix=$NGINX_DIR \
        --http-client-body-temp-path=$NGINX_DIR/temp/client_body \
        --http-proxy-temp-path=$NGINX_DIR/temp/proxy \
        --http-fastcgi-temp-path=$NGINX_DIR/temp/fcgi \
        --http-uwsgi-temp-path=$NGINX_DIR/temp/uwsgi \
        --http-scgi-temp-path=$NGINX_DIR/temp/scgi \
        --with-http_stub_status_module \
        --with-http_gzip_static_module \
        --with-http_realip_module \
        --with-http_ssl_module \
        --with-http_image_filter_module \
        --with-stream \
        --with-stream_realip_module \
        --with-stream_ssl_module \
        --with-stream_ssl_preread_module \
        --add-module=../nginx-push-stream-module
    [ $? != 0 ] && error_exit "nginx configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "nginx make err"
    # don't exec make install
    systemctl stop nginxd
    mv -f $NGINX_DIR/sbin/nginx $NGINX_DIR/sbin/nginx.bak
    cp -f ./objs/nginx $NGINX_DIR/sbin/
    systemctl start nginxd
    
    echo  
    echo "add push stream module complete."
}

# install error function
function error_exit {
    echo 
    echo 
    echo "Install error :$1--------"
    echo 
    exit
}

# start install
function start_install {
    [ ! -d $LOCK_DIR ] && mkdir -p $LOCK_DIR
    install_common
    install_pcre
    install_nginx
}

if [ $1 ]; then
    add_$1
else
    start_install
fi
