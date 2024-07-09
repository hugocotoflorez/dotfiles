#!/bin/bash

# -f full screen width
# -mb, -mr, -ml margin bottom, right, left
# -d auto hide
# -i icon size (def 48)
# -l layer ("overlay", "top", "bottom")
# -nolauncher dont show launcher button
# -r resident without hotspot
ARGS='-mb 5 -mt 5 -nolauncher -x -i 36'

nwg-dock-hyprland $ARGS
