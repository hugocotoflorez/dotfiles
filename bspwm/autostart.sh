#!/bin/sh

pgrep -x sxhkd > /dev/null || sxhkd &

picom &

~/.fehbg

~/.config/polybar/launch.sh

alacritty

unclutter --start-hidden &

xsetroot -cursor_name left_ptr

xset s 300 5

export XSECURELOCK_PASSWORD_PROMPT='asterisks'
xss-lock -n /usr/lib/xsecurelock/dimmer -l -- xsecurelock &
