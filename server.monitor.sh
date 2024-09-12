#!/bin/bash

LOADAVERAGE=`echo $(uptime) | awk '{print $(NF-2)}'`
LOADAVERAGE=`echo $LOADAVERAGE | sed 's/,//'`

if [ `echo "$LOADAVERAGE >= 10"|bc` -eq 1 ]; then
    /usr/bin/curl -X GET --ipv4 https://api.domain.com/telegram/secretary/remind.html?avg=$LOADAVERAGE > /dev/null 2>&1
else
    echo $LOADAVERAGE
fi
