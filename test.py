#!/usr/bin/python

import glob
import os
import subprocess
import sys

#   PATTERN     The pattern of connections (LOCAL, REMOTE, RANDOM)
#   NUM_RACK    The number of ToRs in the pod
#   NUM_SRV     The number of servers in each rack
#   MIN_RTO     The min RTO for TCP connections
#   NUM_ACTIVE  How many servers are actually actively sending
#   BLOCK_SIZE  The size of each data block (in kBytes)
#   

def run(pattern = 'LOCAL', num_rack = 1, num_srv = 48, num_active = 4, block_size = 100, min_rto = 0.002):
	env = 'PATTERN=%s NUM_RACK=%s NUM_SRV=%s NUM_ACTIVE=%s BLOCK_SIZE=%s MIN_RTO=%s' % (str(pattern), str(num_rack), str(num_srv), str(num_active), str(block_size), str(min_rto))
	cmd = ' ns new.tcl'
	os.system(str(env + cmd))

#NB for synchronised random seed makes NO difference!

run('LOCAL', 1, 48, 4, 100, 0.2)
run('LOCAL', 1, 48, 5, 100, 0.2)
run('LOCAL', 1, 48, 6, 100, 0.2)
run('LOCAL', 1, 48, 7, 100, 0.2)
#run('LOCAL', 1, 48, 8, 100, 0.2)
#run('LOCAL', 1, 48, 9, 100, 0.2)
#run('LOCAL', 1, 48, 10, 100, 0.2)
#run('LOCAL', 1, 48, 11, 100, 0.2)
#run('LOCAL', 1, 48, 12, 100, 0.2)

#run('LOCAL', 1, 48, 4, 100, 0.002)
#run('LOCAL', 1, 48, 5, 100, 0.002)
#run('LOCAL', 1, 48, 6, 100, 0.002)
#run('LOCAL', 1, 48, 7, 100, 0.002)
#run('LOCAL', 1, 48, 8, 100, 0.002)
#run('LOCAL', 1, 48, 9, 100, 0.002)
#run('LOCAL', 1, 48, 10, 100, 0.002)
#run('LOCAL', 1, 48, 11, 100, 0.002)
#run('LOCAL', 1, 48, 12, 100, 0.002)
