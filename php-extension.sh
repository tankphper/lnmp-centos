. ./common.sh

SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
EXT_VER=${2:-""}
PHP_VER=$(php --version | grep "^PHP" | awk '{print $2}')
#PHP_VER=$(php-config --version)
PHP_API_VER=$(phpize --version | grep "PHP Api Version*" | awk '{print $NF}')
PHP_EXT_DIR=$(php-config --extension-dir)
PHP_PREFIX=$(php-config --prefix)

echo "PHP_VER:"$PHP_VER
echo "PHP_API_VER:"$PHP_API_VER
echo "PHP_EXT_DIR:"$PHP_EXT_DIR
echo "EXT_VER:"$EXT_VER

function echo_ini {
    echo "extension=$PHP_EXT_DIR/$1.so" >> $PHP_PREFIX/etc/php.ini
}

# --enable-async-redis require hiredis library supported
# --enable-http2 require nghttp2 library supported
function add_swoole {
    local SWOOLE_VER=${EXT_VER:-"4.4.14"}
    cd $SRC_DIR
    [ ! -f swoole.tar.gz ] && wget https://github.com/swoole/swoole-src/archive/v$SWOOLE_VER.tar.gz -O swoole.tar.gz
    [ ! -f swoole ] && mkdir swoole
    tar -zxvf swoole.tar.gz -C swoole --strip-components=1
    cd swoole
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config \
    --enable-openssl \
    --enable-async-redis \
    --enable-http2 \
    --enable-mysqlnd \
    --enable-coroutine \
    --enable-sockets
    [ $? != 0 ] && error_exit "swoole configure err"
    make
    [ $? != 0 ] && error_exit "swoole make err"
    make install
    [ $? != 0 ] && error_exit "swoole make install err"
    echo_ini swoole
}

function add_protobuf {
    local PROTOBUF_VER=${EXT_VER:-"3.6.1"}
    cd $SRC_DIR
    [ ! -f protobuf.tar.gz ] && wget https://github.com/protocolbuffers/protobuf/archive/v$PROTOBUF_VER.tar.gz -O protobuf.tar.gz
    [ ! -f protobuf ] && mkdir protobuf
    tar -zxvf protobuf.tar.gz -C protobuf --strip-components=1
    cd protobuf/php/ext/google/protobuf
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config
    [ $? != 0 ] && error_exit "protobuf configure err"
    make
    [ $? != 0 ] && error_exit "protobuf make err"
    make install
    [ $? != 0 ] && error_exit "protobuf make install err"
    echo_ini protobuf
}

function add_redis {
    local PHPREDIS_VER=${EXT_VER:-"4.3.0"}
    cd $SRC_DIR
    [ ! -f phpredis.tar.gz ] && wget https://github.com/phpredis/phpredis/archive/$PHPREDIS_VER.tar.gz -O phpredis.tar.gz
    [ ! -f phpredis ] && mkdir phpredis
    tar -zxvf phpredis.tar.gz -C phpredis --strip-components=1
    cd phpredis
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config
    [ $? != 0 ] && error_exit "phpredis configure err"
    make
    [ $? != 0 ] && error_exit "phpredis make err"
    make install
    [ $? != 0 ] && error_exit "phpredis make install err"
    echo_ini redis
}

# php-7.2.x not have mcrypt
# php --ri mcrypt will see version 2.5.8
function add_mcrypt {
    local MCRYPT_VER=${EXT_VER:-"1.0.1"}
    cd $SRC_DIR
    [ ! -f phpmcrypt.tar.gz ] && wget https://pecl.php.net/get/mcrypt-$MCRYPT_VER.tgz -O phpmcrypt.tar.gz
    [ ! -d phpmcrypt ] && mkdir phpmcrypt
    tar -zxvf phpmcrypt.tar.gz -C phpmcrypt --strip-components=1
    cd phpmcrypt
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config
    [ $? != 0 ] && error_exit "phpmcrypt configure err"
    make
    [ $? != 0 ] && error_exit "phpmcrypt make err"
    make install
    [ $? != 0 ] && error_exit "phpmcrypt make install err"
    echo_ini mcrypt
}

# install error function
function error_exit {
    echo 
    echo 
    echo "Install error :$1--------"
    echo 
    exit
}

if [ $1 ]; then
   add_$1
fi
