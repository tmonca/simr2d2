
set ns [new Simulator]

set synchSize 1024000
set bufSize 64
set runTimeInSec 20.0
set num_serv 10

set fall [open ./out.tra w]
$ns trace-all $fall

# create output files for bandwidth per nodes (moving average)
set f0 [open ./tput_moving.tr w]
set f1 [open ./tput_instantaneous.tr w]

# record average bw statistics
set favg_ind [open ./tput_cum_ind_avg.tr w]
set favg_tot [open ./tput_cum_tot_avg.tr w]


for {set i 0} {$i < $num_serv} {incr i} {

    set avg($i) 0
    set bw_interval_($i) 0.0

}

set i 0

proc finish {} {

        #global ns fall fnam f0 f1 favg_ind favg_tot tracedir
        global ns fall f0 f1 favg_ind favg_tot 
        $ns flush-trace

        #Close the output files
        close $f0
        close $f1
        close $favg_ind
        close $favg_tot

        exit 0
    }

set client_node [$ns node]
set router [$ns node]


for {set i 0} {$i < $num_serv} {incr i} {
    set server_node_($i) [$ns node]
}
   
$ns duplex-link $client_node $router 1000Mb 1us DropTail
$ns queue-limit $client_node $router 1000
$ns queue-limit $router $client_node $bufSize

for {set i 0} {$i < $num_serv} {incr i} {
    $ns duplex-link $router $server_node_($i) 1000Mb 1us DropTail
    # $ns queue-limit $router $server_node_1 4
    # $ns queue-limit $server_node_1 $router 8

}

# dummy
set tcpcdummy [new Agent/TCP/FullTcp]
$ns attach-agent $client_node $tcpcdummy

for {set i 0} {$i < $num_serv} {incr i} {

    # client_nodes
    set tcpc($i) [new Agent/TCP/Newreno]
    $tcpc($i) set max_ssthresh_ 0
    $tcpc($i) set fid_ $i
    $ns attach-agent $client_node $tcpc($i)

    set tcpc_sink($i) [new Agent/TCPSink]
    $tcpc_sink($i) set fid_ [expr 100 + $i]
    $ns attach-agent $client_node $tcpc_sink($i)

}

for {set i 0} {$i < $num_serv} {incr i} {

    # server_node_1
    set tcp($i) [new Agent/TCP/Newreno]
    $tcp($i) attach [open ./$tracedir/tcp1.tr w]
    $tcp($i) set bugFix_ false
    $tcp($i) trace cwnd_
    $tcp($i) trace ack_
    $tcp($i) trace ssthresh_
    $tcp($i) trace nrexmit_
    $tcp($i) trace nrexmitpack_
    $tcp($i) trace nrexmitbytes_
    $tcp($i) trace ncwndcuts_
    $tcp($i) trace ncwndcuts1_
    $tcp($i) trace dupacks_
    # $tcp($i) trace curseq_
    # $tcp($i) trace maxseq_
    $tcp($i) set fid_ [expr 1000 + $i]
    $ns attach-agent $server_node_($i) $tcp($i)

    set tcp_server_sink($i) [new Agent/TCPSink]
    $tcp_server_sink($i) set fid_ [expr 1100 + $i]
    $ns attach-agent $server_node_($i) $tcp_server_sink($i)

}

for {set i 0} {$i < $num_serv} {incr i} {
    
    # connect the sending agents to sinks
    $ns connect $tcpc($i) $tcp_server_sink($i)
    $ns connect $tcp($i) $tcpc_sink($i)

    $tcpc_sink($i) listen
    $tcp_server_sink($i) listen
}
    

set clientApp [new Application/IncastTcpAppClient $tcpcdummy $synchSize]

for {set i 0} {$i < $num_serv} {incr i} {
    set srvApp1 [new Application/IncastTcpAppServer $tcp1 $synchSize]

    $clientApp connect $sapp1 $tcpc1 $tcpc1_sink

    $tcp1_server_sink setparent $sapp1
}

$ns at 0.1 "$clientApp start"
$ns at 0.1 "record"
$ns at $runTimeInSec "finish"

# Define a procedure which periodically records the bandwidth received by the
# traffic sink $sink and writes it to the file $dfile.
proc record { } {
    global ns favg_ind favg_tot i
    
    for {set j = 0} {$j < $num_serv} {incr j} {
        
        global tcpc_sink($j) bw_interval($j) avg($j)
        
    }
    
    # Set the time after which the procedure should be called again
    set time 0.001

    set i [expr $i + $time]

    #Get the current time
    set now [$ns now]

    # Record how many bytes have been received by the traffic sinks.
    set bw1 [$tcpc1_sink set bytes_]
    set bw_interval_1 [expr $bw_interval_1 + $bw1]
    set bw2 [$tcpc2_sink set bytes_]
    set bw_interval_2 [expr $bw_interval_2 + $bw2]
    set bw3 [$tcpc3_sink set bytes_]
    set bw_interval_3 [expr $bw_interval_3 + $bw3]
    set bw4 [$tcpc4_sink set bytes_]
    set bw_interval_4 [expr $bw_interval_4 + $bw4]

    if {$i >= 1.0} {
        puts $f0 "$now [expr $bw_interval_1/$i*8/1000000] [expr $bw_interval_2/$i*8/1000000] [expr $bw_interval_3/$i*8/1000000] [expr $bw_interval_4/$i*8/1000000] [expr ( $bw_interval_1 + $bw_interval_2 + $bw_interval_3 + $bw_interval_4)/$i * 8/1000000]"
        set bw_interval_1 0
        set bw_interval_2 0
        set bw_interval_3 0
        set bw_interval_4 0
        set i 0.0
    }

    # Calculate the bandwidth (in MBit/s) and write it to the files
    # puts $f0 "$now [expr $bw0/$time*8/1000000] [expr $bw1/$time*8/1000000] [expr ($bw0+$bw1)/$time*8/1000000]"
    puts $f1 "$now [expr $bw1/$time*8/1000000] [expr $bw2/$time*8/1000000] [expr $bw3/$time*8/1000000] [expr $bw4/$time*8/1000000] [expr { wide($bw1+$bw2+$bw3+$bw4)/$time*8/1000000 }]"
    set avg1 [expr { wide($avg1) + $bw1 }]
    set avg2 [expr { wide($avg2) + $bw2 }]
    set avg3 [expr { wide($avg3) + $bw3 }]
    set avg4 [expr { wide($avg4) + $bw4 }]

    puts $favg_ind "$now [expr $avg1/($now-.09999999)*8/1000000] [expr $avg2/($now-.09999999)*8/1000000] [expr $avg3/($now-.09999999)*8/1000000] [expr $avg4/($now-.09999999)*8/1000000]"
    puts $favg_tot "$now [expr { wide($avg1+$avg2+$avg3+$avg4)/($now-.09999999)*8/1000000 }]"

    # Reset the bytes_ values on the traffic sinks
    $tcpc1_sink set bytes_ 0
    $tcpc2_sink set bytes_ 0
    $tcpc3_sink set bytes_ 0
    $tcpc4_sink set bytes_ 0

    # Re-schedule the procedure
    $ns at [expr $now+$time] "record"
}
$ns run
