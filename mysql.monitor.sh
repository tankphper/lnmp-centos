# detect mysqld
function detect {
    RESULT=`systemctl status mysqld | grep "Active*"`
    echo $RESULT
    MATCH=`echo $RESULT | grep -Eo "\(.*\)"`
    echo $MATCH $(date)
    if [ "$MATCH" == "(exited)" ]; then
        echo "Restarting..."
        systemctl restart mysqld
    fi
}

while ((++i)); do
    if ((i>4)); then
        break
    fi
    detect
    sleep 10
done
