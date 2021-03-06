#!/usr/bin/env python2
# -*- coding: utf8 -*-

import os, json

###################################################
# Variables
###################################################
script_path=os.path.dirname(os.path.realpath(__file__)) + os.sep + '..' + os.sep 
config_data = {}

###################################################
# Get knocktone path file
###################################################
def get_knocktone_filepath(file):
    global script_path
    return script_path + file

###################################################
# Reading configuration file
###################################################
with open(get_knocktone_filepath('config.json')) as config_file:
    config_data = json.load(config_file)

