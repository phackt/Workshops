#! /bin/bash

#####################################
# Displays help
#####################################

function help(){
    echo "Usage: $0 [-f <input file>]"
    echo "       [-f] search input emails in file instead of stdin"
    exit 1
}

if [ $# -ne 2 ] && [ $# -ne 0 ];then
    help
fi

#####################################
# Getting options
#####################################
while getopts "f:" OPT;do
    case ${OPT} in
        f)
            INPUT_FILE=${OPTARG}
            echo "[*] input file: ${INPUT_FILE}"
            ;;
        :)
            echo "Invalid option ${OPT}"
            help
            ;;
    esac
done

#####################################
# Function check emails
#####################################
function check_email(){

    email=$1
    echo "[*] check email $1"

    # check for email found
    haveibeenpwned ${email}

    # check for others domains
    for domain in gmail.com yahoo.com ymail.com hotmail.com;do

        # do not repeat request for existing domain found in input
        original_domain=$(echo -n $1 | cut -d@ -f2)

        if [ "${domain}" != "${original_domain}" ];then
            email=$(echo -n $1 | cut -d@ -f1)"@${domain}"
            echo "[*] check email ${email}"
            haveibeenpwned ${email}
        fi
    done
}

#####################################
# Function haveibeenpwned.com API
#####################################
function haveibeenpwned(){

    # request haveibeenpwned
    response=$(curl --silent https://haveibeenpwned.com/api/breachedaccount/$1)
    if [ "X""${response}" != "X" ];then
        echo  "FOUND: $1 pwned in "${response}
    fi

    # https://haveibeenpwned.com/API/v2#AcceptableUse
    # Requests to the breaches and pastes APIs are limited to one per every 1500 milliseconds
    sleep 1.5
}

#####################################
# Reading emails
#####################################
echo "[!] haveibeenpwned API needs 1500 milliseconds between requests"

if [ "X" != "X"${INPUT_FILE} ];then

    #read from file
    for email in $(cat results_all.txt | grep -o '[^ ]*@[^ ]*');do 
        check_email ${email}
    done

else

    # read from stdin
    echo -n "Enter email: "
    read email
    check_email ${email}

fi
