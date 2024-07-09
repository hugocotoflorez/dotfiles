#!/bin/sh

function command_not_found_handler(){echo -e "\e[31m$1??"}

function github(){
    firefox "https://github.com/hugocotoflorez/$1" &!
    exit
}
