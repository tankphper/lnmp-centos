#!/bin/bash
PATH="/www/server/mysql/bin:/usr/local/mysql/bin:/usr/local/bin:/usr/bin:/bin"
export PATH

TIME=`echo $(date +%Y-%m-%d" "%H:%M:%S)`

declare -A CONFIG

CONFIG["/www/web/frant"]="/www/web/frant/runtime/logs/pull.log"

for ROOT in "${!CONFIG[@]}"; do
    FILE="${CONFIG[$ROOT]}"

    if [ -f "$FILE" ]; then
        FILE_SIZE=$(du -k "$FILE" | cut -f1)
        if [ "$FILE_SIZE" -gt 20480 ]; then
            > "$FILE"
            echo "$TIME - 日志超过20M，已自动清空。" >> "$FILE"
        fi
    fi

    if [ ! -e "$FILE" ]; then
        touch "$FILE"
        chown www:www "$FILE"
    fi

    echo '' >> "$FILE"
    echo "$TIME" >> "$FILE"
    echo "$ROOT" >> "$FILE"

    cd "$ROOT" && git pull >> "$FILE" 2>&1
done
