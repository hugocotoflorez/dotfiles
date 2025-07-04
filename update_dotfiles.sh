#!/bin/bash

cd ~/dotfiles/nvim

pacman -Qe | cut -d' ' -f1 > installed-packages.txt

git add .
git commit -m "Auto Update"
git push origin main


