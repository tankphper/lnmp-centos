. ./common.sh

SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
PHPREDIS_VER=$2
PHP_VER=$(php --version | grep "^PHP" | awk '{print $2}')
PHP_API_VER=$(phpize --version | grep "PHP Api Version*" | awk '{print $NF}')

echo $PHP_VER
echo $PHP_API_VER

function echo_ini {
    echo "extension=/www/server/php-$PHP_VER/lib/php/extensions/no-debug-non-zts-$PHP_API_VER/$1.so" >> /www/server/php-$PHP_VER/etc/php.ini
}

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
    
    echo_ini redis
}

function add_mcrypt {
    cd $SRC_DIR
    wget https://pecl.php.net/get/mcrypt-1.0.1.tgz -O phpmcrypt.tar.gz
    mkdir phpmcrypt
    tar -zxvf phpmcrypt.tar.gz -C phpmcrypt --strip-components=1
    cd phpmcrypt
    phpize
    ./configure --with-php-config=/www/server/php/bin/php-config
    make
    make install
    
    echo_ini mcrypt
}

add_$1
