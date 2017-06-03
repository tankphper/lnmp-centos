ROOT=$(pwd)
CPUS=`grep processor /proc/cpuinfo | wc -l`
grep -q "release 7" /etc/redhat-release && R7=1 || R7=0
echo $ROOT
echo $CPUS
echo $R7
INSTALL_DIR="/www/server"
LOCK_DIR="$ROOT/lock"
SRC_DIR="$ROOT/src"
SRC_SUFFIX=".tar.gz"
# mysql source
MYSQL_DOWN="https://cdn.mysql.com/archives/mysql-5.7/mysql-5.7.17.tar.gz"
MYSQL_SRC="mysql-5.7.17"
MYSQL_DIR="$MYSQL_SRC"
MYSQL_LOCK="$LOCK_DIR/mysql.lock"
# common dependency fo mysql
COMMON_LOCK="$LOCK_DIR/mysql.common.lock"

# mysql install function
function install_mysql {
    [ -f $MYSQL_LOCK ] && return
    
    echo "install mysql..."
    cd $SRC_DIR
    [ ! -f $MYSQL_SRC$SRC_SUFFIX ] && wget $MYSQL_DOWN
    tar -zxvf $MYSQL_SRC$SRC_SUFFIX
    cd $MYSQL_SRC
    make clean > /dev/null 2>&1
    # sure datadir is empty
    # sure boost dir
    cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/$MYSQL_DIR \
        -DMYSQL_DATADIR=$INSTALL_DIR/$MYSQL_DIR/data \
        -DSYSCONFDIR=$INSTALL_DIR/etc \
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_PARTITION_STORAGE_ENGINE=1 \
        -DWITH_FEDERATED_STORAGE_ENGINE=1 \
        -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
        -DWITH_MYISAM_STORAGE_ENGINE=1 \
        -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
        -DWITH_READLINE=1 \
        -DENABLED_LOCAL_INFILE=1 \
        -DENABLE_DTRACE=0 \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci \
        -DWITH_EMBEDDED_SERVER=1 \
        -DDOWNLOAD_BOOST=1 \
        -DWITH_BOOST=/usr/share/doc/boost-1.53.0
    [ $? != 0 ] && error_exit "mysql configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "mysql make err"
    make install
    [ $? != 0 ] && error_exit "mysql install err"
    ln -sf $INSTALL_DIR/$MYSQL_SRC $INSTALL_DIR/mysql
    ln -sf $INSTALL_DIR/mysql/bin/mysql /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqldump /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqlslap /usr/local/bin/
    ln -sf $INSTALL_DIR/mysql/bin/mysqladmin /usr/local/bin/
    # bakup config file
    [ -f /etc/my.cnf ] && mv /etc/my.cnf /etc/my.cnf.old
    # new config file
    cp -f my.cnf $INSTALL_DIR/etc/my.cnf
    ln -sf $INSTALL_DIR/etc/my.cnf /etc/my.cnf
    # db file user
    chown -hR mysql.mysql $INSTALL_DIR/mysql/data
    # add to env path
    echo "PATH=\$PATH:$INSTALL_DIR/mysql/bin" > /etc/profile.d/mysql.sh
    # add to active lib
    echo "$INSTALL_DIR/mysql" > /etc/ld.so.conf.d/mysql-wdl.conf
    # refresh active lib
    ldconfig
    
    if [ $R7 == 1 ]
    then
        # init db
        $INSTALL_DIR/mysql/bin/mysqld --initialize-insecure --user=mysql --basedir=$INSTALL_DIR/mysql --datadir=$INSTALL_DIR/mysql/data 
        # auto start script for centos7
        cp -f support-files/mysql.server /etc/init.d/mysqld
        # auto start when start system
        chkconfig --add mysqld
        chkconfig --level 35 mysqld on
        service mysqld start
    else
        # init db
        $INSTALL_DIR/mysql/scripts/mysql_install_db --basedir=$INSTALL_DIR/mysql --datadir=$INSTALL_DIR/mysql/data
        # auto start script for centos6
        cp -f support-files/mysql.server /etc/init.d/mysqld
        # auto start when start system
        chkconfig --add mysqld
        chkconfig --level 35 mysqld on
        service mysqld start
    fi
    # mysql.sock dir
    mkdir -p /var/lib/mysql
    ln -sf /tmp/mysql.sock /var/lib/mysql/
    # set root password 
    $INSTALL_DIR/mysql/bin/mysqladmin -u root password "zhoumanzi"
    $INSTALL_DIR/mysql/bin/mysql -uroot -p"zhoumanzi" -e \
        "use mysql;
        update user set password=password('zhoumanzi') where user='root';
        flush privileges;"
    
    echo  
    echo "install mysql complete."
    touch $MYSQL_LOCK
}

# install common dependency
# mysql compile need boost default dir=/usr/share/doc/boost-1.53.0
# mysql user:group is mysql:mysql
function install_common {
    [ -f $COMMON_LOCK ] && return
    yum install -y gcc gcc-c++ cmake ncurses ncurses-devel bison bison-devel \
        ntp ntpdate
    [ $? != 0 ] && error_exit "common dependence install err"
    
    # create user for mysql
    #groupadd -g 27 mysql > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    #useradd -g 27 -u 27 -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    
    # -U create a group with the same name as the user. so it can instead groupadd and useradd
    useradd -U -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    # set timezone
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    # syn system time to sina time
    ntpdate tiger.sina.com.cn
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
    install_mysql
}

start_install
