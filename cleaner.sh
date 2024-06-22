#!/bin/sh

sudo pacman -Sc # uninstalled packages cache
sudo pacman -Scc # installed packages cache
sudo pacman -Rns $(pacman -Qtdq) # remove unused packages
sudo rm -rf ~/.cache/* # remove cache in home
# rmlint /home/hugo # remove duplicates
echo "rmlint.sh generated"
