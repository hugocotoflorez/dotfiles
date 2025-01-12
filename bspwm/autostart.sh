#!/bin/sh

pgrep -x sxhkd > /dev/null || sxhkd &

picom &

~/.fehbg

~/.config/polybar/launch.sh

kitty

unclutter --start-hidden &
