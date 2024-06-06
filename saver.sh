#!/bin/sh

: ${XSECURELOCK_IMAGE_PATH:=$HOME/Pictures/8-bit-10.jpg}
/usr/bin/feh --zoom=fill --window-id="${XSCREENSAVER_WINDOW}" -F "${XSECURELOCK_IMAGE_PATH}"
