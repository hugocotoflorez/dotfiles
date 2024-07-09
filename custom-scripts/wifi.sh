#!/bin/bash
#
# wifi settings
#




function help()
{
    echo 'Wifi Manager [Hugo Coto]'
    echo 'Commands:'
    echo '--list    -l    list connections'
    echo '--state   -s    show current connection'
    echo '--connect -c    connect to new network'
    echo '--ui      -u    open a gui'
    echo '--fast    -f    fast connect (without password)'
    echo ''
}

function connect()
{
    echo 'New connection';
    L=$(nmcli device wifi list | grep -v "BSSID" | awk '{print $2}')
    o=($(echo -e "$L"))
    echo 'Network name: '
    select n in "${o[@]}"; do
        if [[ -n $n ]]; then
            break
        else
            echo "invalid network name"
        fi
    done
    read -p 'Password: ' -s p
    nmcli device wifi connect $n password $p
}

function fast_connect()
{
    echo 'Fast connection';
    L=$(nmcli device wifi list | grep -v "BSSID" | awk '{print $2}')
    o=($(echo -e "$L"))
    echo 'Network name: '
    select n in "${o[@]}"; do
        if [[ -n $n ]]; then
            break
        else
            echo "invalid network name"
        fi
    done
    nmcli device wifi connect $n
}

case $1 in
    '--help' | '-h')
        help;;
    '--list' | '-l')
        nmcli c | grep 'wifi';;
    '--state' | '-s')
        nmcli g;;
    '--ui' | '-u')
        nm-connection-editor;;
    '--connect' | '-c')
        connect;;
    '--fast' | '-f')
        fast_connect;;
    *)
        help;;
esac
