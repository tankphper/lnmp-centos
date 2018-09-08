. ./common.sh

SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
PHPREDIS_VER=$2

function add_redis {
    cd $SRC_DIR
    wget https://github.com/phpredis/phpredis/archive/$PHPREDIS_VER.tar.gz -O phpredis.tar.gz
    mkdir phpredis
    tar -zxvf phpredis.tar.gz -C phpredis --strip-components=1
    cd phpredis
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config
    make
    make install
}

add_$1
