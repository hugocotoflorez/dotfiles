#!/bin/bash


pacman -Qe | cut -d' ' -f1 > installed-packages.txt

SCRIPT_DIR="$( cd "$( dirname "$BASH_SOURCE[0]" )" && pwd )"
cd $SCRIPT_DIR
git add .
git commit -m "Auto Update"
git push origin main


