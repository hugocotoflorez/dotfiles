#!/bin/sh

# designed for HDMI-1.
# ! The monitor should be powered on (polybar chashes)

bspc monitor HDMI-1 -d VI VII VIII IX X
bspc monitor eDP-1 -d I II III IV V
~/.screenlayout/home_dual.sh &
sleep 1
~/.config/polybar/launch.sh &
~/.fehbg # no se porque se descuadra el fondo pero lo soluciona

