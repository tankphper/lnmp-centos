ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
echo $CPUS
echo $ROOT
INSTALL_DIR="/www/server"
SRC_DIR="$ROOT/src"
PHP_DIR="nginx_php"
SRC_SUFFIX=".tar.gz"
ICONV_SRC="libiconv-1.15"
MCRYPT_SRC="libmcrypt-2.5.8"
PHP_SRC="php-7.1.2"

# php7.1.2 install function
# for nginx:
# --enable-fpm --with-fpm-user=www --with-fpm-group=www
function install_php {
    install_libiconv
    install_mcrypt
    echo 
    echo "install php..."
    cd $SRC_DIR
    tar -zxvf $PHP_SRC$SRC_SUFFIX
    cd php-7.1.2
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
    echo  
    echo "install php complete."
}

# libiconv install function
# iconv_dir=/usr
function install_libiconv {
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
    exit
}

# mcrypt install function
# mcrypt_dir=/usr
function install_mcrypt {
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
    ldconfig
    cd libltdl
    ./configure --enable-ltdl-install && make && make install
    [ $? != 0 ] && error_exit "mcrypt ltdl install err"
    cd $SRC_DIR
    rm -fr $MCRYPT_SRC
    echo 
    echo "install mcrypt complete."
}

# install error function
function error_exit {
    echo 
    echo 
    echo "Install error :$1--------"
    echo 
    exit
}
