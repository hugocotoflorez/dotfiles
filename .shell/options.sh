#!/bin/sh
COPE=$(cope_path) # colorize tool path
HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=1000
setopt appendhistory
autoload -U compinit;  compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors 'di=01;34:*.h=04;36:*.c=04;32'
