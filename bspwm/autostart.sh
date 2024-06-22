#!/bin/sh

SAVER="$HOME/dotfiles/saver.sh"
export XSECURELOCK_SAVER=$SAVER
export XSECURELOCK_PASSWORD_PROMPT='asterisks'

pgrep -x sxhkd > /dev/null || sxhkd &

picom &

~/.fehbg


~/.config/polybar/launch.sh

alacritty &

unclutter --start-hidden &

xsetroot -cursor_name left_ptr
xset s 300 5
# uncomment to enable password after suspend
#xss-lock -n /usr/lib/xsecurelock/dimmer -l -- xsecurelock &
