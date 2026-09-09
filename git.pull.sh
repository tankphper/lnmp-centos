#!/bin/bash
PATH="/www/server/mysql/bin:/usr/local/mysql/bin:/usr/local/bin:/usr/bin:/bin"
export PATH

TIME=`echo $(date +%Y-%m-%d" "%H:%M:%S)`

ROOT1='/www/web/frant'
FILE1=$ROOT1/runtime/logs/pull.log
[ -e $FILE1 ] || touch $FILE1 && chown www:www $FILE1
echo '' >> $FILE1
echo $TIME >> $FILE1
echo $ROOT1 >> $FILE1
cd $ROOT1 && git pull >> $FILE1
