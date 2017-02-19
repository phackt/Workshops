# PenTest & Tools
Some tools and POCs in order to test several kind of techniques.
  
## mitm
  
 - **phising**  
 A script launching an MITM attack and redirecting a specific domain to our phising web page.
  
 - **http_proxy**  
 A proxy that aims at stripping all https web page links and keeping unsecure connection with the proxy (VICTIM <-- **HTTP** --> MITMPROXY
  
## fingerprint  

 - **lowhanging.sh**  
 A script used during the first steps of the OSCP Lab network's discovery.
  
## privesc  
  
 - **LinEnum.sh** (original one is here: [https://github.com/rebootuser/LinEnum](https://github.com/rebootuser/LinEnum))
 A famous privesc script for Linux customized a little bit:

   - check for SELinux
   - check for adm group's users
   - display raw /etc/fstab
   - add some recommendations  

 - **privesc.bat**
 A privesc script for windows using accesschk.exe (needed to be uploaded in the same time, check [sysinternals](https://technet.microsoft.com/fr-fr/sysinternals/bb842062))

## network  

 - **killswitch.sh**  
 Forces traffic through VPN - no leakage if VPN shuts down
  
## algo  

 - **bruteforce**  
 Bruteforce algorithm with permutations and fixed position characters