#!/usr/bin/env python

# found it here: http://ubuntuforums.org/showthread.php?t=1200405

#python server (968)

import os, sys
import CGIHTTPServer
import BaseHTTPServer
from BaseHTTPServer import HTTPServer
from CGIHTTPServer import CGIHTTPRequestHandler
import optparse



class Handler(CGIHTTPServer.CGIHTTPRequestHandler):
    cgi_directories = ["/cgi-bin"]



def getOptions():
    parser = optparse.OptionParser()

    parser.add_option("--port",
                      dest="port",
                      metavar='[INT]',
                      default=8080,
                      help='Port to attach webserver')

    parser.add_option("--webdir",
                      dest="webdir",
                      metavar='[STRING]',
                      default='.',
                      help='Base webserver directory (for /htdocs and /cgi-bin)')

    parser.add_option("--offline",
                      dest='local_js',
                      action='store_true',
                      default=False,
                      help='Use local javascript instead of over external via http')

    parser.add_option("--serveraddr",
                      dest="serveraddr",
                      default="localhost",
                      help='webserver address')


    (options, args) = parser.parse_args()

    return options








def main ():

    options = getOptions()

    webdir = options.webdir #where html and cgi-bin files live
    port = int(options.port)    #use http://localhost:8080/
    serveraddr = options.serveraddr

    if options.local_js:
        print "LOCAL CanvasXpress Javascript IN USE"
        os.environ['LOCAL_JS'] = 'TRUE'
    else:
        print "Pulling CanvasXpress Javascript over http"
    
    print 'webdir: "%s", port %s' % (webdir, port)
    os.chdir(webdir)                              #run in HTML root dir

    srvraddr = (serveraddr, port)                         #my hostname, port number
    #srvrobj = HTTPServer(srvraddr, CGIHTTPRequestHandler)
    srvrobj = HTTPServer(srvraddr, Handler)
    srvrobj.serve_forever()




if __name__ == "__main__":
    main()
