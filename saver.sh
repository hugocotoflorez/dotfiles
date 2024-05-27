#!/bin/sh

: ${XSECURELOCK_IMAGE_PATH:=$HOME/Documents/BeOnp1g.jpeg}

/usr/bin/feh --zoom=fill --window-id="${XSCREENSAVER_WINDOW}" -F "${XSECURELOCK_IMAGE_PATH}"
