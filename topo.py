
#!/usr/bin/python

import glob
import os
import subprocess
import sys
import math

# I need to set 1 VM per host, hosts are then numbered sequentially across
# the whole data centre. Ideally I pass N,m (N servers spread across m racks)

def topo(NumSrv=4, NumToR=1):
    file = open('layout.txt', 'w')
# we'll start with all getting priority 1
    print >> file, "1 ",
    SrvPerToR = int(math.ceil(NumSrv / NumToR))
    counter = 0
    while counter <= NumToR:
        for t in range (0, SrvPerToR):
            #v is the actual server/VM id, t is the rack it's in
            r = counter * 48 + t
            v = counter * SrvPerToR + t
            print >> file, "| VM %d(%d(%d))" % (v, r, counter),
        counter += 1      
    print >> file, ""

topo(35,3)
