#!/bin/bash
sudo bash -c "which reflector && reflector -c fr -n 10 > /etc/pacman.d/mirrorlist"
sudo pacman -Syyu --noconfirm
yay --noconfirm
