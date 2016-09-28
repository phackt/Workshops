import sys
import subprocess
import os

###################################################
# main procedure
###################################################
def main(argv):

    # check that we have at least one ip to test
    if(len(argv) != 3):
        print('Incorrect number of arguments:')
        print(argv[0] + ' <target_ip_1> <target_ip_2>')
        # by convention return code on Unix system is 2 for command line error
        sys.exit(2)
    
    # for each ip passed as argument we are testing is arp poisoning is successful
    target_ip_1 = argv[1]
    target_ip_2 = argv[2]
    
    # if ip has been correctly spoofed
    spoofed = {}
    spoofed[target_ip_1]=icmp_request(target_ip_2, target_ip_1)
    spoofed[target_ip_2]=icmp_request(target_ip_1, target_ip_2)

    # testing spoofed ips
    if(spoofed[target_ip_1] and spoofed[target_ip_2]):
        print('Poisoning successful!!!')
        sys.exit(0)
    elif(not(spoofed[target_ip_1] or spoofed[target_ip_2])):
        sys.exit('No poisoning at all!!!')

    #At least one in non poisoned
    sys.exit(1)

###################################################
# launching icmp echo request to test arp poisoning
###################################################
def icmp_request(ip_dest, ip_spoofed):

    # using hping3 tool to send spoofed icmp requests
    try:
        command='hping3 -c 3 -n -q -1 -a ' + ip_spoofed + ' ' + ip_dest

        p = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, shell=True)
        #(output, err) = p.communicate()
        p_status = p.wait()
        
        if p_status != 0:
            print('No poisoning between ' + ip_dest + ' and ' + ip_spoofed)
            return False

        return True
    except:
        print('Unexpected error: ', sys.exc_info()[0]) 
        sys.exit('Exception raised with command: ' + command)

###################################################
# only for command line
###################################################
if __name__ == '__main__':
    if os.geteuid() != 0:
        sys.exit("You need to have root privileges to run this script.")

    main(sys.argv)
