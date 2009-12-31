#!/usr/bin/perl
#
# bench_mmmap
#
# This is a benchmarking script aimed at mmap usage with either anonymous
# or file backed areas. It uses the interfaces provided by the mmap module 
# with VM Regress. It asks for an address space to be created of a given 
# size and then references pages in it with a given pattern. It then 
# produces a report showing information obtained from both this script 
# and the kernel module
#
# This script reads the given proc entry and generates a graph using gnuplot
#
# Next modifications in bench_mmap are made by Leonid Ananiev leonid.i.ananiev@intel.com
# 
# 	- The access time measurements surrounds now page touch module call
#	  rather than all loop with other pages and files touching and functions callings.
#	- Address access pattern is generated inside main loop but not read
#	  from huge external file that creates additional memory load.
#	- Lognormal and Zipfian random number generator may be used now to create
#	  access addresses.
# 	- More statistic data is collected in smaller array volume since average
#	  and max access time is collected for each page rank and for each second
#	  interval only. Access time and vmstat data outputs are synchronized.
#    - More detailed virtual memory statistic are collected from /proc/vmstat
#	  rather than from vmstat command output.

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Pagemap;
use VMR::Time;
use VMR::Kernel;
use VMR::File;
use VMR::Reference;
use VMR::Graph;
use VMR::External;
use VMR::Report;
use File::Basename;

sub vmrdie {
	my $message = shift;
	unloadmodules;
	die($message);
}

# Option variables
my $man  =0;
my $help =0;
my $pattern = "lognormal";		# Default pattern is 'lognormal'. 
my $mapsize=-1;				# Size to mmap in pages
my $totalreferences=-1;			# Total number of page references
my $totalpasses=-1;			# Number of passes through references
my $test_write=0;			# Set to 1 if --write is specified
my $maxtime_yrange=0;			# The max y range for timing data
my $opt_nounload;			# Option to leave kernel modules loaded

# Output variables
my $output = "mapanon";			# Base name of output filenames
my $path;				# Path to output
my $filehtml;				# HTML Filename
my $fileref;				# Page refindex over time
my $filemaxt;				# Page max time access
my $fileavrg;				# Page average access time
my $filetime;				# Time to access pages
my $fileruntime;			# Time to access pages
my $filemap="/dev/null";		# File to memory map
my $filedata_plot;			# Data file for pagemap
my $filedata_time;			# Data file for time data
my $filedata_runtime;			# Data file for 'running time' - 'elapced time' data
my $filedata_ref;			# Data file for page references
my $filedata_maxt;			# Data file for max page access time
my $filedata_avrg;			# Data file for  averagepage access time 
my $filedata_age;			# Data file showing page age
my $refdata_supplied=0;			# Set to 1 if refdata is supplied

# Graph related
my $addr;				# Address of a mapped region
my $addrhex;				# Address in hex
my $pid;				# PID addr belongs to. Ours hopefully
my ($range, $decode, $present, $total); # Page map decoded information
my $dummy;				# Dummy var for splits

# Time related
my $timetoken;				# Token returned by gettime
my $starttime;				# Start time in seconds
my $starttime_token;			# Start time as returned by Time.pm
my $endtime;	
my $duration_seconds;			# Length of test in seconds
my $duration;				# Duration in human readable form
my $unmap_time;				# Time taken to unmap, indicates sync time
my $ref_fastest;			# Quickest page reference
my $ref_slowest;			# Slowest reference
my $ref_average;			# Average reference
my $elapsed;				# Elasped time from difftime
my $running_time;			# Running time from test start
my $prev_running_time;			# Previous time for printing updates
my $sum_elapsed;			# Summery elapsed time for average for last second
my $fsum_elapsed;			# Summery elapsed time
my $num_elapsed;			# Number for avarege elased time
my $max_elapsed;			# Max elased time for last second

# Reference information
my @references;				# Count of times a page is referenced
my @max_for_page;			# Max access time to page
my @avrg_for_page;			# Average access time to page
my @lastref;				# When a page was last referenced
my $maxage;				# The oldest page in the test

# Proc related
my $reportTitle="";
my $proc;				# Information read from a proc entry
my $procarguments;			# Arguements to write to the proc entry
my $proc_readwrite="map_read";		# Name of the proc entry to use

# External program related
my $uname_output;			# Output from uname
my $date;				# date of test running

# Count variables
my $pageindex;				# Page been touched
my $pageage;				# Age of the page in milliseconds
my $refindex;				# Index within @refdata
my $pass;				# What pass been run

# System parameters
use constant PROT_READ   => 0x01;
use constant PROT_READ   => 0x01;
use constant PROT_WRITE  => 0x02;
use constant MAP_SHARED  => 0x01;
use constant MAP_PRIVATE => 0x02;
my $PAGE_SIZE=4096;

# Get options
GetOptions(
	'help|h'      	=> \$help, 
	'man'         	=> \$man,
	'size|s=s'    	=> \$mapsize,
	'pattern|p=s' 	=> \$pattern,
	'filemap|f=s'   => \$filemap,
	'write|w'	=> \$test_write,
	'references|r=s'=> \$totalreferences,
	'passes|c=s'  	=> \$totalpasses,
	'time_maxy|m=s' => \$maxtime_yrange,
	'nounload'      => \$opt_nounload,
	'output|o=s'  	=> \$output);

# Print usage if necessary
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Check usage
if ($mapsize == -1)         { $mapsize = 600000; }
if ($totalpasses == -1)     { $totalpasses = 1; }
if ($test_write)	    { $proc_readwrite = "map_write"; }
if (-d $output)		    { $output .= "/mapanon"; }

# Check for the correct kernel modules
checkmodule("vmregress_core");
checkmodule("pagetable");
checkmodule("mmap");
checkmodule("pagemap");
checkmodule("zone");

# Set Filenames
($output, $path, $dummy) = fileparse($output,"");

# - These files are what appears on the report page
$filehtml       = $path . "$output.html";
$fileref        = $path . "$output-ref.png";
$filetime       = $path . "$output-time.png";
$fileruntime    = $path . "$output-runtime.png";
$filemaxt       = $path . "$output-maxt.png";
$fileavrg       = $path . "$output-avrg.png";

# - These are the generated data files retained for statistical analysis
$filedata_time    = $path . "$output-time.data";
$filedata_runtime = $path . "$output-runtime.data";
$filedata_plot    = $path . "$output-pagemap.data";
$filedata_maxt    = $path . "$output-maxt.data";
$filedata_avrg    = $path . "$output-avrg.data";
$filedata_ref     = $path . "$output-refcount.data";

# Get the kernel version
openexternal("uname", "-r -v -p");
$uname_output = readexternal("uname");
closeexternal("uname");

# Print report header
reportOpen($filehtml);
if ($filemap eq "/dev/null") {
  if ($test_write) { reportHeader("Anonymous Page Write Reference Benchmark Report"); }
  else		  { reportHeader("Anonymous Page Read Reference Benchmark Report");  }
} else { 
  if ($test_write) { reportHeader("File Backed Page Write Reference Benchmark Report"); }
  else		  { reportHeader("File Backed Page Read Reference Benchmark Report");  }
}

# Print out the report parameters
reportPrint("Test Parameters\n");
reportPrint("---------------\n\n");
reportPrint("Kernel:         $uname_output");

reportPrint("Reference data: ");
reportPrint("Auto-generated ($pattern)\n");
reportPrint("Page Type:      ");
if ($filemap eq "/dev/null") { reportPrint("Anonymous\n"); }
else                         { reportPrint("File Backed ($filemap)\n"); }
reportPrint("Page Operation: ");
if ($test_write) { reportPrint("Write\n"); }
else             { reportPrint("Read\n");  }
reportPrint("\n");

reportPrint("Page size $PAGE_SIZE\n");

reportZone("Before Test");

# Map a memory region
if ($filemap eq "/dev/null") {
	# Map an anonymous region of memory
	writeproc("mapanon_open", $mapsize * $PAGE_SIZE);
} else {
	# Memory map the requested file
	open(MAPFILE, "+<$filemap") || vmrdie("Cannot open $filemap to memory map");
#	sysopen(MAPFILE, "$filemap", O_RDWR | O_DIRECT) || vmrdie("Cannot open $filemap to memory map O_RDWR | O_DIRECT");

	# Build the arguements for proc
	$procarguments = $mapsize * $PAGE_SIZE . " ";
	$procarguments .= (PROT_READ | PROT_WRITE) . " ";
	$procarguments .= (MAP_SHARED) . " ";
	$procarguments .= fileno(MAPFILE);
	$procarguments .= " 0";

	writeproc("mapfd_open", $procarguments);
}
$proc = readproc("map_addr");
($pid, $addr, $addrhex) = split(/ /, $proc);
chop($addrhex);
if ($addrhex =~ /^0xFFFF/) {
  die("Mapped address $addrhex looks like a failed mapping, probably due to lack of address space");
}
print "Mapped $mapsize pages at $addrhex PID=$pid\n";

# Open tempfiles
open (PLOT, ">$filedata_plot") or vmrdie("Could not open $filedata_plot");
open (TIME, ">$filedata_time") or vmrdie("Could not open $filedata_time");
open (RTIME, ">$filedata_runtime") or vmrdie("Could not open $filedata_runtime");
open (REF,  ">$filedata_ref")  or vmrdie("Could not open $filedata_ref");
open (MAXT,  ">$filedata_maxt")  or vmrdie("Could not open $filedata_maxt");
open (AVRG,  ">$filedata_avrg")  or vmrdie("Could not open $filedata_avrg");

print "Touch each page twice to be in stable state\n";
$starttime=time();
$prev_running_time=$starttime;
for ($pass=1; $pass <= 2; $pass++) {
	for ($pageindex=$mapsize - 1; $pageindex >=0 ; $pageindex--) {
		$running_time=time();
		if ($prev_running_time != $running_time) {   # new second
			$prev_running_time=$running_time;
				# Print out some progress so the user knows we're alive
				syswrite STDOUT, "\r" . ($mapsize - $pageindex) . " or " .
					int(100 * ($mapsize - $pageindex) / $mapsize) .
					"% referenced. Running time " . 
					int($running_time - $starttime) . " sec";
			}
		$procarguments = sprintf "%d %d\n",
			$addr + ($pageindex * $PAGE_SIZE), 1;
#print "Touch each page twice to be in stable state $pageindex\n";
		writeproc($proc_readwrite, $procarguments);
	}
	syswrite STDOUT, "\n";
}
openexternal("date", "");
$date = readexternal("date");
closeexternal("date");
reportPrint("Date:         $date\n");

# Reference pageng_timeu
print "Referencing pages\n";
$starttime = time();
$timetoken = gettime();
$starttime_token = $timetoken;
($running_time, $dummy)   = split(/\|/, $timetoken);
$prev_running_time = $running_time;
$ref_fastest = 1000000;
$ref_slowest = 0;
$ref_average = "Not Calculated";
$sum_elapsed=0;
$fsum_elapsed=0;
$num_elapsed=1;
$max_elapsed=0;

# Open external programs of interest

system("$Bin/ksw_stat.sh > mapanon-vmstat.data &");

$refindex=0;
print RTIME "#running_time, max_elapsed, avrg_elapsed, num_elapsed, refindex, running_tm\n";
srand(42);
if ($totalreferences == -1) { 
	$totalreferences=$mapsize * (int(log($mapsize)))
				if $pattern eq "lognormal";
	$totalreferences=$mapsize * 3
				if $pattern eq "zipf05";
}
while ($refindex++ < $totalreferences) {
	$pageindex = lognormal($mapsize) if $pattern eq "lognormal";
	$pageindex = zipf05($mapsize) if $pattern eq "zipf05";

	# mapanon_read takes two parameters, the address to read and
	# the number of bytes
	$procarguments = sprintf "%d %d\n", $addr + ($pageindex * $PAGE_SIZE), 1;
	$timetoken = gettime();
	writeproc($proc_readwrite, $procarguments);
	$elapsed = difftime($timetoken, gettime(), 0);

	($running_time, $dummy)   = split(/\|/, $timetoken);
	if ($prev_running_time != $running_time) {   # new second
		# Read from external programs

		$timetoken = gettime();
		($prev_running_time, $dummy)   = split(/\|/, $timetoken);

		print RTIME ($running_time - $starttime) . " $max_elapsed " .
			int($sum_elapsed/$num_elapsed) .
			" $num_elapsed $refindex $running_time\n";
		print TIME ($running_time - $starttime) . " " . 
			int($sum_elapsed/$num_elapsed) . "\n";
		$sum_elapsed=0;
		$num_elapsed=1;
		$max_elapsed=0;
		if ($running_time % 30) {
			# Print out some progress so the user knows we're alive
			syswrite STDOUT, "\r" .
				int(100 * $refindex / ($totalreferences * $totalpasses)) .
				"% referenced. Running time " . 
				int(($running_time  - $starttime)/ 60) . " min";
		}
	}
	if($elapsed > $max_elapsed) {$max_elapsed = $elapsed;}
	$sum_elapsed += $elapsed;
	$fsum_elapsed += $elapsed;
	$num_elapsed++;
	# Record fastest/slowest access times
	if ($elapsed > $ref_slowest) { $ref_slowest = $elapsed; }
	if ($elapsed < $ref_fastest) { $ref_fastest = $elapsed; }

	if ($max_for_page[$pageindex] < $elapsed)
		{ $max_for_page[$pageindex] = $elapsed; }
	$avrg_for_page[$pageindex] =
		 ($avrg_for_page[$pageindex] * $references[$pageindex] + $elapsed) 
			/ (++$references[$pageindex]);
}
syswrite STDOUT, "\n$refindex of " . $totalreferences . " referenced...." .
		 "Pass $totalpasses of $totalpasses\n";

close TIME;
close RTIME;
$endtime = time();
$elapsed = difftime($starttime_token, gettime, 1);
$duration_seconds = $endtime - $starttime;
$duration  = int($duration_seconds / 3600) . " hours ";
$duration_seconds  = $duration_seconds % 3600;
$duration .= int($duration_seconds / 60)   . " minutes ";
$duration .= int($duration_seconds % 60)   . " seconds";

# Dump reference count information
for ($pageindex=0; $pageindex<$mapsize; $pageindex++) {

	# Print out the page reference
	if (exists $references[$pageindex]) {
		print REF "$pageindex " . $references[$pageindex] . "\n";
	} else {
		print REF "$pageindex " . "0\n";
	}
	if (exists $max_for_page[$pageindex]) {
		print MAXT "$pageindex " . $max_for_page[$pageindex] . "\n";
	} else {
		print MAXT "$pageindex " . "0\n";
	}
	if (exists $avrg_for_page[$pageindex]) {
		print AVRG "$pageindex " . $avrg_for_page[$pageindex] . "\n";
	} else {
		print AVRG "$pageindex " . "0\n";
	}
}
close REF;
close MAXT;
close AVRG;

print "Reading page map\n";
$proc = readproc("pagemap_read");
($range, $decode, $present, $total) = findmap($proc, $addrhex, 1);
print PLOT $decode;
close PLOT;

# Unmap area
$starttime_token = gettime;
writeproc("map_close", "$addr " . $mapsize*$PAGE_SIZE);
if ($filemap ne "/dev/null") { close FILEMAP; }
$unmap_time = int difftime($starttime_token, gettime, 1);

# Sleep 1 second to allow external programs, especially vmstat to output one last time
sleep(1);

# Close external programs

gnuplot("default",
        "Average page access time (mcsec) vs page index",
	":", ":",
	$fileavrg,
	$filedata_avrg,
	"avrg time mcsec");

gnuplot("default",
        "Max page access time (mcsec) vs page index",
	":", ":",
	$filemaxt,
	$filedata_maxt,
	"max time mcsec");


if ($maxtime_yrange == 0) { $maxtime_yrange = $ref_slowest; }
gnuplot("default",
	"The dependence Average Page Access Times (mcsec) upon running time (sec)",
	":", "$ref_fastest : $maxtime_yrange",
	$filetime,
	$filedata_time,
	"time mcsec");

system("gnuplot $Bin/plot_com");

# Change image filenames to be the relative path for HTML output
$fileref      = "$output-ref.png";
$filemaxt     = "$output-maxt.png";
$fileavrg     = "$output-avrg.png";
$filetime     = "$output-time.png";
$fileruntime  = "$output-runtime.png";

# Print the report results
reportPrint("MMap Region\n");
reportPrint("-----------\n");
reportPrint("Region:           $range ($mapsize pages)\n");
reportPrint("Addr:             $addrhex\n");
reportPrint("Passes:           $totalpasses\n");
reportPrint("Reference count:  $totalreferences\n");
reportPrint("Total references: $refindex\n");
reportPrint("Fastest access:   $ref_fastest mcsec\n");
reportPrint("Slowest access:   $ref_slowest mcsec\n");
$fsum_elapsed=int( $fsum_elapsed / $refindex);
reportPrint("Average access:   $fsum_elapsed mcsec\n\n");

reportPrint("Test duration:   $duration Start time: $starttime\n");
reportPrint("Unmap duration:  $unmap_time ms\n\n");

reportZone("After Test");
reportGraph("The dependence Average Page Access Times (mcsec) upon running time (sec)",
		$path, "$filetime.ps",     $filetime);
reportGraph("Max Page Access Time",    $path, "$filemaxt.ps", $filemaxt);
reportGraph("Average Page Access Time",    $path, "$fileavrg.ps", $fileavrg);
reportFooter;
reportClose;

system("kill `ps -ef | awk '/ksw_stat.sh/ && !/awk/{print \$2}'`");
# Finish
if ($opt_nounload) {
  print "Kernel modules not unloaded to preserve test output\n";
} else {
  unloadmodules;
}
print "Test Duration: $duration\n";
print "Results outputted to $filehtml\n";

##
# agesort - Used for sorting the lastref array into time order
sub agesort {
	my ($a, $b) = @_;
	my ($idxa, $lastrefa);
	my ($idxb, $lastrefb);
	
	($idxa, $lastrefa) = split(/ /, $a);
	($idxb, $lastrefb) = split(/ /, $b);

	$lastrefa cmp $lastrefb;
}
	
# Below this line is help and manual page information
__END__

=head1 NAME

bench_mapanon.pl - Benchmark page reference performance with mmaped anonymous memory

=head1 SYNOPSIS

bench_mapanon.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --size          Size of area to benchmark with  
  --refdata       Alternatively, use this source file of reference data
  --write         Boolean to indicate if a write test should be performed
  --pattern       Page reference pattern (default: lognormal)
  --filemap       File to memory map (default: use anonymous memory)
  --references    Amount of references to generate
  --passes        Number of times to read reference data
  --time_maxy     The maximum yrange for the time page reference graph
  --nounload      Do not unload kernel modules
  --output        Output filename (extensions appended)

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--size>

This is the size in pages of the area to be tested. It must be provided

=item B<--refdata>

The preferred way to supply reference data is with a file containing a list
of page references. This may be generated with B<generate_references.pl>. If
it is undesirable to generate such a file, use the --pattern and --references
switches to generate one

=item B<--write>

By default the test will read the memory area. If this switch is enabled, a
write test will be performed instead

=item B<--pattern>

If data is not provided, --pattern will produce a lognormal distribution pattern.
'zipf05' pattern may be set to get zipfina distribution pattern with exponent=0.5.

=item B<--filemap>

Without this switch, anonymous memory is benchmarked. With this switch, the
file referred to will be mmaped by the benchmark process and used. This is
useful for determining how well the VM is able to treat either set of pages
a process generally uses

=item B<--references>

Similar for --pattern, this switch will produce the given number of references.

=item B<--passes>

If the reference dataset is quiet small, it may be desirable to run through the
same dataset a number of times. This switch will run the benchmark B<passes>
number of times

=item B<--time_maxy>

When comparing two sets of timing graphs, it is useful to make sure they have
the same y range. The yrange can be fixed with this parameter. Alternatively
the B<gnuplot.pl> script can be used to regraph the time data

=item B<--nounload>

If specified, kernel modules for this test will not be unloaded on exit.

=item B<--output>

By default the program will output all data to the current directory. This
switch will allow a differnet directory and name to be used. The name supplied
is used as a prefix to any produced file. For example, the HTML file is
called prefix.html and the time reference graph is called prefix-time.png.

=back

=head1 DESCRIPTION

B<bench_mapanon.pl> benchmarks VM behaviour with regards to anonymously
mapped memory with mmap. It produces a report and keeps the data for future
analysis. The report is broken up into three sections. The first section gives
some parameters of the test, some memory statistics and the kernel version
been tested. It has such information as the fastest and slowest page access,
the size of the area tested, how many pages referenced, length of the test
etc. The zone information before and after the test is also provided.

The second section is some data graphs.  The first graph "Page Access Times"
graphs how long it takes in microseconds to reference each page. The second
"Page Map" shows a graph of page reference count Vs page presence. It should
be noted this is a bit misleading for testing VM's as the page replacement
policy is based on age, not frequency a page was used. A graph to show page
presence Vs page age will be available in a later version. The last graph
shows the output from B<vmstat -n 1>

The last section has the entire output from vmstat, the information in
/proc/cpuinfo and the information in /proc/meminfo so the reader knows
something about the host system.

Three sets of data are preserved for future analysis. The first
B<prefix-time.data> is how long each page reference took in microseconds. The
first column is the number reference, the second column the time. The
second data file is B<prefix-pagemap.data> shows what pages were present
in memory. If it is 0, it is absense and otherwise it is present. The last
file is B<prefix-refcount.data> which contains how many times each page was
referenced. If a set of page references was not provided, the generated file
will be stored in B<prefix-pagereferences.data> but it is recommended data
is prepared with the B<generate_references.pl> script.

For each of these files, the prefix is determined by the --output switch. By
default it will be mapanon.

This script requires the Time::HiRes Perl module, a recent version of gnuplot
and the imagemagick tools are all available.

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
