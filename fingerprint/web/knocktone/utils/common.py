#!/usr/bin/env python2
# -*- coding: utf8 -*-

import json, os, requests
from termcolor import colored
from utils.config import config_data

# global actions
requests.packages.urllib3.disable_warnings()

###################################################
# create CSV file
###################################################
def create_csv(file,data):       
    # Opening hosts.csv
    with open(file, 'w') as output_csv:
        output_csv.write(data)

###################################################
# create JSON file
###################################################
def create_json(file,data):       
    # Opening hosts.json
    with open(file, 'w') as output_json:
        json.dump(data, output_json)

###################################################
# Check existing file
###################################################
def file_exists(file):
    if not os.path.isfile(file):
        raise Exception('File %s does not exist' % file)

###################################################
# Check existing directory
###################################################
def dir_exists(file):
    if not os.path.isdir(file):
        raise Exception('Directory %s does not exist' % file)

###################################################
# Return valid http response (try http/https)
# Do not follow redirection
###################################################
def get_http_response(domain,port):
    response = None
    try:
        response = requests.get('http://%s:%s' % (domain,port), allow_redirects=False, timeout=config_data['timeout'], headers={'User-Agent': config_data['useragent']})
        
        if (response is None or (response is not None and response.status_code == config_data['http_status_bad_request'])):
            response = requests.get('https://%s:%s' % (domain,port), allow_redirects=False, verify=False, timeout=config_data['timeout'], headers={'User-Agent': config_data['useragent']})
    except Exception as e:
        print colored(e.message,'red')

    return response
