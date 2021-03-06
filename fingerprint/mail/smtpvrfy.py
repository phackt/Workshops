#!/usr/bin/env python3
# -*- coding: utf8 -*-
# smtp VRFY/EXPN checker

import socket
import sys
import argparse
import re

###################################################
# main procedure
###################################################
def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("-t", "--target", help="SMTP host", required=True, metavar='')
    parser.add_argument("-p", "--port", help="SMTP port", type=int, default=25, metavar='')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("-e", "--email", help="email to VRFY/EXPN", metavar='')
    group.add_argument("-f", "--file", help="emails list to VRFY/EXPN", metavar='')
    args = parser.parse_args()

    if(args.email is not None and args.file is not None):
        print("Choose one option (-e|-f) but not both")
        sys.exit(0)

    # Create a socket
    s=socket.socket(socket.AF_INET,socket.SOCK_STREAM)
    connect=s.connect((args.target,args.port))
    banner=s.recv(1024)

    # Send VRFY command
    if args.email is not None:
        print("VRFY " + args.email + " " + ("OK" if vrfy(args.email,s) else "KO") + " on " + args.target)
        print("EXPN " + args.email + " " + ("OK" if expn(args.email,s) else "KO") + " on " + args.target)
    if args.file is not None:
        with open(args.file,"r") as f:
            for line in f.readlines():
                line = line.rstrip("\n")
                print("VRFY " + line + " " + ("OK" if vrfy(line,s) else "KO") + " on " + args.target)
                print("EXPN " + line + " " + ("OK" if expn(line,s) else "KO") + " on " + args.target)

def vrfy(name,s):
    s.send(bytes("VRFY " + name + "\r\n","utf-8"))
    result=s.recv(1024)
    if(int(re.split(b"\s+",result)[0]) == 250):
        return True
    else:
        return False

def expn(name,s):
    s.send(bytes("EXPN " + name + "\r\n","utf-8"))
    result=s.recv(1024)
    if(int(re.split(b"\s+",result)[0]) == 250):
        return True
    else:
        return False

###################################################
# only for command line
###################################################
if __name__ == "__main__":
    main(sys.argv)
