. ./common.sh

read -p "Enter php version like 7.2.34,7.4.33,8.0.0: " PHP_VERSION

INSTALL_DIR="/www/server"
SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
# php source
PHP_DOWN="http://hk1.php.net/distributions/php-$PHP_VERSION.tar.gz"
PHP_SRC="php-$PHP_VERSION"
PHP_DIR="$PHP_SRC"
PHP_LOCK="$LOCK_DIR/php.lock"
# dependency of php
ICONV_DOWN="http://ftp.gnu.org/gnu/libiconv/libiconv-1.16.tar.gz"
ICONV_SRC="libiconv-1.16"
ICONV_LOCK="$LOCK_DIR/php.iconv.lock"
# php-7.2.x or newer need compile https://pecl.php.net/get/mcrypt-1.0.1.tgz by handle and add mcrypt.so to php.ini
MCRYPT_DOWN="https://gitlab.com/lnmp-shell/lnmp-files/-/raw/master/libmcrypt-2.5.8.tar.gz"
MCRYPT_SRC="libmcrypt-2.5.8"
MCRYPT_LOCK="$LOCK_DIR/php.mcrypt.lock"
# mbstring depend oniguruma
ONIGURUMA_DOWN="https://github.com/kkos/oniguruma/archive/v6.9.4.tar.gz"
ONIGURUMA_SRC="oniguruma-6.9.4"
ONIGURUMA_LOCK="$LOCK_DIR/php.oniguruma.lock"
# common dependency for php
COMMON_LOCK="$LOCK_DIR/php.common.lock"

# php-7.x and php-8.x install function
# nginx: --enable-fpm --with-fpm-user=www --with-fpm-group=www
# as of php-7.4.0, --with-gd becomes --enable-gd (whether to enable the extension at all)
# as of php-7.4.0, use --with-jpeg instead --with-jpeg-dir=DIR
# as of php-7.4.0, --with-png-dir and --with-zlib-dir have been removed, libpng and zlib are required
# as of php-7.4.0 use --with-freetype instead --with-freetype-dir=DIR, which relies on pkg-config
# as of php-7.2.0 --enable-gd-native-ttf has no effect and has been removed
# as of php-7.4.0 use --with-zip instead --enable-zip
function install_php {
    
    [ ! -f /usr/lib64/libiconv.so ] && install_libiconv
    [ ! -f /usr/lib64/libmcrypt.so ] && install_mcrypt
    [ ! -f /usr/include/oniguruma.h ] && install_oniguruma
    
    [ -f $PHP_LOCK ] && (echo 'Install locked.') && return    
    echo "install php..."

    cd $SRC_DIR
    [ ! -f $PHP_SRC$SRC_SUFFIX ] && wget --no-check-certificate $PHP_DOWN
    tar -zxvf $PHP_SRC$SRC_SUFFIX
    cd $PHP_SRC
    make clean > /dev/null 2>&1
    if version_lt $PHP_VERSION "7.4.0"; then
        ./configure --prefix=$INSTALL_DIR/$PHP_DIR \
        --with-config-file-path=$INSTALL_DIR/$PHP_DIR/etc \
        --enable-fpm --with-fpm-user=www --with-fpm-group=www \
        --enable-mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
        --with-iconv --with-mcrypt=/usr \
        --with-gd --with-freetype-dir --with-jpeg-dir --with-png-dir --enable-gd-native-ttf \
        --with-zlib --with-curl --with-openssl --with-xmlrpc --with-gettext \
        --enable-xml --with-libxml-dir=/usr \
        --enable-inline-optimization \
        --enable-mbregex --enable-mbstring --enable-ftp --enable-intl --enable-xml --enable-bcmath \
        --enable-exif --enable-shmop --enable-pcntl --enable-soap --enable-sockets --enable-zip --enable-opcache \
        --disable-rpath --disable-ipv6 --disable-debug
    else
        ./configure --prefix=$INSTALL_DIR/$PHP_DIR \
        --with-config-file-path=$INSTALL_DIR/$PHP_DIR/etc \
        --enable-fpm --with-fpm-user=www --with-fpm-group=www \
        --enable-mysqlnd --with-mysql=mysqlnd --with-mysqli=mysqlnd --with-pdo-mysql=mysqlnd \
        --with-iconv --with-mcrypt=/usr \
        --enable-gd --with-freetype --with-jpeg --with-zip \
        --with-zlib --with-libxml-dir=/usr --with-curl --with-openssl --with-xmlrpc --with-gettext \
        --enable-inline-optimization \
        --enable-mbregex --enable-mbstring --enable-ftp --enable-intl --enable-xml --enable-bcmath \
        --enable-exif --enable-shmop --enable-pcntl --enable-soap --enable-sockets --enable-opcache \
        --disable-rpath --disable-ipv6 --disable-debug
    fi
    [ $? != 0 ] && error_exit "php configure err"
    make ZEND_EXTRA_LIBS='-liconv' -j $CPUS
    [ $? != 0 ] && error_exit "php make err"
    make install
    [ $? != 0 ] && error_exit "php install err"
    # php link dir
    ln -sf $INSTALL_DIR/$PHP_DIR $INSTALL_DIR/php
    # copy php.ini-production to $PHP_DIR
    cp php.ini-production $INSTALL_DIR/$PHP_DIR/etc/php.ini
    # replace php.ini config
    sed -i 's@^short_open_tag = Off@short_open_tag = On@' $INSTALL_DIR/$PHP_DIR/etc/php.ini
    sed -i 's@^;date.timezone.*@date.timezone = Asia/Shanghai@' $INSTALL_DIR/$PHP_DIR/etc/php.ini
    ln -sf $INSTALL_DIR/$PHP_DIR/bin/php /usr/local/bin/php
    ln -sf $INSTALL_DIR/$PHP_DIR/bin/phpize /usr/local/bin/phpize
    ln -sf $INSTALL_DIR/$PHP_DIR/bin/php-config /usr/local/bin/php-config
    # php version
    php -v | grep -q "PHP 7" && V7=1 || V7=0
    php -v | grep -q "PHP 8" && V8=1 || V8=0
    if [[ $V7 -eq 1 || $V8 -eq 1 ]]; then
        cp -f $INSTALL_DIR/$PHP_DIR/etc/php-fpm.conf.default $INSTALL_DIR/$PHP_DIR/etc/php-fpm.conf
        cp -f $INSTALL_DIR/$PHP_DIR/etc/php-fpm.d/www.conf.default $INSTALL_DIR/$PHP_DIR/etc/php-fpm.d/www.conf
        # php-fpm config
        sed -i 's@^;pid = run/php-fpm.pid@pid = run/php-fpm.pid@' $INSTALL_DIR/$PHP_DIR/etc/php-fpm.conf
    else
        cp -f $INSTALL_DIR/$PHP_DIR/etc/php-fpm.conf.default $INSTALL_DIR/$PHP_DIR/etc/php-fpm.conf
        echo 'PHP 5.6'
    fi
    # for php-fpm
    if [ $VERS -ge 7 ]; then
        cp -f ./sapi/fpm/php-fpm.service /usr/lib/systemd/system/
        sed -i 's@${prefix}@/www/server/php@' /usr/lib/systemd/system/php-fpm.service
        sed -i 's@${exec_prefix}@/www/server/php@' /usr/lib/systemd/system/php-fpm.service
        systemctl daemon-reload
        systemctl start php-fpm.service
        systemctl enable php-fpm.service
    else
        cp -f ./sapi/fpm/init.d.php-fpm /etc/init.d/php-fpm
        chmod +x /etc/init.d/php-fpm
        chkconfig --add php-fpm
        service php-fpm start
    fi
    
    echo  
    echo "install php complete."
    touch $PHP_LOCK
}

# libiconv install function
# iconv_dir=/usr/local/libiconv
function install_libiconv {
    [ -f $ICONV_LOCK ] && return     
    echo "install libiconv..."

    cd $SRC_DIR
    [ ! -f $ICONV_SRC$SRC_SUFFIX ] && wget $ICONV_DOWN
    tar -zxvf $ICONV_SRC$SRC_SUFFIX && cd $ICONV_SRC
    ./configure --prefix=/usr/local/libiconv
    [ $? != 0 ] && error_exit "libiconv configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "libiconv make err"
    make install
    [ $? != 0 ] && error_exit "libiconv install err"
    # link to /usr/lib64
    ln -sf /usr/local/libiconv/lib/libiconv.so /usr/lib64/
    ln -sf /usr/local/libiconv/lib/libiconv.so.2 /usr/lib64/
    
    # refresh active lib
    ldconfig
    cd $SRC_DIR
    rm -fr $ICONV_SRC
    
    echo 
    echo "install libiconv complete."
    touch $ICONV_LOCK
}

# mcrypt install function
# mcrypt_dir=/usr
function install_mcrypt {
    [ -f $MCRYPT_LOCK ] && return 
    echo "install mcrypt..."

    cd $SRC_DIR
    [ ! -f $MCRYPT_SRC$SRC_SUFFIX ] && wget $MCRYPT_DOWN
    tar -zxvf $MCRYPT_SRC$SRC_SUFFIX && cd $MCRYPT_SRC
    ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "mcrypt configure err"
    make
    [ $? != 0 ] && error_exit "mcrypt make err"
    make install
    [ $? != 0 ] && error_exit "mcrypt install err"
    
    # refresh active lib
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

# mbstring depend oniguruma
# Centos 8 install oniguruma
function install_oniguruma {
    [ -f $ONIGURUMA_LOCK ] && return
    echo "install oniguruma..."

    cd $SRC_DIR
    wget $ONIGURUMA_DOWN -O $ONIGURUMA_SRC.tar.gz
    tar -zxvf $ONIGURUMA_SRC.tar.gz && cd $ONIGURUMA_SRC
    ./autogen.sh && ./configure --prefix=/usr
    [ $? != 0 ] && error_exit "oniguruma configure err"
    make
    [ $? != 0 ] && error_exit "oniguruma make err"
    make install
    [ $? != 0 ] && error_exit "oniguruma install err"
   
    # refresh active lib
    ldconfig 
    cd $SRC_DIR
    rm -fr $ONIGURUMA_SRC

    echo
    echo "install oniguruma complete."
    touch $ONIGURUMA_LOCK
}

# install common dependency
# ifconfig command depend net-tools
# php user:group is www:www
function install_common {
    [ -f $COMMON_LOCK ] && return
    # iptables-services for Centos 7 and Centos 8
    yum install -y sudo wget gcc gcc-c++ make sudo autoconf libtool-ltdl-devel gd-devel \
        freetype-devel libxml2-devel libjpeg-devel libpng-devel openssl-devel \
        libsqlite3x-devel libtool libzip-devel \
	curl-devel patch ncurses-devel bzip2 libcap-devel diffutils \
        bison icu libicu libicu-devel net-tools psmisc vim vim-enhanced \
        zip unzip telnet tcpdump ipset lsof iptables iptables-services
    [ $? != 0 ] && error_exit "common dependency install err"

    # create user for nginx php
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
    install_php
}

start_install
