#!/bin/sh

file="/sys/bus/pci/devices/0000:01:00.0/power/control"
content=$(<"$file")

if [[ "$content" == "on" ]]; then
        echo "auto" > "$file"

else
    echo "on" > "$file"
fi

cat "$file"
