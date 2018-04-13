#!/usr/bin/env python3
# -*- coding: utf8 -*-

import sys, argparse
from urllib.parse import urlparse
from urllib.parse import parse_qs

class Url():
    
    # Static list of Url
    LIST = []    
    
    def __init__(self,surl):
        purl = urlparse(surl)
        self.url = surl
        self.scheme = purl.scheme
        self.netloc = purl.netloc
        self.path = '' if purl.path == '/' else purl.path
        self.params = list(parse_qs(purl.query,keep_blank_values=True).keys())

    """
    Compare if it matches with some Url objects
    """
    @staticmethod
    def exists(url):
        
        for ourl in Url.LIST:
            thesame1 = url.scheme == ourl.scheme and url.netloc == ourl.netloc and url.path == ourl.path
            thesame2 = True
            for param in url.params:
                if param not in ourl.params:
                    thesame2 = False
                    break

            if thesame1 and thesame2:
                return True

        return False


    
##################################################
# main procedure
###################################################
def main(argv):

    nb_processed = 0

    ###################
    # parse args
    ###################
    parser = argparse.ArgumentParser(description='Look for duplicate urls')
    parser.add_argument("-f", "--file", dest="urlsfile",help="file with urls")
    args = parser.parse_args()

    if not args.urlsfile:
        parser.print_help()
        sys.exit(1)

    with open(args.urlsfile) as urls_file:

        urls = urls_file.read().splitlines()
        
        print('[*] Processing %d urls' % len(urls))
    
        ###################
        # Pushing urls onto queue
        ###################
        for url in urls:  
            ourl = Url(url)
            if not Url.exists(ourl):
                Url.LIST.append(ourl)

            nb_processed += 1

            if nb_processed % 1000 == 0:
                print('[*] %s urls processed' % nb_processed)

        print('[*] Output file: uniqurls.output')
        print('[*] Done')

    # Writing results file
    with open('uniqurls.output','w') as result_file:

        for ourl in Url.LIST:
            print(ourl.url,file=result_file)
        

###################################################
# only for command line
###################################################
if __name__ == '__main__':
    # if os.geteuid() != 0:
    #     sys.exit('You need to have root privileges to run this script.')
    main(sys.argv)