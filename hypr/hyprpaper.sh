#!/bin/bash

killall hyprpaper

echo "preload = $1" > hyprpaper.conf
echo "#if more than one preload is desired then continue to preload other backgrounds" >> hyprpaper.conf
echo "#preload = /path/to/next_image.png" >> hyprpaper.conf
echo "" >> hyprpaper.conf
echo "wallpaper = eDP-1,   $1" >> hyprpaper.conf
echo "wallpaper = HDMI-A-1, $1" >> hyprpaper.conf
echo "" >> hyprpaper.conf
echo "#disable splash text rendering over the wallpaper" >> hyprpaper.conf
echo "splash = false" >> hyprpaper.conf
echo "" >> hyprpaper.conf
echo "#fully disable ipc" >> hyprpaper.conf
echo "# ipc = false" >> hyprpaper.conf

hyprpaper &!

