# dotfiles

## nvim installation

copy folder REPO/.config/nvim to local .config/nvim

install packer and install packages
```shell
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
```

errors at first start must be ignored and overpassed pressing enter key
then,
`:so`
`:PackerSync`
`:PackerCompile`
