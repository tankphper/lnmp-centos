. ./common.sh

SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
EXT_VER=${2:-""}
PHP_VER=$(php --version | grep "^PHP" | awk '{print $2}')
#PHP_VER=$(php-config --version)
PHP_API_VER=$(phpize --version | grep "PHP Api Version*" | awk '{print $NF}')
PHP_EXT_DIR=$(php-config --extension-dir)

echo "PHP_VER:"$PHP_VER
echo "PHP_API_VER:"$PHP_API_VER
echo "PHP_EXT_DIR:"$PHP_EXT_DIR
echo "EXT_VER:"$EXT_VER

function echo_ini {
    echo "extension=/www/server/php-$PHP_VER/lib/php/extensions/no-debug-non-zts-$PHP_API_VER/$1.so" >> /www/server/php-$PHP_VER/etc/php.ini
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
    local PHPREDIS_VER=${EXT_VER:-"4.2.0"}
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
