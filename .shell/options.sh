#!/bin/sh

# COPE=$(cope_path) # colorize tool path

HISTFILE=~/.zsh_history
HISTSIZE=1000
SAVEHIST=$HISTSIZE

bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

setopt appendhistory
setopt sharehistory
setopt hist_ignore_space

autoload -U compinit;  compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)EZA_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'



