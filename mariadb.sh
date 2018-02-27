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
# mariadb source
MARIADB_DOWN="http://ossm.utm.my/mariadb//mariadb-10.2.13/source/mariadb-10.2.13.tar.gz"
MARIADB_SRC="mariadb-10.2.13"
MARIADB_DIR="$MARIADB_SRC"
MARIADB_LOCK="$LOCK_DIR/mariadb.lock"
# cmake tool source
CMAKE_DOWN="https://cmake.org/files/v3.8/cmake-3.8.2.tar.gz"
CMAKE_SRC="cmake-3.8.2"
CMAKE_DIR="$CMAKE_SRC"
CMAKE_LOCK="$LOCK_DIR/cmake.lock"
# common dependency fo mariadb
COMMON_LOCK="$LOCK_DIR/mariadb.common.lock"

# mariadb install function
function install_mariadb {
    
    [ ! -f /usr/local/bin/cmake ] && install_cmake 

    [ -f $MARIADB_LOCK ] && return
    
    echo "install mariadb..."
    
    cd $SRC_DIR
    [ ! -f $MARIADB_SRC$SRC_SUFFIX ] && wget $MARIADB_DOWN
    tar -zxvf $MARIADB_SRC$SRC_SUFFIX
    cd $MARIADB_SRC
    make clean > /dev/null 2>&1
    # sure datadir is empty
    cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR/$MARIADB_DIR \
        -DMARIADB_DATADIR=$INSTALL_DIR/$MARIADB_DIR/data \
        -DSYSCONFDIR=$INSTALL_DIR/etc \
        -DWITHOUT_TOKUDB=1
        -DWITH_INNOBASE_STORAGE_ENGINE=1 \
        -DWITH_PARTITION_STORAGE_ENGINE=1 \
        -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
        -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
        -DWITH_READLINE=1 \
        -DWITH_EMBEDDED_SERVER=1 \
        -DENABLED_LOCAL_INFILE=1 \
        -DENABLE_DTRACE=0 \
        -DDEFAULT_CHARSET=utf8mb4 \
        -DDEFAULT_COLLATION=utf8mb4_general_ci
    [ $? != 0 ] && error_exit "mariadb configure err"
    make -j $CPUS
    [ $? != 0 ] && error_exit "mariadb make err"
    make install
    [ $? != 0 ] && error_exit "mariadb install err"
    ln -sf $INSTALL_DIR/$MARIADB_SRC $INSTALL_DIR/mariadb
    ln -sf $INSTALL_DIR/mariadb/bin/mysql /usr/local/bin/
    ln -sf $INSTALL_DIR/mariadb/bin/mysqldump /usr/local/bin/
    ln -sf $INSTALL_DIR/mariadb/bin/mysqlslap /usr/local/bin/
    ln -sf $INSTALL_DIR/mariadb/bin/mysqladmin /usr/local/bin/
    # bakup config file
    [ -f /etc/my.cnf ] && mv /etc/my.cnf /etc/my.cnf.old
    # new config file
    [ ! -d $INSTALL_DIR/etc ] && mkdir $INSTALL_DIR/etc
    #cp -f $ROOT/mariadb.conf/my.cnf $INSTALL_DIR/etc/my.cnf
    #ln -sf $INSTALL_DIR/etc/my.cnf /etc/my.cnf
    # add to env path
    echo "PATH=\$PATH:$INSTALL_DIR/mariadb/bin" > /etc/profile.d/mariadb.sh
    # add to active lib
    echo "$INSTALL_DIR/mariadb" > /etc/ld.so.conf.d/mariadb-wdl.conf
    # refresh active lib
    ldconfig
    
    # init db for mariadb
    $INSTALL_DIR/mariadb/scripts/mysql_install_db --basedir=$INSTALL_DIR/mariadb --datadir=$INSTALL_DIR/mariadb/data
    # db dir user:group
    chown -hR mysql:mysql $INSTALL_DIR/mariadb/data 
    # auto start script for centos6 and centos7
    cp -f ./support-files/mysql.server /etc/init.d/mariadbd
    chmod +x /etc/init.d/mariadbd
    # auto start when start system
    chkconfig --add mariadbd
    chkconfig --level 35 mariadbd on
    service mariadbd start

    # set root password for mariadb
    $INSTALL_DIR/mariadb/bin/mysqladmin -u root password "zhoumanzi"
    
    # mariadb.sock dir
    mkdir -p /var/lib/mysql
    [ -f /tmp/mariadb.sock ] && ln -sf /tmp/mariadb.sock /var/lib/mysql/
    
    echo  
    echo "install mariadb complete."
    touch $MARIADB_LOCK
}

# cmake install function
# mariadb depend cmake to compile
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

# install common dependency
# remove system default cmake
# mariadb user:group is mariadb:mariadb
function install_common {
    [ -f $COMMON_LOCK ] && return
    yum install -y gcc gcc-c++ ncurses ncurses-devel bison bison-devel \
        ntp ntpdate
    [ $? != 0 ] && error_exit "common dependence install err"
    
    # create user for mariadb
    #groupadd -g 27 mariadb > /dev/null 2>&1
    # -d to set user home_dir=/www
    # -s to set user login shell=/sbin/nologin, you also to set /bin/bash
    #useradd -g 27 -u 27 -d /dev/null -s /sbin/nologin mariadb > /dev/null 2>&1
    
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
    install_mariadb
}

start_install
