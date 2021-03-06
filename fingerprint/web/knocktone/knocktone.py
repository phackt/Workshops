#!/usr/bin/env python2
# -*- coding: utf8 -*-
import json, sys, argparse, collections, uuid
import dns.resolver
from termcolor import colored
from utils.common import *
from utils.config import config_data, get_knocktone_filepath
from bs4 import BeautifulSoup

###################################################
# knocktone is a swiss-knife in DNS recon
###################################################

##################################################
# Resolve domains
# Generate Subdomains list
# Convert knockpy output file for input of aquatone-scan
# Scan aquatone headers previously found by aquatone-scan
##################################################

# variables
aquatone_homedir = os.environ['HOME'] + os.sep + 'aquatone'
aquatone_json_data = {}
aquatone_csv_data = ''

###################################################
# main procedure
###################################################
def main(argv):

    global config_data
    global aquatone_homedir

    # Main variables
    create_files=True

    # Parse input args
    parser = argparse.ArgumentParser(prog='knocktone.py', description='A swiss-knife for DNS recon methodoly', formatter_class=argparse.RawTextHelpFormatter)
    subparsers = parser.add_subparsers(dest='action')

    # create the parser for the command convert
    parser_convert = subparsers.add_parser('convert', help='convert knockpy for aquatone-scan')
    parser_convert.add_argument('input_file', help='knockpy json input file')

    # create the parser for the command dns
    parser_dns = subparsers.add_parser('dns', help='resolve domains list')
    parser_dns.add_argument('input_file', help='domains file')

    # create the parser for the command generate
    parser_generate = subparsers.add_parser('generate', help='generate subdomains list')
    parser_generate.add_argument('input_file', help='words file')
    parser_generate.add_argument('domain', help='domain used in subdomains generation')

    # create the parser for the command scan
    parser_generate = subparsers.add_parser('scan', help='scan aquatone headers previously gathered')
    parser_generate.add_argument('domain', help='domain in aquatone directory')

    # create the parser for the command concat
    parser_generate = subparsers.add_parser('concat', help='concat hosts.json files from aquatone-discover')
    parser_generate.add_argument('input_file_1', help='first input file hosts.json')
    parser_generate.add_argument('input_file_2', help='second input file hosts.json')
    parser_generate.add_argument('output_file', help='output file')

    args = parser.parse_args()

    # Select action
    if args.action == 'convert':
        file_exists(args.input_file)
        aquatone_format(args.input_file)
    elif args.action == 'dns':
        file_exists(args.input_file)
        dns_resolve_from_file(args.input_file)
    elif args.action == 'generate':
        # No need to generate hosts files
        create_files=False
        file_exists(args.input_file)
        generate_subdomains(args.input_file,args.domain)
    elif args.action == 'scan':
        aquatone_headersdir = aquatone_homedir + os.sep + args.domain + os.sep + config_data['aquatone_headersdir']
        # No need to generate hosts files
        create_files=False
        dir_exists(aquatone_headersdir)
        check_aquatonescan_headers(aquatone_headersdir)
    elif args.action == 'concat':
        # No need to generate hosts files
        create_files=False
        file_exists(args.input_file_1)
        file_exists(args.input_file_2)
        concat_aquatone_hosts_files(args.input_file_1,args.input_file_2,args.output_file)

    # Creating hosts files for aquatone-scan (csv,json)
    if create_files:
        create_json(get_knocktone_filepath(config_data['aquatone_json_output_file']),aquatone_json_data);
        create_csv(get_knocktone_filepath(config_data['aquatone_csv_output_file']),aquatone_csv_data);

###################################################
# convert knockpy output json file into 
# csv and json aquatone expected format
###################################################
def aquatone_format(knockpy_input_file):

    global aquatone_json_data
    global aquatone_csv_data

    # Reading knockpy input file
    with open(knockpy_input_file) as input_file:

        # Loading knockpy json data
        data = json.load(input_file)
        
        # Retrieving domain
        aquatone_json_data[data['target_response']['target']] = data['target_response']['ipaddress'][0]
        aquatone_csv_data += '%s,%s\n' % (data['target_response']['target'],data['target_response']['ipaddress'][0])

        for subdomain in data['subdomain_response']:
            
            # Retrieving subdomains
            aquatone_json_data[subdomain['target']] = subdomain['ipaddress'][0]
            aquatone_csv_data += '%s,%s\n' % (subdomain['target'],subdomain['ipaddress'][0])

            # Printing if alias found for further investigation (subdomain takeover)
            if(subdomain['alias']):
                print colored('Alias found for %s (%s)' % (subdomain['target'],', '.join(subdomain['alias'])),'yellow')

                # We are looping on each alias and resolve them
                print_unresolved_alias(subdomain['alias'])
 
###################################################
# read a list of a list of domains
###################################################
def dns_resolve_from_file(file):

    global aquatone_json_data
    global aquatone_csv_data
    nb_processed = 0
    nb_domains = 0
    all_ips = set()

    # Opening the file with subdomains
    with open(file) as domains_input_file:

        # Delete newline
        domains = domains_input_file.read().splitlines()
        nb_domains = len(domains)

        print 'Resolving file %s with %d domains' % (file,nb_domains)

        # define a set of ips resolving multicard domains
        wildcard_ips = get_wildcard_ips(domains)
        checked_ips = set()

        #########################
        # Looping on every subdomain
        #########################
        for domain in domains:

            # DNS answer type A
            answer_dns_A = dns_resolve_A(domain)
            is_wildcard_domain = False

            # The domain has been resolved
            if answer_dns_A:

                # Get ips
                ips = [answer.address for answer in answer_dns_A]
                all_ips.update(ips);

                # Test if an ip is a multicard resolution
                for ip in ips:
                    if ip in wildcard_ips:
                        is_wildcard_domain = True
                        break;
                    elif ip in all_ips and ip not in checked_ips:
                        # Here it seems that the ip has been previously resolved
                        # so we are testing that it is not a subdomain wildcard resolution
                        
                        checked_ips.add(ip)
                        wildcard_ips.update(get_wildcard_ips([domain], True))

                        if ip in wildcard_ips:
                            is_wildcard_domain = True
                            break;

                # So we are going to the next domain because of wildcard domain
                if is_wildcard_domain:
                    continue

                ip = ips[0]

                print colored('Domain found %s (%s)' % (domain,','.join(ips)),'green')

                aquatone_json_data[domain] = ip
                aquatone_csv_data += '%s,%s\n' % (domain,ip)

                ##########################################
                # We are looking if we can find some alias
                ##########################################
                aliases = []
                alias=dns_resolve_CNAME(domain)

                # Recursive check
                while(alias):
                    aliases.append(alias)
                    alias=dns_resolve_CNAME(alias)

                if aliases:
                    print colored('Alias found for %s (%s)' % (domain,','.join(aliases)),'yellow')
                    print_unresolved_alias(aliases)

            # Counting processed lines
            nb_processed += 1
            if nb_processed % 1000 == 0:
                print '%s processed on %s' % (nb_processed,nb_domains)
        
        print '%s processed on %s' % (nb_domains,nb_domains)

###################################################
# generate subdomains file
###################################################
def generate_subdomains(file,domain):

    output_file=config_data['subdomains_output_file'];
    output_file_data='';

    # Opening the file with words to add to the domain
    with open(file) as words_input_file:
        subdomains = words_input_file.read().splitlines()
        for subdomain in subdomains:
            output_file_data += '%s.%s\n' % (subdomain,domain)

    # Saving sudomains list
    with open(get_knocktone_filepath(output_file), 'w') as result_file:
        result_file.write(output_file_data)

###################################################
# send a DNS type A request
###################################################
def dns_resolve_A(domain):

    try:
        return dns.resolver.query(domain, 'A')
        # We are returning the first ip address found
        # return str(answers_IPv4[0].address)
    except Exception as e:
        return None

###################################################
# send a DNS type CNAME request
###################################################
def dns_resolve_CNAME(domain):

    try:
        answers_IPv4 = dns.resolver.query(domain, 'CNAME')
        return str(answers_IPv4[0].target)
    except Exception as e:
        return None

###################################################
# print unresolved alias
###################################################
def print_unresolved_alias(aliases):  

    for alias in aliases:
        if(not dns_resolve_A(alias)):
            print colored('[finding] We found an unresolved alias (subdomain takeover): %s' % alias,'red')

###################################################
# check post aquatone-scan headers
###################################################
def check_aquatonescan_headers(directory):

    global config_data

    # Looping on each subdomains headers txt files
    for file in os.listdir(directory):
        if file.endswith('.txt'):
            print '\nScanning file %s' % file

            # we are getting the information about the target
            file_info = os.path.splitext(file)[0].split('__')
            domain = file_info[0].replace('_','.')
            ip = file_info[1].replace('_','.')
            port = int(file_info[2])

            # Displaying the HTTP code
            response = get_http_response(domain,port)

            # Get HTTP status code and check if response is not None
            if response is not None:
                redirect = False

                http_status_code = response.status_code

                color=None
                if(http_status_code == config_data['http_status_success']):
                    color='green'
                elif response.is_redirect or response.is_permanent_redirect:
                    redirect = True

                # Display url to follow if redirection has been detected
                if redirect:
                    print colored('HTTP status code: %d (%s redirects to %s)' % (http_status_code,response.url,response.headers['Location']),color)
                else:
                    print colored('HTTP status code: %d (%s)' % (http_status_code,response.url),color)

                # Looking if we can access the service directly via the server's ip
                if(check_ip_based_hosting(domain,ip,port)):
                    print colored('[finding] Server %s is directly accessible via ip %s' % (domain,ip),'green')

            # Opening txt file
            with open(directory + os.sep + file) as headers_file:
                headers_lines = headers_file.read().splitlines()

                # Reading each line of the headers txt file
                for line in headers_lines:

                    # Checking is some headers are present
                    for value in config_data['headers']['present']:
                        if value.lower() in line.lower():
                            print colored('[finding] %s:%d %s' % (domain,port,line),'green')

                """
                missing_headers = []
                # Checking if some headers are missing
                for value in config_data['headers']['missing']:
                    if not value.lower() in map(lambda x:x.lower(),headers_lines):
                        missing_headers.append(value)
                        
                if missing_headers:
                    print colored('Missing patterns (%s)' % ', '.join(missing_headers),'yellow')
                """


###################################################
# Check if ip-based hosting
###################################################
def check_ip_based_hosting(domain,ip,port):

    global config_data

    response_ip_based = get_http_response(ip,port)
    response_host_based = get_http_response(domain,port)

    # Check if one of the response if None
    if None in (response_ip_based,response_host_based): return False

    #Check thanks to the html title tag
    title_ip_based = BeautifulSoup(response_ip_based.text,'html.parser').title
    title_host_based = BeautifulSoup(response_host_based.text,'html.parser').title

    # Check that the titles exist and are the same and that status_code is 200 (do not take care of redirections)
    return False if None in (title_ip_based,title_host_based) else \
    (title_ip_based.string == title_host_based.string and response_ip_based.status_code == config_data['http_status_success'] and response_host_based.status_code == config_data['http_status_success'])

###################################################
# concat aquatone-discover hosts.json files
###################################################
def concat_aquatone_hosts_files(input_file_1,input_file_2,output_file):

    input_data_1 = {}
    input_data_2 = {}

    # Reading input files
    with open(input_file_1) as input_file_1, open(input_file_2) as input_file_2:
        input_data_1 = json.load(input_file_1)
        input_data_2 = json.load(input_file_2)

    # concat dictionaries
    input_data_1.update(input_data_2)

    # write resulting output file
    with open(output_file, 'w') as result_file:
        json.dump(collections.OrderedDict(sorted(input_data_1.items())), result_file)

###################################################
# create a function to gather ips resolved in case of wildcard DNS
###################################################
def get_wildcard_ips(domains, are_subdomains = False):

    wildcard_ips = set()
    wildcard_domains = set()

    # Looking if we have to take only the domain
    if not are_subdomains:
        for domain in domains:
            wildcard_domains.add('%s.%s' % (domain.split('.')[-2],domain.split('.')[-1]))
    else:
        wildcard_domains = domains

    for domain in wildcard_domains:
        for i in range(10):
            answer_dns = dns_resolve_A('%s.%s' % (str(uuid.uuid4()),domain))

            # The domain has been resolved
            if answer_dns:

                # Get ips
                ips = [answer.address for answer in answer_dns]
                wildcard_ips.update(ips)

    return wildcard_ips



###################################################
# only for command line
###################################################
if __name__ == '__main__':
    # if os.geteuid() != 0:
    #     sys.exit('You need to have root privileges to run this script.')
    main(sys.argv)