#!/bin/bash

echo -e "\e[40m---- Battery -----\e[0m"

printf "\e[34mBattery level: \e[1m%s%%\e[0m\n" \
$(cat /sys/class/power_supply/BAT1/capacity)

printf "\e[34mStatus: \e[1m%s\e[0m\n" \
$(cat /sys/class/power_supply/BAT1/status)

printf "\e[34mCapacity: \e[1m%s\e[0m\n" \
$(cat /sys/class/power_supply/BAT1/capacity_level)

echo -e "\e[40m------------------\e[0m"
