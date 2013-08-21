source network.tcl

set framesize 1538

#if {0 == [info exists env(JOBFILE)]} {
#    puts "Environmental variable JOBFILE needs to be set."
#    exit 0
#}

set filename layout.txt

#set outputsuffix [format "out" $perf_isolation]
#set index [string last "txt" $filename]
#set outfile [string replace  $filename $index [expr $index + 3] $outputsuffix]
set outfile layout.out

#if {0 == [info exists env(USESTDOUT)] ||
#    1 != $::env(USESTDOUT)} {
#	puts "Redirecting stdout to $outfile"
#	close stdout
#	open $outfile w
#}

if {0 == [info exists env(COMM_PATTERN)]} {
     set pattern "NTOONE"
} else {
     set pattern $::env(COMM_PATTERN)
}

if {0 == [info exists env(JITTER)]} {
    set jitter 0
} else {
    set jitter $::env(JITTER)
}

# puts "Output: $outfile"


set duration 1.5
set begin 0.5
set end [expr $begin + $duration]
set finish [expr $end + 0.5]

set cluster [new Cluster]

$cluster read_job $filename
$cluster ns_init
$cluster run $begin $end $finish

