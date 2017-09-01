#!/bin/bash

cd "$(dirname "$0")"

FILE=./monitorstatus
MON=./sysmonitor.sh

# Every five minutes write the battery info
if [[ $(( $(date +%M) % 5 )) == 0 ]]; then

    "$MON" --file "$FILE" --all --silent

# Every minute write network info only
else

    "$MON" --file "$FILE" --wan --wifi --silent

fi

