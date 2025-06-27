#!/bin/bash

cd ~/dotfiles
git add .
git commit -m "Auto Update"
git push origin main

cd ~/dotfiles/nvim
git add .
git commit -m "Auto Update"
git push origin main

