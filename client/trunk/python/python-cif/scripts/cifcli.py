#!/usr/bin/python

import cif
import argparse
import os

if __name__ == '__main__':
    # Parse Command Line Arguments
    parser = argparse.ArgumentParser(description="Command line interface to CIF APIs")

    parser.add_argument("-q",'--query')
    parser.add_argument('-s','--severity')
    parser.add_argument('-r','--restriction')
    parser.add_argument("-f", '--fields',nargs='*',metavar="FIELD")
    args = parser.parse_args()

    if not args.query:
        parser.print_help()
        print "\n"
        print "example: python cif.py -q infrastrastructure/bonet -f restriction address asn cidr\n"
        os._exit(-1)        

    rclient = cif.ClientINI(fields=args.fields)

    r = rclient.GET(args.query,args.severity,args.restriction)
    print rclient.table(r)