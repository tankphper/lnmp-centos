ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
echo $CPUS
echo $ROOT
INSTALL_DIR="/www/server"
SRC_DIR="$ROOT/src"
LOCK_DIR="$ROOT/lock"
SRC_SUFFIX=".tar.gz"
# redis server source
REDIS_DOWN="http://download.redis.io/releases/redis-3.2.8.tar.gz"
REDIS_SRC="redis-3.2.8"
REDIS_DIR="redis-3.2.8"
REDIS_LOCK="$LOCK_DIR/redis.lock"

# redis-3.2.8 install function
function install_redis {
    [ -f $REDIS_LOCK ] && return
    echo 
    echo "install redis..."
    cd $SRC_DIR
    [ ! -f $SRC_DIR/$REDIS_SRC$SRC_SUFFIX ] && wget $REDIS_DOWN
    tar -zxvf $REDIS_SRC$SRC_SUFFIX
    cd $REDIS_SRC
    make clean >/dev/null 2>&1
    make
    [ $? != 0 ] && error_exit "redis make err"
    make install
    [ $? != 0 ] && error_exit "redis install err"
    # copy
    sed -i 's@^daemonize no@daemonize yes@' redis.conf
    sed -i 's@^protected-mode yes@protected-mode no@' redis.conf
    sed -i 's@^bind 127.0.0.1@#bind 127.0.0.1@' redis.conf
    sed -i 's@^# requirepass foobared@requirepass redis!-!pass@' redis.conf
    ln -sf redis.conf $INSTALL_DIR/etc/redis.conf
    # set to auto start
    cp utils/redis_init_script /etc/rc.d/init.d/redis
    sed -i '1c/# chkconfig: 2345 80 90' /etc/rc.d/init.d/redis 
    sed -i 's@^CONF="/etc/redis/${REDISPORT}.conf"@CONF="/www/server/etc/redis.conf"@' /etc/rc.d/init.d/redis 
    sed -i 's@^$EXEC $CONF@$EXEC $CONF &@' /etc/rc.d/init.d/redis 
    # chkconfig and start
    chkconfig --add redis
    service redis start 
    echo  
    echo "install redis complete."
    touch $PHP_LOCK
}

# install common dependency
function install_common {
    yum install tcl -y
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
    mkdir -p $LOCK_DIR
    install_common
    install_redis
}

start_install
