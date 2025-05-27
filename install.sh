#!/bin/bash

sudo ./sysupdate.sh

yay -S --noconfirm --needed `cat ./installed-packages.txt`

./deploy.sh ./MANIFEST
sudo ./deploy.sh ./MANIFEST
