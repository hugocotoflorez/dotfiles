#!/bin/bash

exist() { command -v "$1" >/dev/null 2>&1; }

if ! exist yay; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
fi

sudo ./sysupdate.sh

yay -S --noconfirm --needed `cat ./installed-packages.txt`

./deploy.sh ./MANIFEST
sudo ./deploy.sh ./MANIFEST
