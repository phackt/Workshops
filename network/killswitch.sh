#! /bin/bash

declare -a IPS_ARRAY

UFW_ENABLED=0
OVPN_FILE=""

# Displays help
function help(){
    echo "[!] Usage: $0 {start|stop} -i <ip>"
    echo "[!] Usage: $0 {start|stop} -f <config.ovpn>"
    exit 1
}

# Checking is root
if [ $(id -u) -ne 0 ]; then
    echo "[!] You'd better be root! Exiting..."
    exit
fi

if [ $# -ne 1 ] && [ $# -ne 3 ]; then
    help
fi

# Case first argument
case "${1}" in
start)
    shift
    while getopts "i:f:" OPT;do
        case "${OPT}" in
            i)
                echo "[*] VPN gateway ip: ${OPTARG}"
                IPS_ARRAY+=(${OPTARG})
                ;;
            f)
                OVPN_FILE="${OPTARG}"
                if [ ! -f "${OVPN_FILE}" ];then
                    echo -e "\e[31m[!] ${OVPN_FILE} not found.\e[0m"
                    exit 1
                fi

                # Dynamically find all VPN gateway ips
                echo "[*] finding VPN gateways ips"
                for gateway in $(cat "${OVPN_FILE}" | grep "remote " | cut -d' ' -f2)
                do
                    echo "[*] VPN gateway found: $gateway"
                    for ip in $(host $gateway | cut -d' ' -f4)
                    do
                        echo "[*] VPN gateway ip: ${ip}"
                        IPS_ARRAY+=($ip)
                    done
                done
                ;;
        esac
    done

    # Is ufw enabled
    ufw status | grep active &>/dev/null
    if [ $? -eq 0 ];
    then
        UFW_ENABLED=1
        echo "[*] saving ufw rules"
        cp /etc/ufw/user.rules /etc/ufw/user.rules.killswitch
        cp /etc/ufw/user6.rules /etc/ufw/user6.rules.killswitch
    fi

    echo "[*] resetting rules"
    # reset ufw settings
    ufw --force reset

    echo "[*] denying all"
    # set default behaviour of and enable ufw
    ufw default deny incoming
    ufw default deny outgoing

    echo "[*] allowing lan traffic"
    # allow local traffic
    ufw allow to 10.0.0.0/8
    ufw allow in from 10.0.0.0/8
    ufw allow to 172.16.0.0/12
    ufw allow in from 172.16.0.0/12
    ufw allow to 192.168.1.0/16
    ufw allow in from 192.168.1.0/16

    # in case of VPS
    ufw allow in 22/tcp

    echo "[*] allowing traffic over VPN interface tun0"
    # allow all traffic over VPN interface
    ufw allow in on tun0
    ufw allow out on tun0

    echo "[*] allowing all vpn gateway ip addresses"
    # allow vpn ip address
    for ip in ${IPS_ARRAY[@]}
    do
        echo "[*] ufw allow in from $ip to any"
        ufw allow out to $ip port 1198 proto udp
        ufw allow in from $ip port 1198 proto udp
    done        

    # setting DNS
    echo "[*] setting DNS"
    cp /etc/resolv.conf /etc/resolv.conf.killswitch && echo "nameserver 209.222.18.222" > /etc/resolv.conf
    ufw enable

    ;;
     
stop)

    echo "[*] resetting rules"
    # reset ufw settings
    ufw --force reset
    ufw disable

    if [ ${UFW_ENABLED} -eq 1 ];
    then
        echo "[*] restoring rules"
        cp /etc/ufw/user.rules.killswitch /etc/ufw/user.rules
        cp /etc/ufw/user6.rules.killswitch /etc/ufw/user6.rules
        ufw enable
    fi

    echo "[*] restoring DNS"
    cp /etc/resolv.conf.killswitch /etc/resolv.conf
    ;;

*)
    echo "[!] Usage: $0 {start|stop}"
    exit 1

    ;;
esac
