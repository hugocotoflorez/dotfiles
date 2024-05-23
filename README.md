# dotfiles

## nvim installation

### quick setup

clone this repo
```shell
git clone https://github.com/hugocotoflorez/dotfiles
```

create a simlink (nvim folder in .config must not exist)
```shell
ln -s <repo path>/nvim ~ln -s <repo path>/nvim ~/.config/nvim.config/nvim
```

install packer
```shell
git clone --depth 1 https://github.com/wbthomason/packer.nvim\
 ~/.local/share/nvim/site/pack/packer/start/packer.nvim
```

errors at first start must be ignored and overpassed pressing enter key
then,
`:so`
`:PackerSync`
`:PackerCompile`
