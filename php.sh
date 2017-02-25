ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
echo $CPUS
echo $ROOT
INSTALL_DIR="/www/server"
SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
ICONV_SRC="libiconv-1.15"
ICON_LOCK="$LOCK_DIR/iconv.lock"
MHASH_SRC="mhash-0.9.9.9"
MHASH_LOCK="$LOCK_DIR/mhash.lock"
MCRYPT_SRC="libmcrypt-2.5.8"
MCRYPT_LOCK="$LOCK_DIR/mcrypt.lock"
PHP_SRC="php-7.1.2"
PHP_DIR="nginx_$PHP_SRC"
PHP_LOCK="$LOCK_DIR/php.lock"
COMMON_LOCK="$LOCK_DIR/common.lock"

# php7.1.2 install function
# for nginx:
# --enable-fpm --with-fpm-user=www --with-fpm-group=www
# no zend guard loader for php7
function install_php {
    install_libiconv
    install_mhash
    install_mcrypt
    [ -f $PHP_LOCK ] && return
    echo 
    echo "install php..."
    cd $SRC_DIR
    tar -zxvf $PHP_SRC$SRC_SUFFIX
    cd $PHP_SRC
    make clean >/dev/null 2>&1
    ./configure --prefix=$INSTALL_DIR/$PHP_DIR \
        --with-config-file-path=$INSTALL_DIR/$PHP_DIR/etc \
        --enable-mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
        --with-iconv-dir=/usr \
        --with-freetype-dir --with-jpeg-dir \
        --with-png-dir --with-zlib \
        --with-libxml-dir=/usr --enable-xml \
        --disable-rpath \
        --enable-inline-optimization --with-curl \
        --enable-mbregex --enable-mbstring \
        --with-mcrypt=/usr --with-gd \
        --with-xmlrpc --with-gettext \
        --enable-gd-native-ttf --with-openssl \
        --with-mhash --enable-ftp --enable-intl \
        --enable-bcmath --enable-exif --enable-soap \
        --enable-shmop --enable-pcntl \
        --disable-ipv6 --disable-debug \
        --enable-sockets --enable-zip --enable-opcache \
        --enable-fpm --with-fpm-user=www --with-fpm-group=www
    [ $? != 0 ] && error_exit "php configure err"
    make ZEND_EXTRA_LIBS='-liconv' -j $CPUS
    [ $? != 0 ] && error_exit "php make err"
    make install
    [ $? != 0 ] && error_exit "php install err"
    # copy php.ini-production to $PHP_DIR
    cp php.ini-production $INSTALL_DIR/$PHP_DIR/etc/php.ini
    # replace config
    sed -i 's@^short_open_tag = Off@short_open_tag = On@' $INSTALL_DIR/$PHP_DIR/etc/php.ini
    sed -i 's@^;date.timezone.*@date.timezone = Asia/Shanghai@' $INSTALL_DIR/$PHP_DIR/etc/php.ini
    
    echo  
    echo "install php complete."
    touch $PHP_LOCK
}

# libiconv install function
# iconv_dir=/usr
function install_libiconv {
    [ -f $ICONV_LOCK ] && return 
    echo "install libiconv..."
    cd $SRC_DIR
    tar -zxvf $ICONV_SRC$SRC_SUFFIX
    cd $ICONV_SRC
    # for centos7 start
    cd srclib
    sed -i -e '/gets is a security/d' stdio.in.h
    cd ..
    # end
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "libiconv configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "libiconv make err"
    make install
    [ $? != 0 ] && error_exit "libiconv install err"
    #add to active lib
    ldconfig
    cd $SRC_DIR
    rm -fr $ICONV_SRC
    echo 
    echo "install libiconv complete."
    touch $ICONV_LOCK
}

# mhash install function
# mhash_dir=/usr
function install_mhash {
    [ -f $MHASH_LOCK ] && return 
    echo "install mhash..."
    cd $SRC_DIR
    tar -zxvf $MHASH_SRC$SRC_SUFFIX
    cd $MHASH_SRC
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "mhash configure err"
    make
    [ $? != 0 ] && error_exit "mhash make err"
    make install
    [ $? != 0 ] && error_exit "mhash install err"
    #add to active lib
    ldconfig
    cd $SRC_DIR
    rm -fr $MCRYPT_SRC
    echo 
    echo "install mcrypt complete."
    touch $MCRYPT_LOCK
}

# mcrypt install function
# mcrypt_dir=/usr
function install_mcrypt {
    [ -f $MCRYPT_LOCK ] && return 
    echo "install mcrypt..."
    cd $SRC_DIR
    tar -zxvf $MCRYPT_SRC$SRC_SUFFIX
    cd $MCRYPT_SRC
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "mcrypt configure err"
    make
    [ $? != 0 ] && error_exit "mcrypt make err"
    make install
    [ $? != 0 ] && error_exit "mcrypt install err"
    #add to active lib
    ldconfig
    cd libltdl
    ./configure --enable-ltdl-install && make && make install
    [ $? != 0 ] && error_exit "mcrypt ltdl install err"
    cd $SRC_DIR
    rm -fr $MCRYPT_SRC
    echo 
    echo "install mcrypt complete."
    touch $MCRYPT_LOCK
}

# install common depend
function install_common {
    [ -f $COMMON_LOCK ] && return
    # for centos7 start
    iptables="iptables-services"
    # end
    yum install -y gcc gcc-c++ make sudo autoconf libtool-ltdl-devel gd-devel \
        freetype-devel libxml2-devel libjpeg-devel libpng-devel openssl-devel \
        curl-devel patch libmcrypt-devel libmhash-devel ncurses-devel bzip2 \
        libcap-devel ntp sysklogd diffutils sendmail iptables zip unzip cmake wget \
        re2c bison icu libicu libicu-devel net-tools psmisc vim-enhanced \
        telnet ipset lsof $iptables
    [ $? != 0 ] && error_exit "common depend install err"
    # create user for nginx php
    groupadd -g 1000 www >/dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    useradd -g 1000 -u 1000 -d /www -s /sbin/nologin www >/dev/null 2>&1
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

install_common
install_php

