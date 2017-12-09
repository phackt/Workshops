#!/usr/bin/env python2
# -*- coding: utf8 -*-
import json, sys, argparse, collections, requests, threading, Queue
from termcolor import colored
from urlparse import urlparse

# Global actions
requests.packages.urllib3.disable_warnings()

# Global vars
config_data = {}
nb_processed = 0

# Global lock for counter
threadLock = threading.Lock()

##################################################
# Thread class
##################################################
class WorkerThread(threading.Thread) :

    def __init__(self, queueUrls, queueResults, config_data, tid) :
        threading.Thread.__init__(self)
        self.queueUrls = queueUrls
        self.queueResults = queueResults
        self.config_data = config_data
        self.tid = tid

    ##################################################
    # Request the url
    ##################################################
    def get_http_response(self, url):

        response = None

        o = urlparse(url)

        # We are testing if the protocol is present
        if o.scheme in ('http','https'):
            try:
                response = requests.get(url, allow_redirects=True, verify=False, timeout=self.config_data['timeout'], headers={'User-Agent': self.config_data['useragent'], 'Origin': self.config_data['origin']})    
            except Exception as e:
                pass
        else:
            # trying http and https
            try:
                response = requests.get('http://%s' % url, allow_redirects=True, timeout=self.config_data['timeout'], headers={'User-Agent': self.config_data['useragent'], 'Origin': self.config_data['origin']})
                
                if (response is None or (response is not None and response.status_code == self.config_data['http_status_bad_request'])):
                    response = requests.get('https://%s' % url, allow_redirects=True, verify=False, timeout=self.config_data['timeout'], headers={'User-Agent': self.config_data['useragent'], 'Origin': self.config_data['origin']})
            except Exception as e:
                pass

        return response

    ##################################################
    # Run baby run!
    ##################################################
    def run(self) :

        global nb_processed
        
        # Always run until its queue is empty
        while True:

            url = None 
            results = {}

            try :

                # Get element in queue
                url = self.queueUrls.get(timeout=1)
                
                with threadLock:
                    nb_processed += 1

                response = self.get_http_response(url)

                # response should be http code 200
                if response is None or response.status_code != self.config_data['http_status_success']:
                    continue

                # results vars
                interestings_results = []
                opencors = False
                hacal = False
                hacac = False

                # Reading each line of the headers txt file
                for header_key_raw in response.headers.keys():
                    header_value_raw = response.headers[header_key_raw]

                    # lower values
                    header_value = header_value_raw.lower()
                    header_key = header_key_raw.lower()

                    # In case of encoding issues
                    try:
                        # Checking is some headers are present
                        for interesting_header in self.config_data['headers']['present']:

                            interesting_header = interesting_header.lower()

                            # looking for some interesting headers
                            if interesting_header in header_key or interesting_header in header_value:
                                interestings_results.append(header_key_raw+": "+header_value_raw)

                            # looking for CORS
                            if header_key == "access-control-allow-origin" and (header_value == "null" or header_value == self.config_data['origin'].lower()):
                                hacal = True
                            if header_key == "access-control-allow-credentials" and header_value == "true":
                                hacac = True

                            # Do we have bounty?
                            if hacal and hacac:
                                opencors = True

                    except Exception as e:
                        pass
                        # print "%s: %s" % (url,e)
                    
                # Looking for relevant results
                if(len(interestings_results) > 0 or opencors == True):
                    
                    url = response.request.url

                    # Jackpot
                    if(opencors == True):
                        print colored('open cors found for url %s' % url,'green')

                    # Pushing results on queue
                    results[url] = {} 
                    results[url]['interesting']=interestings_results
                    results[url]['opencors']=opencors

                    self.queueResults.put(results)

                # print nb lines processed
                if nb_processed%self.config_data['nblines'] == 0:
                    print '%s urls processed' % nb_processed

            except Queue.Empty:
                pass

            # Todo: check why task_done called too many times
            try:
                self.queueUrls.task_done()
            except Exception as e:
                pass
       
              
##################################################
# main procedure
###################################################
def main(argv):

    global config_data
    global nb_processed

    # read config
    with open('config.json') as config_file:
        config_data = json.load(config_file)

    # parse args
    parser = argparse.ArgumentParser(description='cors POC')
    parser.add_argument("-f", "--file", dest="urlsfile",help="file with urls")
    args = parser.parse_args()

    # Opening the file with urls
    # file can contain url with the following formats:
    # - http://domain.com
    # - https://domain.com
    # - domain.com (will test both http and https and keep first response)
    with open(args.urlsfile) as urls_file:

        urls = urls_file.read().splitlines()

        queueUrls = Queue.Queue()
        queueResults = Queue.Queue()

        print "Processing %d lines" % len(urls)
        print "Launching %d threads" % config_data['threads']

        # Creating threads
        for i in range(1, config_data['threads']+1):
            worker = WorkerThread(queueUrls, queueResults, config_data, i) 
            worker.setDaemon(True)
            worker.start()
    
        # Pushing urls onto queue
        for url in urls:
            queueUrls.put(url)     

        queueUrls.join()

        # All threads have consumed their queue
        print 'Total of %s urls processed' % nb_processed

        print 'Writing results_cors.json'

        # Saving results
        with open('results_cors.json', 'w') as output_json:
            while queueResults.qsize():
                json.dump(queueResults.get(), output_json)

        print 'Done'

###################################################
# only for command line
###################################################
if __name__ == '__main__':
    # if os.geteuid() != 0:
    #     sys.exit('You need to have root privileges to run this script.')
    main(sys.argv)