#!/usr/bin/python

import sys,select

def main(argv):
    
    ############
    # Check for passed Arguments
    if select.select([sys.stdin,],[],[],0.0)[0]:
    	# only read from stdin if stdin is available
    	STDIN_arg = sys.stdin.read()
    	print("STDIN arg: %s" % str(STDIN_arg))
    else:
    	print "No STDIN argument passed..."
        sys.exit(1)
    	
    try:
        arg_1 = str(sys.argv[1])
        print("Argument 1: %s" % str(arg_1))
    except:
        print "No Argument 1 passed..."
        sys.exit(1)

#### main ####
if __name__ == "__main__":
	try:
		main(sys.argv[1:])
	except IndexError:
		print "Missing arguments..."
		sys.exit(1)