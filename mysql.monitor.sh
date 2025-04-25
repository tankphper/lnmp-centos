# * * * * * /usr/bin/sh /www/server/shell/mysql.monitor.sh >> /var/log/mysql.monitor.log
# detect mysqld status
function detect {
    RESULT=`systemctl status mysqld | grep "Active*"`
    echo $RESULT
    MATCH=`echo $RESULT | grep "exit" | wc -l`
    echo $MATCH $(date)
    if [ $MATCH -gt 0 ]; then
        echo "Stoping..."
        systemctl stop mysqld
        echo "Starting..."
        systemctl start mysqld
        echo "Restarted"
    fi
}

while ((++i)); do
    if ((i>2)); then
        break
    fi
    detect
    sleep 25
done
