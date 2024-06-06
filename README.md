

### quick setup

clone this repo
```shell
git clone https://github.com/hugocotoflorez/dotfiles
```

create a simlink (nvim folder in .config must not exist)
```shell
ln -s <repo path>/nvim ~/.config/nvim.config/nvim
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


## remaps

Using custom keymap (via customization)
 - Layer 0      \\
 Default qwerty us\\
 - Layer 1 ( toggle on Fn1 )\\
 Arrow keys in hjkl\\
 - Layer 2 ( hold space )\\
 Nums in home row\\
 symbols in q row\\
 \~ in tab\\
 - Layer 3 ( toggle in Fn2 )\\
 Mouse movement in hjkl\\
 Whell scroll in a, s\\
 mouse click in d, f\\
\\
 -On every layer\\
 caps lock (hold) -> control\\
 caps lock (tap) -> escape\\
\\
 Also some functionality keys in some layer\\



## shell

Files are split into scripts in .shell



