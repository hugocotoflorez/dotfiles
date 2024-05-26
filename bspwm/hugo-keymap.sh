#!/bin/sh

setxkbmap -option lv3:alt_switch -option caps:ctrl_modifier hugo
xcape -e 'Caps_Lock=Escape'
echo "Hugo layot set!"

