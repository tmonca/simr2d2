# Attempting an R2D2 simulation of a single pod (2 layer topo 48x48 port, 
# 10Gbps, 40Gbps uplinks)

# Two types of traffic - long-running background flows, shorter latency 
# sensitive traffic

# Latency sensitive traffic receives strict priority over background and 
# should (ideally) be liable to incast in absence of R2D2. This is going
# to require some fiddly tuning of parameters...

set framesize 1462
set max_host_id 0

set pattern "NTOONE"
set print_topology 1
set debug_ 1

Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set packetSize_ [expr $framesize - 40]

Agent/TCP set window_ 2000
Agent/TCP set slow_start_restart_ false
Agent/TCP set tcpTick_ 0.00001
Agent/TCP set minrto_ 0.002 ; # minRTO = 2ms
Agent/TCP set windowOption_ 0
Agent/TCP set nodelay_ 1

Queue/MPriQueue set summarystats_ 0
#625 KB is about 500 usec for 10Gbps
Queue/MPriQueue set queue_in_bytes_ 625000 
Queue/MPriQueue set mean_pktsize_ 1500
Queue/MPriQueue set printMax 0
Queue/MPriQueue set drop_front_ 0
Queue/MPriQueue set print_drop_ 0


remove-all-packet-headers
add-packet-header Flags TCP IP


Class Network

# This creates the physical network and connects the nodes

Network instproc init {} {
    $self instvar vm_per_host_ host_per_ToR_ ToR_per_agr_
    $self instvar total_agr_ total_ToR_ total_host_
    $self instvar ToR_BW_ agr_BW_
    $self instvar agr_latency_ ToR_latency_ 
    $self instvar agr_qlen_ ToR_qlen_ host_qlen_
    $self instvar host_ ToR_ agr_ 
    $self instvar created_
    $self instvar ns_

    #set default values
    set ToR_BW_ 10Gbps
    set ToR_latency_ 0.001ms

    set agr_BW_ 40Gbps
    set agr_latency_ 0.001ms

    set host_per_ToR_ 48
    set ToR_per_agr_  48
    set total_agr_ 1

    set total_ToR_  [expr $ToR_per_agr_  * $total_agr_]
    set total_host_ [expr $host_per_ToR_ * $total_ToR_]

    set agr_qlen_ 1000
    set ToR_qlen_ 1000
    set host_qlen_ 1000
    
    set created_ false
}


Network instproc set_cluster_size {total_host} {
    $self instvar host_per_ToR_ ToR_per_agr_ agr_per_core_
    $self instvar total_agr_ total_host_ total_ToR_
    set total_ToR  [expr [expr [expr $total_host_ + $host_per_ToR_] - 1] / $host_per_ToR_]
    set total_agr  [expr [expr [expr $total_ToR_  + $ToR_per_agr_ ] - 1] / $ToR_per_agr_ ]

    set total_agr_  $total_agr
    set total_ToR_  $total_ToR
    set total_host_ $total_host

    puts "#Host: $total_host_ #Tor: $total_ToR_ #Agr: $total_agr_ "

    if {$total_agr_ > 1} {
	    puts "can't have more than 1 Aggregate switch"
	    exit -1
    }
}

Network instproc ns_init {ns} {
    global print_topology

    $self instvar agr_ ToR_ host_
    $self instvar ns_
    $self instvar created_
    $self instvar total_agr_ total_host_ total_ToR_
    $self instvar ToR_per_agr_ host_per_ToR_
    $self instvar ToR_BW_ agr_BW_ 
    $self instvar ToR_latency_ agr_latency_ 
    $self instvar agr_qlen_ ToR_qlen_
    
    set created_ true
    set ns_ $ns

    #create agr switches
    
	set agr_(0) [$ns_ node]
	$agr_(0) color Blue
    

    # create ToR switches and connect them to aggr switches
    # can use MPriQueue to give a priority queue...
    for {set i 0} {$i < $total_ToR_} {incr i} {
	    set ToR_($i) [$ns_ node]
	    $ToR_($i) color Green
	    $ns_ duplex-link $ToR_($i) $agr_(0) $agr_BW_ $agr_latency_ DropTail
	    $ns_ duplex-link-op $ToR_($i) $agr_(0) queuePos 0.5
	    $ns_ queue-limit $ToR_($i) $agr_(0) $ToR_qlen_
	    $ns_ queue-limit $agr_(0) $ToR_($i) $agr_qlen_
    }
}


Network instproc connect_host {host} {
    global print_topology
    $self instvar host_ total_host_ ToR_ ns_ host_per_ToR_
    $self instvar ToR_BW_ ToR_latency_ host_qlen_ ToR_qlen_
    set host_index [$host set host_id_]
    set ToR_index [expr $host_index / $host_per_ToR_]
    set host_($host_index) [$host get_ns_host]
    if {$print_topology > 0} {    
	    puts "host $host_index <-> ToR $ToR_index"
    }
    
    $ns_ duplex-link $host_($host_index) $ToR_($ToR_index) $ToR_BW_ $ToR_latency_ DropTail
    $ns_ duplex-link-op $host_($host_index) $ToR_($ToR_index) queuePos 0.5
    $ns_ queue-limit $host_($host_index) $ToR_($ToR_index) $host_qlen_
    $ns_ queue-limit $ToR_($ToR_index) $host_($host_index) $ToR_qlen_
}



Class VM

# This creates VMs (which run on hosts) May not need this level of granularity
# Currently VMs "own" the traffic flows 

VM instproc init {} {
    $self instvar host_id_ 
    $self instvar tenant_
    $self instvar host_
    $self instvar org_flows_
    $self instvar dst_flows_
    $self instvar num_org_flows_
    $self instvar num_dst_flows_
   

    set num_org_flows_ 0
    set num_dst_flows_ 0
}

VM instproc ns_init {ns} {
  
    $self instvar org_flows_ num_org_flows_  

    for {set i 0} {$i < $num_org_flows_} {incr i} {
	    $org_flows_($i) ns_init $ns 
    }
}

VM instproc add_org_flow {flow} {
    $self instvar org_flows_ num_org_flows_
    set org_flows_($num_org_flows_) $flow
    $flow set src_vm_ $self
    incr num_org_flows_
}

VM instproc add_dst_flow {flow} {
    $self instvar dst_flows_ num_dst_flows_
    set dst_flows_($num_dst_flows_) $flow
    $flow set dst_vm_ $self
    incr num_dst_flows_
}

VM instproc get_host {} {
    $self instvar host_
    return $host_
}

VM instproc is_active {} {
    return [$tenant_ active_]
}


Class Host

# set up hosts

Host instproc init {host_id} {
    $self instvar ns_host_
    $self instvar host_id_
    $self instvar num_vm_

    set host_id_ $host_id
    set num_vm_ 0
}

Host instproc ns_init {ns} {
    $self instvar  ns_host_
    set ns_host_ [$ns node]

}

Host instproc add_vm {vm} {
    $self instvar vms_ num_vm_ host_id_
    set vms_($num_vm_) $vm
    $vm set host_ $self
    $vm set host_id_ $host_id_
    incr num_vm_
}

Host instproc get_ns_host {} {
    $self instvar ns_host_
    return $ns_host_
}



Class Flow

# Flows are the actual traffic in the system. Need to work out  
# how to have background and foreground flows.

Flow instproc init {} {
    global framesize
    $self instvar flow_id_
    $self instvar src_vm_
    $self instvar dst_vm_
    $self instvar type_ 
    $self instvar l5_
    $self instvar l4_
    $self instvar l4_d_

    #set type_ "CBR"
	set type_ "TCP"
	
}

Flow instproc ns_init {ns} {
    global framesize debug_
    $self instvar l4_ l5_ src_vm_ dst_vm_ type_ flow_id_

    set src_host [$src_vm_ get_host]
    set dst_host [$dst_vm_ get_host]
    set done 0
    
    #create flow in ns
    if {$type_ == "TCP"} {
	    set l4_ [new Agent/TCP]
	    $l4_ set packetSize_ $framesize
	    $l4_ set flow_id $flow_id_
	    
	    set l5_ [new Application/FTP]

	    set l4_d_ [new Agent/TCPSink]
        
	    $ns attach-agent [$src_host set  ns_host_] $l4_
	    $ns attach-agent [$dst_host set  ns_host_] $l4_d_	
	    $l5_ attach-agent $l4_
	    $ns connect $l4_ $l4_d_
	    set done 1
    }
    
    if {$done == 0} {
	    puts "Unknown flow type: $type_"
	    exit -1
    }

    if {$debug_ > 1} {
        puts "$type_ flow from [$src_host set host_id_] to [$dst_host set host_id_]"
    }
}

Flow instproc start {ns t} {
    global jitter
    $self instvar l5_ offset_
    set offset_ [expr [expr [expr [expr [ns-random] % 1000000] + 0.0] / 1000000] * $jitter / 1000000]
    puts "start flow $self at([expr $t + $offset_])"
    $ns at [expr $t + $offset_] "$l5_ start"
}

Flow instproc stop {ns t} {
    $self instvar l5_ offset_
    $ns at [expr $t + $offset_] "$l5_ stop"
}



Class Tenant 

# "Tenants" have a set of VMs distributed across the DC. For R2D2 might just want 
# to use a single tenant (but may also be a mechanism to split latency-sensitive
# traffic from background) 

Tenant instproc init {} {
    global pattern 

    $self instvar vms_
    $self instvar num_vm_
    $self instvar type_
    $self instvar flows_
    $self instvar num_flow_

    set num_vm_ 0
    set type_ $pattern
}

Tenant instproc new_vm {} {
    $self instvar vms_
    $self instvar num_vm_
    set vm [new VM]
    set vms_($num_vm_) $vm 
    incr num_vm_

    return $vm
}

Tenant instproc get_vm {index} {
    $self instvar num_vm_ vms_
    if {$index >= $num_vm_} {
	    puts "Invalid VM index"
	    exit -1
    }
    return $vms_($index)
    
}

Tenant instproc create_flow {priority} {

    $self instvar num_vm_ 
    $self instvar vms_
    $self instvar type_ num_flow_ flows_

    set num_flow_ 0

    if {"NSQUARE" == $type_} {
	    if {$num_vm_ <= 1} {
	     return
	    }
	
	    for {set i 0} {$i < $num_vm_} {incr i} {
	        for {set j 0} {$j < $num_vm_} {incr j} {
		        if {$i == $j} {
		            continue
		        }
		        set flow [new Flow]
		        $flow set tenant_ $self
		        #$flow set priority $priority
		        $flow set flow_id_ $priority
		        $vms_($i) add_org_flow $flow
		        $vms_($j) add_dst_flow $flow
		        set flows_($num_flow_) $flow
		        incr num_flow_
	        }
	    }
    }
    
    if {"NTOONE" == $type_} {
	    if {$num_vm_ <= 1} {
	        return
	    }


	    for {set i 1} {$i < $num_vm_} {incr i} {
	        set flow [new Flow]
	        $flow set tenant_ $self
	        #$flow set priority $priority
		    $flow set flow_id_ $priority
	        $vms_($i) add_org_flow $flow
	        $vms_(0) add_dst_flow $flow
	        set flows_($num_flow_) $flow
	        incr num_flow_
	    }
    }
    
    if {$num_flow_ == 0} {
	    if {$num_vm_ > 1} {
	        puts "Now flow created for tenant $self"
	        exit -1
	    }
    }
}

Tenant instproc ns_init {ns} {
    $self instvar vms_ num_vm_ 
    for {set i 0} {$i < $num_vm_} {incr i} {
	    set vm $vms_($i)
	    $vm ns_init $ns 
    }
}

Tenant instproc start {ns t} {
    $self instvar active_ num_flow_ flows_
    for {set i 0} {$i < $num_flow_} {incr i} {
        puts "tenant flow $i (<$num_flow_)"
	    $flows_($i) start $ns $t
    }
}

Tenant instproc stop {ns t} {
    $self instvar active_ num_flow_ flows_
    for {set i 0} {$i < $num_flow_} {incr i} {
	    $flows_($i) stop $ns $t
    }
}



Class Cluster

Cluster instproc init {} {
    $self instvar tenants_
    $self instvar network_ 
    $self instvar hosts_
    $self instvar ns_
    $self instvar num_tenant_ num_host_

    set num_tenant_ 0
}

Cluster instproc new_tenant {tenant_type} {
    return [new Tenant]
}

Cluster instproc read_job {filename} {
    global max_host_id 
    $self instvar num_tenant_
    $self instvar tenants_ 
    puts "Reading config file: $filename"
    
    set chan [open $filename]
    
    while {[gets $chan line] >= 0} {
	    if {[string length $line] <= 1} {
	        continue
	    }
	
 # split the topo file using |
	    set words [split $line |]
	
    # calculate how many VMs this tenant has	
	    set num_vm [expr [llength $words] - 1]
	    puts "There are $num_vm VMs in this file"
	    set priority [lindex $words 0]
	    scan [lindex $words 0] "%d" priority
        puts "The priority is $priority"
	    set tenant [$self new_tenant 0]
	    set tenants_($num_tenant_) $tenant 


#  VM 1(9(1))
	    for {set i 1 } {$i <= $num_vm} {incr i} {
	        set vmplacement [lindex $words $i]
            if {[scan $vmplacement " VM %d(%d(%d))" vmid hostid rackid] != 3} {
                puts "$vmplacement"
                continue
            }
            puts "$vmplacement"
	        set vm [$tenant new_vm]
	        $vm set host_id_ $hostid
	        $vm set tenant_ $tenant

	        if {$hostid > $max_host_id} {
		        set max_host_id $hostid
	        }
	    }
	    incr num_tenant_

	    $tenant create_flow $priority
    }
}

Cluster instproc  ns_init {} {
    puts "Building NS2 simulation"
    global max_host_id outfile 
    $self instvar network_ ns_ num_tenant_ tenants_ nf_ cluster_size_ hosts_
    
    set ns_ [new Simulator]
    set nf_ [open $outfile w]
    $ns_ trace-all $nf_

    set network_ [new Network]
    set cluster_size_ [expr $max_host_id + 1]

    $network_ set_cluster_size $cluster_size_
    $network_ ns_init $ns_

    #create hosts
    for {set i 0} {$i < $cluster_size_} {incr i} {
	    set hosts_($i) [new Host $i]
	    $hosts_($i) ns_init $ns_
	    $network_ connect_host $hosts_($i)
    }


    #connect vms
    for {set i 0} {$i < $num_tenant_} {incr i} {
	    set tenant $tenants_($i)
	    for {set j 0} {$j < [$tenant set num_vm_]} {incr j} {
	        set vm [$tenant get_vm $j]
	        set host_index [$vm set host_id_]
	        $hosts_($host_index) add_vm $vm
	    }
	    $tenant ns_init $ns_ 
    }
}

Cluster instproc terminate {} {
    $self instvar ns_ nf_
    $ns_ flush-trace
    close $nf_
    exit -1
}


Cluster instproc run {begin end finish} {
    puts "Starting NS2 simulation"
    $self instvar num_tenant_
    $self instvar tenants_
    $self instvar ns_ nf_
    
    for {set i 0} {$i < $num_tenant_} {incr i} {
        puts "starting $i $num_tenant_"
	    $tenants_($i) start $ns_ $begin
	    $tenants_($i) stop $ns_ $end
    }
    
    $ns_ at $finish "$self terminate"
    $ns_ run
}








