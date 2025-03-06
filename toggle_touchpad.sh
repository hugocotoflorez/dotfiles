#!/bin/bash

file="/sys/bus/pci/devices/0000:01:00.0/power/control"
content=$(<"$file")

if [[ "$content" == "on" ]]; then
        sudo bash -c "echo 'auto' > $file"

else
    sudo bash -c "echo 'on' > $file"
fi

cat "$file"
