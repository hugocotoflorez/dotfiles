#!/bin/bash

exist() { command -v "$1" >/dev/null 2>&1; }

function clone_install() {
        if [ -d "$1" ]; then
                rm -rf "$1"
        fi
        if ! exist "$1"; then
                git clone "https://github.com/hugocotoflorez/$1"
                cd "$1"
                make install
                cd ..
        fi
}

if ! exist yay; then
        sudo pacman -S --needed git base-devel
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si
fi

sudo ls -s default.conf /etc/keyd
sudo ls -s pacman.conf /etc

git submodule update --init nvim
sudo pacman -Syyu --noconfirm

rm ~/.* -rf

mkdir -p ~/.config
mkdir -p ~/.local/bin
mkdir -p ~/.local/share/applications

./deploy.sh ./MANIFEST
sudo ./deploy.sh ./MANIFEST

clone_install tetris
clone_install todo
clone_install hfetch

yay -S --needed --noconfirm `cat ./installed-packages.txt`

