. ./common.sh

INSTALL_DIR="/www/server"
LOCK_DIR="$ROOT/lock"
SRC_DIR="$ROOT/src"
SRC_SUFFIX=".tar.gz"
# dependency of nginx
#PCRE_DOWN="ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre-8.43.tar.gz"
PCRE_DOWN="https://ftp.pcre.org/pub/pcre/pcre-8.43.tar.gz"
PCRE_SRC="pcre-8.43"
PCRE_LOCK="$LOCK_DIR/pcre.lock"
# openresty source
OPENRESTY_VERSION="openresty-1.19.9.1"
OPENRESTY_FILE="$OPENRESTY_VERSION$SRC_SUFFIX"
OPENRESTY_DOWN="https://openresty.org/download/$OPENRESTY_FILE"
OPENRESTY_DIR="$INSTALL_DIR/$OPENRESTY_VERSION"
OPENRESTY_LOCK="$LOCK_DIR/openresty.lock"
# common dependency fo nginx
COMMON_LOCK="$LOCK_DIR/openresty.common.lock"

# openresty install function
function install_openresty {
    [ -f $OPENRESTY_LOCK ] && return
     
    echo "install openresty..."
    cd $SRC_DIR
    [ ! -f $OPENRESTY_FILE ] && wget $OPENRESTY_DOWN
    tar -zxvf $OPENRESTY_FILE
    cd $OPENRESTY_VERSION
    make clean > /dev/null 2>&1
    sed -i 's@CFLAGS="$CFLAGS -g"@#CFLAGS="$CFLAGS -g"@' auto/cc/gcc
    ./configure --user=www --group=www --prefix=$OPENRESTY_DIR
    [ $? != 0 ] && error_exit "openresty configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "openresty make err"
    make install
    [ $? != 0 ] && error_exit "openresty install err"
    mkdir -p $OPENRESTY_DIR/nginx/conf/{vhost,rewrite}
    [ -L $INSTALL_DIR/nginx ] && rm -fr $INSTALL_DIR/nginx
    ln -sf $OPENRESTY_DIR/nginx $INSTALL_DIR/nginx
    ln -sf $OPENRESTY_DIR/nginx/sbin/nginx /usr/local/bin/nginx
    # default web dir
    [ ! -d /www/web ] && mkdir -p /www/web
    [ -d /www/web ] && chown -h www:www /www/web
    # cp default conf and tp rewrite rule 
    cp -f $ROOT/nginx.conf/nginx.conf $OPENRESTY_DIR/nginx/conf/nginx.conf
    cp -f $ROOT/nginx.conf/rule.conf $OPENRESTY_DIR/nginx/conf/rewrite/rule.conf
    if [ $VERS -ge 7 ]; then
        # auto start script for Centos 7 and Centos 8
        cp -f $ROOT/nginx.conf/nginx.init.R7 /usr/lib/systemd/system/nginxd.service
        systemctl daemon-reload
        systemctl start nginxd.service
        # auto start when start system 
        systemctl enable nginxd.service
    else
        # auto start script for Centos 6
        cp -f $ROOT/nginx.conf/nginx.init.R6 /etc/init.d/nginxd
        chmod +x /etc/init.d/nginxd
        # auto start when start system
        chkconfig --add nginxd
        chkconfig --level 35 nginxd on
        service nginxd start
    fi
    
    echo  
    echo "install openresty complete."
    touch $OPENRESTY_LOCK
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

# add nginx third module
function add_module {
    echo "install module..."
    cd $SRC_DIR
    git clone http://github.com/wandenberg/nginx-push-stream-module.git
    cd $OPENRESTY_VERSION
    ./configure --user=www --group=www --prefix=$OPENRESTY_DIR \
           --add-module=../nginx-push-stream-module
    [ $? != 0 ] && error_exit "openresty configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "openresty make err"
    make install
    [ $? != 0 ] && error_exit "openresty install err"
    echo  
    echo "add module complete."
}

# install common dependency
# nginx gzip depend zlib zlib-devel
# nginx ssl depend openssl openssl-devel
# nginx image_filter module denpend gd gd-devel
# nginx user:group is www:www
function install_common {
    [ -f $COMMON_LOCK ] && return
    # iptables-services for Centos 7 and Centos 8
    yum install -y sudo wget gcc gcc-c++ make cmake autoconf automake \
        zlib zlib-devel openssl openssl-devel gd gd-devel \
        telnet tcpdump ipset lsof iptables iptables-services
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
    # syn hardware time to system time
    hwclock -w
   
    echo 
    echo "install common dependency complete."
    touch $COMMON_LOCK
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
    install_openresty
}

if [[ $1 = "module" ]]; then
    add_module
else
    start_install
fi
