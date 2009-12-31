#!/usr/bin/perl
#
# test_fault.pl
#
# This is a front-end to the fault.o test module. It is a validation test
# to make sure a block of anonymous pages can be mmaped and then referenced.
# It will run four types of tests, each related to the amount of memory that
# is available.
#
# If CONFIG_HIGHMEM is available, ZONE_HIGHMEM is used, otherwise ZONE_NORMAL
# is. Four tests exist based on watermarks. They are
#
# testfast - Will allocate above the pages_high watermark
# testlow  - Will allocate between pages_low and pages_min
# testmin  - Will allocate between 0 and pages min
# testzero - Will allocate a region larger than physical memory
#
# Once the test starts, it cannot be interrupted. When it is finished, it will
# produce a report.

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use VMR::Pagemap;
use VMR::Kernel;
use VMR::Graph;
use VMR::File;
use VMR::External;
use VMR::Report;
use File::Basename;
use strict;

# Option variables
my $man  =0;
my $help =0;
my $passes=0;
my $mapsize=-1;
my $opt_testfast=0;
my $opt_testlow=0;
my $opt_testmin=0;
my $opt_testzero=0;
my $opt_nounload;

# Proc variables
my $proc;		# Proc entry read into memory
my $procentry="";	# Proc entry to write to
my $procarguments;	# Arguements passed to proc entries

# Output related
my $output="./test_fault";
my $path;		# Path to output directory
my $filehtml;		# Output HTML file
my $filemap;		# Output filename for graph
my $filevmstat;		# vmstat output graph
my $filedata_map;	# Shows pages present or swapped
my $dummy;		# Dummy variable for fileparse

# External program related
my $vmstat_output;	# Output from vmstat -n 1
my $uname_output;	# Output from uname

# Graph related
my $range;		# Range of the mapped region
my $decode;		# Decoded map
my $present;		# Number of present pages
my $total;		# Total number of pages

# Time related
my $starttime;
my $duration;

# Enumerate the tests
use constant TEST_FAST => "test_fault_fast";
use constant TEST_LOW  => "test_fault_low";
use constant TEST_MIN  => "test_fault_min";
use constant TEST_ZERO => "test_faule_zero";

# Get options
GetOptions(
	'help|h'   => \$help, 
	'man'      => \$man,
	'testfast' => \$opt_testfast,
	'testlow'  => \$opt_testlow,
	'testmin'  => \$opt_testmin,
	'testzero' => \$opt_testzero,
	'nounload' => \$opt_nounload,
	'passes=s' => \$passes,
	'size=s'   => \$mapsize,
	'output|o=s' => \$output);

# Fix up arguments if necessary
if ( -d $output ) { 
  $output .= "test_fault"; 
  $output .= "-fast" if ($opt_testfast);
  $output .= "-low"  if ($opt_testlow);
  $output .= "-min"  if ($opt_testmin);
  $output .= "-zero" if ($opt_testzero);
}

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Set option based information
$procentry = "test_fault_fast"  if ($opt_testfast);
$procentry = "test_fault_low"   if ($opt_testlow);
$procentry = "test_fault_min"   if ($opt_testmin);
$procentry = "test_fault_zero"  if ($opt_testzero);
$passes = 1   		        if ($passes <= 0);
$mapsize = ""		        if ($mapsize <= 0);
$procarguments = "$passes $mapsize";
die("You must specify a test to run") if $procentry eq "";

# Check for the correct kernel modules
checkmodule("vmregress_core");
checkmodule("pagetable");
checkmodule("fault");
checkmodule("zone");

# Set the output filenames
($output, $path, $dummy) = fileparse($output,"");
$filehtml     = $path . "$output.html";
$filemap      = $path . "$output-map.png";
$filevmstat   = $path . "$output-vmstat.png";
$filedata_map = $path . "$output-map.data";

# Open output files
reportOpen($filehtml);
open (MAP,  ">$filedata_map")  or die("Could not open $filemap");

# Open external files
openexternal("vmstat", "-n 1");
$vmstat_output = readexternal("vmstat");

# Print HTML report header
reportHeader("Demand Paging ($procentry) Validation Test Report");
reportZone("Before Test");

# Run test
print "Running test.... Test is non-interruptable and may take a long time!\n";
$starttime = time;
writeproc($procentry, $procarguments);
$proc = readproc($procentry);
print "Test completed\n";

# Close external programs
$duration = time;
$duration -= $starttime;
print "Test duration: $duration seconds\n";

# Read output from vmstat
print "Reading vmstat output\n";
while ($duration-- > 0) { $vmstat_output .= readexternal("vmstat"); }
closeexternal("vmstat");

# Decode map, print out and strip pagemap from proc entyr
($range, $decode, $present, $total) = findmap($proc, 0, 1);
print MAP $decode;
close MAP;
$proc = stripmap($proc);

# Plot graph
if ($decode ne "") {
print "Plotting page present graph\n";
gnuplot("default",
	"Page Present $range ($present of $total present)",
	"0 : $total", "0:2",
	$filemap,
	$filedata_map,
	"present");
}

# Plot vmstat
print "Plotting vmstat output\n";
gnuplot("vmstat",
	"vmstat -n output",
	":", ":",
	$filevmstat,
	$vmstat_output);

# Change image filenames to be the relative path for HTML output
$filemap    = "$output-map.png";
$filevmstat = "$output-vmstat.png"; 

# Print test results
reportTest($proc);
reportGraph("Page Presense", $path, "$filemap.ps",    $filemap);
reportGraph("vmstat output", $path, "$filevmstat.ps", $filevmstat);
reportEnvironment($vmstat_output);
reportFooter;
reportClose;

# Finish
if ($opt_nounload) {
  print "Kernel modules not unloaded to preserve test output\n";
} else {
  unloadmodules;
}
print "Results outputted to: $filehtml\n";

# Below this line is help and manual page information
__END__

=head1 NAME

test_fault.pl - Validation test for mmaped anonymous pages

=head1 SYNOPSIS

test_fault.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --testfast      Run test with pages allocated above pages_high
  --testlow       Run test between pages_low and pages_min
  --testmin       Run test between 0 and pages_min
  --testzero      Run test with more pages than physical memory
  --nounload      Do not unload kernel modules
  --passes        Number of passes to make on test
  --size          Optionally specify the number of pages to use
  --output        Output files prefix

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--testfast>

This will examine the pages_high watermark of the allocation zone and create
a region that will not affect that watermark

=item B<--testlow>

Same as above except the size brings the free pages between pages_low and
pages_min. This will determine if the system behaves correctly when memory
is slightly too low. kswapd should be woken up

=item B<--testmin>

Same sa above except the free pages will be between 0 and pages_min. This
will determin if the system behaves correctly in low memory conditions.
kswapd should be woken up and the testing process will synchrously free
pages

=item B<--testzero>

Same as above except there will be 0 free pages and if --size is used,
a region larger than physical memory can be created. This will test system
behaviour in really low memory conditions

=item B<--nounload>

If specified, kernel modules for this test will not be unloaded on exit.

=item B<--passes>

How many times to run the same test

=item B<--size>

Optionally specify the size of the region to use. With tests other than
testzero, it may not run if the size is too large.

=item B<-output>

By default the program will output all data to the current directory. This
switch will allow a differnet directory and name to be used. The name supplied
is used as a prefix to any produced file. For example, the HTML file is
called prefix.html and the time reference graph is called prefix-time.png.

=back

=head1 DESCRIPTION

No detailed description available. Consult the full documentation

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
