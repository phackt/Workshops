#!/bin/bash

#####################################
# Aims at automating some bug bounty recon
#####################################

#####################################
#####################################
# Variables section
#####################################
#####################################
TOOLS_DIR="${HOME}/tools/"
WORK_DIR="${HOME}/recon/"
LOG_DIR=""
WORDS_FILE=""
DOMAIN=""
SCAN=0
ALTDNS=0

# Script directory
SCRIPT_DIR=$(dirname $(readlink -f $0))

# *****************
# Update these ones
# *****************
ALTDNS_DIR="${HOME}/Documents/repo/altdns/"
ALTDNS_WORDLIST="${ALTDNS_DIR}/words.txt"
AQUATONE_DIR="${HOME}/aquatone/"
KNOCKTONE_DIR="${HOME}/Documents/repo/pentest/fingerprint/knocktone/"

#####################################
#####################################
# Help
#####################################
#####################################
function help(){
    echo "Usage: $0 -d domain"
    echo "       -d domain        :domain to attack"
    echo "       -f file          :file used for subdomains words (launch subdomains discover)"
    echo "       -a               :launch altdns on subdomains found"
    echo "       -s               :launch scan on aquatone data"
    echo "Example of command:"
    echo "$0 -d yahoo.com -f /home/batman/dns/bitquark_subdomains_top100K.txt"
    exit 1
}

if [[ $# -lt 3 && $# -gt 6 ]];then
    help
fi

#####################################
#####################################
# Getting options
#####################################
#####################################
while getopts "d:f:sa" OPT;do
    case "${OPT}" in
        d)
            DOMAIN="${OPTARG}"
            LOG_DIR="${WORK_DIR}/${DOMAIN}/log"
            ;;
        f)
            WORDS_FILE="${OPTARG}"
            if [ ! -f "${WORDS_FILE}" ];then
                echo -e "\e[31m[!] ${WORDS_FILE} not found.\e[0m"
                exit 1
            fi
            ;;
        s)
            SCAN=1
            ;;
        a)
            ALTDNS=1
            ;;
        :)
            echo -e "\e[31m[!] Invalid option ${OPT}\e[0m"
            help
            ;;
    esac
done

#####################################
#####################################
## Global actions
#####################################
#####################################

# Create working directory
rm -rf ${WORK_DIR}/${DOMAIN} && mkdir -p ${WORK_DIR}/${DOMAIN}/log

#####################################
# Check aquatone is installed
#####################################
aquatone-discover -h &>/dev/null || \
(curl -sL https://deb.nodesource.com/setup_8.x | sudo -E bash - && apt-get install -y nodejs && gem install aquatone)
if [ $? -ne 0 ];then
    echo -e "\e[31m[!] Fail to install aquatone from 'gem install aquatone'\e[0m"
    exit 1
fi

#####################################
# Check altdns is installed
#####################################
${ALTDNS_DIR}/altdns.py -h &>/dev/null || \
(rm -rf ${ALTDNS_DIR} && git clone https://github.com/phackt/altdns.git ${ALTDNS_DIR} && pip install -r ${ALTDNS_DIR}/requirements.txt)
if [ $? -ne 0 ];then
    echo -e "\e[31m[!] Fail to install altdns from 'https://github.com/phackt/altdns.git'\e[0m"
    exit 1
fi

#####################################
# Check awscli is installed
#####################################
aws s3 help &>/dev/null || (sudo apt-get install -y awscli && aws configure)
if [ $? -ne 0 ];then
    echo -e "\e[31m[!] 'sudo apt-get install -y awscli && aws configure' failed\e[0m"
    exit 1
fi

#####################################
# Check firefox is installed
#####################################
firefox -h &>/dev/null || sudo apt-get install -y firefox
if [ $? -ne 0 ];then
    echo -e "\e[31m[!] 'sudo apt-get install -y firefox' failed\e[0m"
    exit 1
fi

#####################################
#####################################
## Recon using in // aquatone and knocktone
#####################################
#####################################

# Start subdomains discover
if [[ "X${WORDS_FILE}" != "X" && "X${DOMAIN}" != "X" ]];then

    #####################################
    # Launch of aquatone-discover
    #####################################
    echo -e "\e[33m[*] Launch aquatone-discover for subdomains discover\e[0m"

    aquatone-discover --domain ${DOMAIN} --wordlist ${WORDS_FILE}

    #####################################
    # Launch knocktone.py in xterm (look for aliases and subdomains takeover)
    #####################################
    echo -e "\e[33m[*] Launch knocktone subdomains discover\e[0m"

    cat ${AQUATONE_DIR}/${DOMAIN}/hosts.txt | cut -d, -f1 | sort -u > ${WORK_DIR}/${DOMAIN}/hosts.txt

    nohup xterm -T "knocktone DNS discover on domain ${DOMAIN}" -hold -e \
    "${KNOCKTONE_DIR}/knocktone.py dns ${WORK_DIR}/${DOMAIN}/hosts.txt | tee ${LOG_DIR}/xterm_knocktone_dns.txt" &

	#####################################
	# Bruteforce found subdomains with altdns permutations
	#####################################
	if [ ${ALTDNS} -eq 1 ];then

	    ALTERED_WORDS_FILE=${WORK_DIR}/${DOMAIN}/altdns.altered

	    echo -e "\e[33m[*] Launch altdns to generate permutations\e[0m"
    	    ${ALTDNS_DIR}/altdns.py -w ${ALTDNS_WORDLIST} -i ${WORK_DIR}/${DOMAIN}/hosts.txt -o ${ALTERED_WORDS_FILE} -n -t 10

	    #####################################
	    # Launch the amazing knocktone.py
	    #####################################
	    echo -e "\e[33m[*] Launch knocktone to resolve permutations\e[0m"
	    ${KNOCKTONE_DIR}/knocktone.py dns ${ALTERED_WORDS_FILE}

	    # Add the permuted subdomains resolved to the hosts.txt, hosts.json files from first aquatone-discover
	    # knocktone.py concat file1 file2 output_file
	    ${KNOCKTONE_DIR}/knocktone.py concat ${KNOCKTONE_DIR}/hosts.json ${AQUATONE_DIR}/${DOMAIN}/hosts.json ${AQUATONE_DIR}/${DOMAIN}/hosts.json

	    # Do the same with txt result files
	    # N.B: altdns outputs only permutations, not original subdomains
	    (cat ${KNOCKTONE_DIR}/hosts.txt ${AQUATONE_DIR}/${DOMAIN}/hosts.txt | sort -u > /tmp/sorted_hosts.txt) && \
	    mv /tmp/sorted_hosts.txt ${AQUATONE_DIR}/${DOMAIN}/hosts.txt
	fi

    #####################################
    ## Launch aquatone-scan, gather and takeover on all subdomains scope
    #####################################
    echo -e "\e[33m[*] Launch aquatone scan, gather, and takeover discover\e[0m"

    aquatone-scan --domain ${DOMAIN} --ports huge && \
    aquatone-gather --domain ${DOMAIN} && \
    aquatone-takeover --domain ${DOMAIN}

    echo -e "\e[33m[*] Opening aquatone html report\e[0m"
    firefox ${AQUATONE_DIR}/${DOMAIN}/report/*.html &>/dev/null &

# End of subdomains discover
fi

#####################################
#####################################
## Perform some post scan actions
#####################################
#####################################

# Start post discover actions
if [[ ${SCAN} -eq 1 && "X${DOMAIN}" != "X" ]];then

    #####################################
    # Custom scan on headers found
    ##################################### 
    echo -e "\e[33m[*] Launch knocktone scan on headers found\e[0m"

    nohup xterm -T "knocktone SCAN on domain ${DOMAIN}" -hold -e "${KNOCKTONE_DIR}/knocktone.py scan ${DOMAIN} | tee ${LOG_DIR}/xterm_knocktone_scan.txt" &

    #####################################
    # Stats on server found
    #####################################
    echo -e "\e[33m[*] Statistics about servers\e[0m"
    cat ${AQUATONE_DIR}/${DOMAIN}/headers/* | grep 'Server:' | sort | uniq -c | sort -nr

    #####################################
    # Look for subdomains in html pages gathered by aquatone
    #####################################
    echo -e "\e[33m[*] Look for new subdomains in gathered html pages\e[0m"

    domain_regexp=$(echo ${DOMAIN} | sed 's/\./\\./g')
    cat ${AQUATONE_DIR}/${DOMAIN}/html/* | egrep -o '[a-z0-9\-\_\.]+\.'${domain_regexp} | sort -u > ${WORK_DIR}/${DOMAIN}/subdomainsinhtml.txt

    while read subdomain;do
        grep ${subdomain} ${AQUATONE_DIR}/${DOMAIN}/hosts.txt &>/dev/null
        if [ $? -eq 1 ];then
            echo -e "\e[32m[!] New subdomain found: ${subdomain}\e[0m"
        fi
    done < ${WORK_DIR}/${DOMAIN}/subdomainsinhtml.txt

    #####################################
    # Look for amazon s3 servers in html pages
    #####################################
    echo -e "\e[33m[*] Look for new s3 servers in gathered html pages\e[0m"

    domain_regexp="[a-zA-Z0-9\.\-]*(s3-|s3.).*\.?amazonaws\.com[a-zA-Z0-9\.\-\/]*"
    cat ${AQUATONE_DIR}/${DOMAIN}/html/* | egrep -o "${domain_regexp}" | sort -u > ${WORK_DIR}/${DOMAIN}/s3bucketsinhtml.txt

    while read bucket;do
        echo -e "\e[32m[!] AWS S3 url found: ${bucket}\e[0m"

        # We are saving the prefixes
        # echo ${bucket%*${domain_regexp}} >> ${WORK_DIR}/${DOMAIN}/s3bucketsinhtml_prefixes.txt
    done < ${WORK_DIR}/${DOMAIN}/s3bucketsinhtml.txt

    #####################################
    # Look for s3 buckets (aws cli)
    #####################################
    echo -e "\e[33m[*] Bruteforce s3 buckets\e[0m"

    domain_regexp=$(echo .${DOMAIN} | sed 's/\./\\./g')

    while read domain; do
        domain=$(echo ${domain} | cut -d, -f1)
        domain_with_hyphens=$(echo ${domain} | sed 's/\./-/g')
        prefix=$(echo ${domain%.*})

        # We are saving the prefixes and domain found
        echo ${domain} >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
        echo ${domain_with_hyphens} >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
        echo ${prefix} >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
    done < ${AQUATONE_DIR}/${DOMAIN}/hosts.txt

    echo ${DOMAIN} >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
    echo ${DOMAIN%.*}  >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt

    # We are concatenating the s3 buckets found in html pages with the subdomains prefixes (and got uniq sorted strings)
    if [ -f "${WORK_DIR}/${DOMAIN}/s3bucketsinhtml_prefixes.txt" ];then
        cat ${WORK_DIR}/${DOMAIN}/s3bucketsinhtml_prefixes.txt >> ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
    fi

    (cat ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt | sort -u > /tmp/all_buckets_prefixes.txt) && \
    mv /tmp/all_buckets_prefixes.txt ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt

    #####################################
    # Launch awscli and try to read/update bucket
    #####################################
    echo "Hacked" > haxor.txt

    while read bucket;do
        echo -e "\n\e[33m[*] Look for bucket ${bucket}\e[0m"
        
        # Try to read bucket
        aws s3 ls s3://${bucket} 2>&1
        if [ $? -eq 0 ];then
            echo -e "\e[33m[!] Bucket ${bucket} is readable\e[0m" | tee -a ${LOG_DIR}/readable_buckets_found.txt
        fi

        # Try to write bucket
        aws s3 mv haxor.txt s3://${bucket} 2>&1
        if [ $? -eq 0 ];then
            echo -e "\e[33m[!] Bucket ${bucket} is writable\e[0m" | tee -a ${LOG_DIR}/${DOMAIN}/writable_buckets_found.txt
        fi
    done < ${WORK_DIR}/${DOMAIN}/all_buckets_prefixes.txt
    rm -f haxor.txt

# End of post discover actions
fi

#####################################
#####################################
# End of script
#####################################
#####################################
echo "[*] End of program"
exit 0
