#!/bin/bash

#####################################
# From https://phackt.com/web-exposed-git-repositories
#
# Gathering some information from web exposed git repositories
# 
#####################################

#####################################
#
# Variables section
#
#####################################

declare -A INPUT_FILES

TIMEOUT=5
USERAGENT="Mozilla/5.0 (Windows NT 6.1; WOW64; rv:54.0) Gecko/20100101 Firefox/54.0"
URL=""
BRANCHES=()

# Script directory
SCRIPT_DIR=$(dirname $(readlink -f $0))
SCRIPT_NAME=$(basename $(readlink -f $0))
WORKDIR="/tmp/$(cat /proc/sys/kernel/random/uuid)"

# Useful for git ls-remote
export GIT_TERMINAL_PROMPT=0

# Check existence of git
git --help &>/dev/null
if [ $? -ne 0 ];then
	echo -e "\e[31m[!] git client is missing: run 'sudo apt install git'\e[0m"
	exit 1
fi

#####################################
#
# Help
#
#####################################
function help(){
    echo "Usage: $0 -u git_url"
    echo
    echo "Example of command:"
    echo "${SCRIPT_NAME} -u https://monsite.com/.git/"
    exit 1
}

if [ $# -ne 2 ];then
    help
fi

#####################################
#
# Getting options
#
#####################################
while getopts "u:" OPT;do
    case "${OPT}" in
        u)
            URL="${OPTARG}"
            if [ "${URL: -1}" != "/" ];then
                URL=${URL}"/"
            fi
            echo -e "\e[33m[*] Looking for url: ${URL}\e[0m"
            ;;
        :)
            echo -e "\e[31m[!] Invalid option ${OPT}\e[0m"
            help
            ;;
    esac
done

# Delete work dir if exists
(rm -rf ${WORKDIR} && mkdir ${WORKDIR}) &>/dev/null

#####################################
#
# Functions declaration
#
#####################################
function check_traversal_dir(){
    test $(curl -k -s -A "${USERAGENT}" --fail --connect-timeout ${TIMEOUT} "${URL}" | grep -e "\"HEAD\"" -e "\"refs/\"" | wc -l) -eq 2
    echo $?
}

function get_branches(){
	curl -k -s -A "${USERAGENT}" --fail --connect-timeout ${TIMEOUT} "${URL}config" > "${WORKDIR}/config"
    
    while read branch;do
        BRANCHES+=("${branch}")
    done < <(grep "\[branch " "${WORKDIR}/config" | cut -d"\"" -f2)

    # Check if branch master has been found, otherwise we force the search
    hasmaster=0
    for element in "${BRANCHES[@]}";do if [ "${element}" == "master" ];then hasmaster=1;break;fi;done

    if [ ${hasmaster} -eq 0 ];then
    	BRANCHES+=("master")
    fi
}

function get_last_commit(){
    curl -k -s -A "${USERAGENT}" --fail --connect-timeout ${TIMEOUT} "${URL}logs/refs/heads/$1" | tail -1
}

#####################################
#
# Scanning url
#
#####################################
isdirlist=$(check_traversal_dir)

get_branches

# check directory listing
if [ ${isdirlist} -eq 0 ];then
    echo -e "\e[32m[*] [directory listing OK]\e[0m"
fi

for branch in "${BRANCHES[@]}"
do
	lastcommit="$(get_last_commit ${branch})"

	# Checking if at least logs/refs/heads/master exists
	echo "${lastcommit}" | grep "</html>" &>/dev/null
	validlog=$?

	# Looking for valid master lastcommit
	if [ "${branch}" == "master" -a ${validlog} -eq 0 ];then continue;fi

    timestamp=$(echo "${lastcommit}" | cut -d$'\t' -f1 | rev | awk '{print $2}' | rev)
    timestamp_str="$(date +'%d-%m-%Y %H:%M:%S' -d@${timestamp})"
    echo -e "\e[32m[*] [${timestamp_str}]\e[0m last commit for branch \e[32m[${branch}]\e[0m:"
    echo "${lastcommit}"
done

#######################
#
# Looking for .git/config
#
#######################

# Colorize useful information
echo -e "\n\e[33m[*] ${URL}config:\e[0m"
grep -i -P --color=always '(url *= *.*|\[credential\]|\[user\]|.*pass.*|$)' "${WORKDIR}/config" 2>/dev/null | sed -z 's/\n*$/\n/g'

#######################
#
# Looking for .gitignore
#
#######################
# fail will return a code 22 if http status code != 2xx
tempurl="$(echo ""${URL}"" | sed 's/[^\/]*\/$//g').gitignore"
curl -k -s -A "${USERAGENT}" --fail --connect-timeout ${TIMEOUT} "${tempurl}" > "${WORKDIR}/.gitignore" && \
	[ "X$(grep -i '<html>' ""${WORKDIR}/.gitignore"")" == "X" ] && \
	echo -e "\n\e[33m[*] ${tempurl}:\e[0m" && \
	cat "${WORKDIR}/.gitignore" | grep -v '^ *#' | sed -z 's/\n*$/\n/g'

#######################
#
#Looking for public HTTP repositories
#
#######################
echo
while read repo;do

	# trying to switch from ssh to https (if HTTP service is allowed for cloning)
	echo "${repo}" | grep "^git@" &>/dev/null
	if [ $? -eq 0 ];then
		repo="$(echo ""${repo}"" | sed 's/git@/https:\/\//g' | sed 's/\(.*\):/\1\//')"
	fi

	echo "${repo}" | grep "^ssh:\/\/" &>/dev/null
	if [ $? -eq 0 ];then
		repo="$(echo ""${repo}"" | sed 's/^ssh/https/g')"
	fi

	# git ls-remote
	git -c http.userAgent="${USERAGENT}" -c http.sslVerify=false -c user.email=git-sync@noreply.com -c user.name=git-sync ls-remote "${repo}" &> /dev/null
	if [ $? -eq 0 ];then
		echo -e "\e[32m[*] Repository '${repo}' can be accessed\e[0m"
	fi

done < <(grep -E 'url *= *(http(s)?:|git@|ssh:).*' "${WORKDIR}/config" | cut -d"=" -f2 | sed 's/ //g')

# delete work dir 
rm -rf "${WORKDIR}/config" &>/dev/null
