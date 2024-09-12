. ./common.sh

PHP_SWT_VER=${1:-""}
PHP_OLD_VER=$(php-config --version)

ln -sf /www/server/php-$PHP_SWT_VER/bin/php /usr/local/bin/php
ln -sf /www/server/php-$PHP_SWT_VER/bin/phpize /usr/local/bin/phpize
ln -sf /www/server/php-$PHP_SWT_VER/bin/php-config /usr/local/bin/php-config
rm -fr /www/server/php
ln -sf /www/server/php-$PHP_SWT_VER /www/server/php

sed -i "s/${PHP_OLD_VER}/${PHP_SWT_VER}/g" /usr/lib/systemd/system/php-fpm.service
systemctl daemon-reload
systemctl restart php-fpm

PHP_NEW_VER=$(php-config --version)

echo "PHP_SWT_VER:"$PHP_SWT_VER
echo "PHP_OLD_VER:"$PHP_OLD_VER
echo "PHP_NEW_VER:"$PHP_NEW_VER
