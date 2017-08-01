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
MYSQL_DOWN="https://cdn.mysql.com/archives/mysql-5.7/mysql-5.7.18.tar.gz"
MYSQL_SRC="mysql-5.7.18"
MYSQL_DIR="$MYSQL_SRC"
MYSQL_LOCK="$LOCK_DIR/mysql.lock"
# cmake tool source
CMAKE_DOWN="https://cmake.org/files/v3.8/cmake-3.8.2.tar.gz"
CMAKE_SRC="cmake-3.8.2"
CMAKE_DIR="$CMAKE_SRC"
CMAKE_LOCK="$LOCK_DIR/cmake.lock"
# boost
BOOST_DOWN="https://sourceforge.net/projects/boost/files/boost/1.59.0/boost_1_59_0.tar.gz"
BOOST_SRC="boost_1_59_0"
BOOST_DIR="$BOOST_SRC"
BOOST_LOCK="$LOCK_DIR/boost.lock"
# common dependency fo mysql
COMMON_LOCK="$LOCK_DIR/mysql.common.lock"

# mysql install function
function install_mysql {
    
    [ ! -f /usr/local/bin/cmake ] && install_cmake 
    [ ! -d /usr/src/$BOOST_SRC ] && install_boost

    [ -f $MYSQL_LOCK ] && return
    
    echo "install mysql..."
    
    cd $SRC_DIR
    [ ! -f $MYSQL_SRC$SRC_SUFFIX ] && wget $MYSQL_DOWN
    tar -zxvf $MYSQL_SRC$SRC_SUFFIX
    cd $MYSQL_SRC
    make clean > /dev/null 2>&1
    # sure datadir is empty
    # sure boost dir path
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
        -DWITH_BOOST=/usr/src/$BOOST_SRC
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
    [ ! -d $INSTALL_DIR/etc ] && mkdir $INSTALL_DIR/etc
    cp -f $ROOT/mysql.conf/my.cnf $INSTALL_DIR/etc/my.cnf
    ln -sf $INSTALL_DIR/etc/my.cnf /etc/my.cnf
    # db file user:group
    [ -d $INSTALL_DIR/mysql/data ] && mkdir $INSTALL_DIR/mysql/data
    chown -hR mysql:mysql $INSTALL_DIR/mysql/data
    # add to env path
    echo "PATH=\$PATH:$INSTALL_DIR/mysql/bin" > /etc/profile.d/mysql.sh
    # add to active lib
    echo "$INSTALL_DIR/mysql" > /etc/ld.so.conf.d/mysql-wdl.conf
    # refresh active lib
    ldconfig
    
    if [ $R7 == 1 ]
    then
        # init db use
        # --initialize set password to log file
        # --initialize-insecure set a empty password
        $INSTALL_DIR/mysql/bin/mysqld --initialize-insecure --user=mysql --basedir=$INSTALL_DIR/mysql --datadir=$INSTALL_DIR/mysql/data 
        # auto start script for centos7
        cp -f support-files/mysql.server /etc/init.d/mysqld
        chmod +x /etc/init.d/mysqld
        # auto start when start system
        chkconfig --add mysqld
        chkconfig --level 35 mysqld on
        service mysqld start

        # set root password
        $INTSALL_DIR/mysql/bin/mysql -u root -p -e "use mysql;alter user 'root'@'localhost' identified by 'zhoumanzi'"
    else
        # init db
        ./scripts/mysql_install_db --basedir=$INSTALL_DIR/mysql --datadir=$INSTALL_DIR/mysql/data
        # auto start script for centos6
        cp -f ./support-files/mysql.server /etc/init.d/mysqld
        chmod +x /etc/init.d/mysqld
        # auto start when start system
        chkconfig --add mysqld
        chkconfig --level 35 mysqld on
        service mysqld start

        # set root password 
        $INSTALL_DIR/mysql/bin/mysqladmin -u root password "zhoumanzi"

    fi
    # mysql.sock dir
    mkdir -p /var/lib/mysql
    [ -f /tmp/mysql.sock ] && ln -sf /tmp/mysql.sock /var/lib/mysql/
    
    echo  
    echo "install mysql complete."
    touch $MYSQL_LOCK
}

# cmake install function
# mysql depend cmake to compile
# cmake_dir=/usr
function install_cmake {
    [ -f $CMAKE_LOCK ] && return

    echo "install cmake..."
    cd $SRC_DIR
    [ ! -f $CMAKE_SRC$SRC_SUFFIX ] && wget $CMAKE_DOWN
    tar -zxvf $CMAKE_SRC$SRC_SUFFIX
    cd $CMAKE_SRC
    ./bootstrap --prefix=/usr
    [ $? != 0 ] && error_exit "cmake configure err"
    make
    [ $? != 0 ] && error_exit "cmake make err"
    make install
    [ $? != 0 ] && error_exit "cmake install err"
    cd $SRC_DIR
    rm -fr $CMAKE_SRC

    echo
    echo "install cmake complete."
    touch $CMAKE_LOCK
}

# boost install function
# mysql depend boost library
# boost_dir=/usr/src
function install_boost {
    [ -f $BOOST_LOCK ] && return

    echo "install boost..."
    cd $SRC_DIR
    [ ! -f $BOOST_SRC$SRC_SUFFIX ] && wget $BOOST_DOWN
    cp $BOOST_SRC$SRC_SUFFIX /usr/src
    cd /usr/src
    tar -zxvf $BOOST_SRC$SRC_SUFFIX
    
    echo
    echo "install boost complete."
    touch $BOOST_LOCK
}

# install common dependency
# mysql compile need boost default dir=/usr/share/doc/boost-1.53.0
# remove centos7 default boost version is 1.53.0
# remove system default cmake
# mysql user:group is mysql:mysql
function install_common {
    [ -f $COMMON_LOCK ] && return
    yum install -y gcc gcc-c++ ncurses ncurses-devel bison bison-devel \
        ntp ntpdate
    [ $? != 0 ] && error_exit "common dependence install err"
    
    # create user for mysql
    #groupadd -g 27 mysql > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    #useradd -g 27 -u 27 -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    
    # -U create a group with the same name as the user. so it can instead groupadd and useradd
    useradd -U -d /dev/null -s /sbin/nologin mysql > /dev/null 2>&1
    # set local timezone
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
