
set ns [new Simulator]

set bufSize 64
set runTimeInSec 21.0

if {0 == [info exists env(PATTERN)]} {
     set pattern "LOCAL"
} else {
     set pattern $::env(PATTERN)
}

if {0 == [info exists env(NUM_RACK)]} {
    set num_rack 1
} else {
    set num_rack $::env(NUM_RACK)
}

if {0 == [info exists env(NUM_SRV)]} {
    set num_serv 48
} else {
    set num_serv $::env(NUM_SRV)
}

if {0 == [info exists env(MIN_RTO)]} {
    Agent/TCP set minrto_  0.002
} else {
    Agent/TCP set minrto_ $::env(MIN_RTO)
}

if {0 == [info exists env(NUM_ACTIVE)]} {
    set num_active 0.002
} else {
    set num_active $::env(NUM_ACTIVE)
}

#NB block_size is in 1,000s
if {0 == [info exists env(BLOCK_SIZE)]} {
    set block_size 100
} else {
    set block_size $::env(BLOCK_SIZE)
}

set fall [open ./out.tra w]
#$ns trace-all $fall

# create output files for bandwidth per nodes (moving average)
set fmove [open ./moving-$pattern-$num_active-$block_size-$num_rack-$num_serv.csv w]
set finstant [open ./instant-$pattern-$num_active-$block_size-$num_rack-$num_serv.csv w]

set fcombine [open ./combined.csv a]

puts -nonewline $fcombine "$pattern\t$num_active\t$block_size\t$num_rack\t$num_serv\t"

# record average bw statistics
#set favg_ind [open ./tput_cum_ind_avg.tr w]
#set favg_tot [open ./tput_cum_tot_avg.tr w]
for {set i 0} {$i < $num_active} {incr i} {
    set bw($i) 0
    set avg($i) 0
    set bw_interval($i) 0
    set bw_total($i) 0
}

set it 0.0

proc finish {} {

        #global ns fall fnam f0 f1 favg_ind favg_tot tracedir
        global ns fall fmove finstant fcombine num_active bw_total
        $ns flush-trace
        set temp3 0
        for {set i 0} {$i < $num_active} {incr i} {
            set temp3 [expr $temp3 + $bw_total($i)]
            puts "$temp3"
        }
        puts $fcombine "$temp3"
        #Close the output files
        close $fall
        close $fmove
        close $finstant
        close $fcombine

        exit 0
    }

# set client_node [$ns node] 
# INSTEAD I will use node (0,0) as the client

set aggregate [$ns node]

for {set j 0} {$j < $num_rack} {incr j} {
    set router($j) [$ns node]
    $ns duplex-link $aggregate $router($j) 10000Mb 1us DropTail
    $ns queue-limit $aggregate $router($j) 100
    $ns queue-limit $router($j) $aggregate 100
}
for {set j 0} {$j < $num_rack} {incr j} {
    for {set i 0} {$i < $num_serv} {incr i} {
        set node_($j,$i) [$ns node]
       # puts "Rack $j node $i"
        $ns duplex-link $router($j) $node_($j,$i) 10000Mb 0.5us DropTail
        $ns queue-limit $node_($j,$i) $router($j) $bufSize
        $ns queue-limit $router($j) $node_($j,$i) $bufSize
    }
}  

# dummy
set tcpcdummy [new Agent/TCP/FullTcp]
$ns attach-agent $node_(0,0) $tcpcdummy

for {set a 0} {$a < $num_active} {incr a} {

    # client_nodes
    set tcpc($a) [new Agent/TCP/Newreno]
    $tcpc($a) set max_ssthresh_ 0
    $tcpc($a) set fid_ $a
    $ns attach-agent $node_(0,0) $tcpc($a)

    set tcpc_sink($a) [new Agent/TCPSink]
    $tcpc_sink($a) set fid_ [expr 100 + $a]
    $ns attach-agent $node_(0,0) $tcpc_sink($a)

}

# $pattern can be LOCAL, REMOTE, RANDOM
set rng [new RNG]
$rng seed $num_active
set ru1 [new RandomVariable/Uniform]
$ru1 use-rng $rng
$ru1 set min_ 0
$ru1 set max_ $num_rack
        
set ru2 [new RandomVariable/Uniform]
$ru2 use-rng $rng
$ru2 set min_ 0
$ru2 set max_ $num_serv

    for {set n 0} {$n < $num_active} {incr n} {
        set tcp($n) [new Agent/TCP/Newreno]
        #$tcp($n) attach [open ./tcp1.tr w]
        #$tcp($n) set bugFix_ false
        #$tcp($n) trace cwnd_
        #$tcp($n) trace ack_
        #$tcp($n) trace ssthresh_
        #$tcp($n) trace nrexmit_
        #$tcp($n) trace nrexmitpack_
        #$tcp($n) trace nrexmitbytes_
        #$tcp($n) trace ncwndcuts_
        #$tcp($n) trace ncwndcuts1_
        #$tcp($n) trace dupacks_
        # $tcp($n) trace curseq_
        # $tcp($n) trace maxseq_
        $tcp($n) set fid_ [expr 1000 + $n]
        
        #Need to create random rack,machine combination

        
        if {$pattern == "LOCAL"} {
            set r 0
        } elseif {$pattern == "RANDOM"} {
            set r [expr int([expr floor([$ru1 value])])]
        } else {
            puts "Pattern was $pattern"
            set r 0
        }
        set m [expr int([expr floor([$ru2 value])])]
        if {($r == 0) && ($m ==0)} {
            puts "not allowed server on (0,0)"
            set m [expr int([expr floor([$ru2 value])])]
        }
        puts "Rack $r, machine $m"
        $ns attach-agent $node_($r,$m) $tcp($n)

        set tcp_server_sink($n) [new Agent/TCPSink]
        $tcp_server_sink($n) set fid_ [expr 1100 + $n]
        $ns attach-agent $node_($r,$m) $tcp_server_sink($n)

    }

    for {set i 0} {$i < $num_active} {incr i} {
        # connect the sending agents to sinks
        $ns connect $tcpc($i) $tcp_server_sink($i)
        $ns connect $tcp($i) $tcpc_sink($i)

        $tcpc_sink($i) listen
        $tcp_server_sink($i) listen
    }
        
    set clientApp [new Application/IncastTcpAppClient $tcpcdummy [expr $block_size * 100]]
    puts "NUM ACTIVE = $num_active"
    for {set i 0} {$i < $num_active} {incr i} {
        set srvApp($i) [new Application/IncastTcpAppServer $tcp($i) [expr $block_size * 100]]

        $clientApp connect $srvApp($i) $tcpc($i) $tcpc_sink($i)

        $tcp_server_sink($i) setparent $srvApp($i)
    }



$ns at 0.1 "$clientApp start"
$ns at 1.0 "record"
$ns at $runTimeInSec "finish"

# Define a procedure which periodically records the bandwidth received by the
# traffic sink $sink and writes it to the file $dfile.
proc record { } {
    global ns it fcombine fmove finstant tcpc_sink tcp_server_sink num_active bw_interval bw_total bw
    
    # Set the time after which the procedure should be called again
    set time 0.001

    set it [expr $it + $time]

    #Get the current time
    set now [$ns now]

    # Record how many bytes have been received by the traffic sinks.
    
    for {set i 0} {$i < $num_active} {incr i} {
        set bw($i) [$tcpc_sink($i) set bytes_]
        set bw_interval($i) [expr $bw_interval($i) + $bw($i)]
        set bw_total($i) [expr $bw_total($i) + $bw($i)]
        $tcpc_sink($i) set bytes_ 0
    }
    

    set temp 0
    if {$it >= 1.0} {
        puts -nonewline $fmove "$now\t"
        for {set i 0} {$i < $num_active} {incr i} {
            puts -nonewline $fmove "[expr $bw_interval($i)/$it*8/1000000] \t"
            set temp [expr $temp + $bw_interval($i) ]
        }
        puts $fmove "$temp"
        set bw_interval_($i) 0
        set it 0.0
        set temp 0
    }
    
    # Calculate the bandwidth (in MBit/s) and write it to the files
    set temp2 0
    puts -nonewline $finstant "$now\t"  
    for {set i 0} {$i < $num_active} {incr i} {
        puts -nonewline $finstant "[expr $bw($i)/$time*8/1000000]\t"
        set temp2 [expr $temp2 + $bw($i)]

    }
    puts $finstant "$temp2"
    
    # Re-schedule the procedure
    $ns at [expr $now+$time] "record"
}
$ns run





