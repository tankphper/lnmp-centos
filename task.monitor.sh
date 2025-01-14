#!/bin/bash
PATH="/www/server/mysql/bin:/usr/local/mysql/bin:/usr/local/bin:/usr/bin:/bin"
export PATH

BUSY_COUNT=`echo $(php /www/server/task/start.php status | grep "busy" | wc -l)`

echo "Busy: "$BUSY_COUNT
if [ `echo "$BUSY_COUNT >= 1"|bc` -eq 1 ]; then
    #php /www/server/task/start.php restart -d > /dev/null 2>&1
    echo "Restart..."
else
    echo "Ok"
fi
