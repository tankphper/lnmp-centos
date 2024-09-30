. ./common.sh

read -p "Enter php version like 7.2.34,7.4.33: " PHP_VERSION

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
# php-7.2.x need compile https://pecl.php.net/get/mcrypt-1.0.1.tgz by handle and add mcrypt.so to php.ini
MCRYPT_DOWN="https://gitlab.com/lnmp-shell/lnmp-files/-/raw/master/libmcrypt-2.5.8.tar.gz"
MCRYPT_SRC="libmcrypt-2.5.8"
MCRYPT_LOCK="$LOCK_DIR/mcrypt.lock"
# php-7.4.x depend libzip >= 0.11 libzip != 1.3.1 libzip != 1.7.0
LIBZIP_DOWN="https://libzip.org/download/libzip-1.10.1.tar.gz"
LIBZIP_SRC="libzip-1.10.1"
LIBZIP_LOCK="$LOCK_DIR/php.libzip.lock"
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
    
    [ ! -f /usr/lib/libiconv.so ] && install_libiconv
    [ ! -f /usr/lib/libmcrypt.so ] && install_mcrypt
    if version_gt $PHP_VERSION "7.4.0"; then (install_libzip) fi
    
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
        --enable-ftp --enable-intl \
        --enable-bcmath --enable-exif --enable-soap \
        --enable-shmop --enable-pcntl \
        --disable-ipv6 --disable-debug \
        --enable-sockets --enable-zip --enable-opcache \
        --enable-fpm --with-fpm-user=www --with-fpm-group=www
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
# iconv_dir=/usr
function install_libiconv {
    [ -f $ICONV_LOCK ] && return     
    echo "install libiconv..."

    cd $SRC_DIR
    [ ! -f $ICONV_SRC$SRC_SUFFIX ] && wget $ICONV_DOWN
    tar -zxvf $ICONV_SRC$SRC_SUFFIX
    cd $ICONV_SRC
    # for Centos 7 start
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
    tar -zxvf $MCRYPT_SRC$SRC_SUFFIX
    cd $MCRYPT_SRC
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

# php-7.4.x require libzip >= 0.11 libzip != 1.3.1 libzip != 1.7.0
function install_libzip {
    [ -f $LIBZIP_LOCK ] && return
    echo "install libzip..."

    cd $SRC_DIR
    [ ! -f $LIBZIP_SRC$SRC_SUFFIX ] && wget $LIBZIP_DOWN -O $LIBZIP_SRC.tar.gz
    tar -zxvf $LIBZIP_SRC.tar.gz && cd $LIBZIP_SRC
    mkdir build
    cd build
    cmake ..
    [ $? != 0 ] && error_exit "libzip make err"
    make install
    [ $? != 0 ] && error_exit "libzip install err"

    touch /etc/ld.so.conf.d/php-lib.conf
    echo /usr/local/lib64 >> /etc/ld.so.conf.d/php-lib.conf
    # the export command is not valid in the shell
    #export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib64/pkgconfig
    # refresh active lib
    ldconfig
    cd $SRC_DIR
    rm -fr $LIBZIP_SRC

    echo
    echo "install libzip complete."
    touch $LIBZIP_LOCK

    error_exit "run as root: export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:/usr/local/lib64/pkgconfig"
}

# install common dependency
# ifconfig command depend net-tools
# php user:group is www:www
function install_common {
    [ -f $COMMON_LOCK ] && return
    # iptables-services for Centos 7 and Centos 8
    yum install -y sudo wget gcc gcc-c++ make sudo autoconf libtool-ltdl-devel gd-devel \
        freetype-devel libxml2-devel libjpeg-devel libpng-devel openssl-devel \
        libsqlite3x-devel sqlite-devel oniguruma-devel sysklogd re2c \
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
