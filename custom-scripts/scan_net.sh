#!/bin/bash

# Detectar la IP local y calcular el rango de la subred
ip_local=$(hostname -i)
subred=$(echo $ip_local | awk -F"." '{print $1"."$2"."$3".0/24"}')

echo "Escaneando la red en la subred $subred..."
echo ""

# Usar nmap para escanear dispositivos conectados a la red
nmap_result=$(nmap -sP $subred)

# Extraer IPs de los dispositivos detectados
ips=$(echo "$nmap_result" | grep "Nmap scan report for" | awk '{print $5}')

echo "Dispositivos encontrados en la red:"
for ip in $ips; do
    # Intentar resolver el nombre de host usando getent hosts
    host=$(getent hosts $ip | awk '{print $2}')

    # Si getent no encuentra el hostname, intentar con avahi-resolve
    if [ -z "$host" ]; then
        host=$(avahi-resolve-address $ip 2>/dev/null | awk '{print $2}')
    fi

    # Si aún no encuentra el hostname, intentar con dig
    if [ -z "$host" ]; then
        host=$(dig -x $ip +short)
    fi

    # Si no se encuentra ningún hostname, mostrar "Sin hostname"
    if [ -z "$host" ]; then
        host="(Sin hostname)"
    fi

    echo -e "IP: $ip | Hostname: $host"
done

