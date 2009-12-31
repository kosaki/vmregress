#!/usr/bin/perl
#
# test_alloc.pl
#
# This is a front-end to the alloc.o test module. It is a validation test
# to make sure that __alloc_pages and __free_pages will work for varying
# levels of memory pressure
#
# testfast - Will allocate above the pages_high watermark
# testlow  - Will allocate between pages_low and pages_min
# testmin  - Will allocate between 0 and pages min
# testzero - Will allocate a region larger than physical memory
#
# Once the test starts, it cannot be interrupted. When it is finished, it will
# produce a report. If the test dies or gets killed, the machine will have to
# be rebooted

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
my $opt_testfast;
my $opt_testlow;
my $opt_testmin;
my $opt_testzero;
my $opt_nounload;

# Proc variables
my $proc;		# Proc entry read into memory
my $procentry="none";	# Proc entry to write to
my $procarguments;	# Arguements passed to proc entries

# Output related
my $output="./test_alloc";
my $path;		# Path to output directory
my $filehtml;		# Output HTML file
my $filevmstat;		# vmstat output graph
my $dummy;		# Dummy variable for fileparse

# External program related
my $vmstat_output;	# Output from vmstat -n 1

# Time related
my $starttime;
my $duration;

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

# Set option based information
$procentry = "test_alloc_fast"  if ($opt_testfast);
$procentry = "test_alloc_low"   if ($opt_testlow);
$procentry = "test_alloc_min"   if ($opt_testmin);
$procentry = "test_alloc_zero"  if ($opt_testzero);
$passes = 1 		        if ($passes <= 0);
$mapsize = ""		        if ($mapsize <= 0);
$procarguments = "$passes $mapsize";

# Fix up arguments if necessary
if ( -d $output ) { 
  $output .= "test_alloc"; 
  $output .= "-fast" if ($opt_testfast);
  $output .= "-low"  if ($opt_testlow);
  $output .= "-min"  if ($opt_testmin);
  $output .= "-zero" if ($opt_testzero);
}

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
(print "ERROR: You must specify a test\n" && 
 pod2usage(-exitstatus => 0, -verbose => 0)) if $procentry eq "none";

# Check for the correct kernel modules
checkmodule("vmregress_core");
checkmodule("alloc");
checkmodule("zone");

# Set the output filenames
($output, $path, $dummy) = fileparse($output,"");
$filehtml     = $path . "$output.html";
$filevmstat   = $path . "$output-vmstat.png";

# Open output files
reportOpen($filehtml);

# Open external files
openexternal("vmstat", "-n 1");
$vmstat_output = readexternal("vmstat");

# Print HTML report header
reportHeader("Physical Page Allocation ($procentry) Validation Test Report");
reportZone("Before Test");

# Run test
print "Running test.... Test is non-interruptable!\n";
$starttime = time;
writeproc($procentry, $procarguments);
$proc = readproc($procentry);
print "Test completed\n";

# Close external programs
$duration = time;
$duration -= $starttime;
while ($duration-- > 0) { $vmstat_output .= readexternal("vmstat"); }
closeexternal("vmstat");

# Plot vmstat
print "Plotting vmstat output\n";
gnuplot("vmstat",
	"vmstat -n output",
	":", ":",
	$filevmstat,
	$vmstat_output);

# Change image filenames to be the relative path for HTML output
$filevmstat = "$output-vmstat.png"; 

# Print test results
reportTest($proc);
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

test_alloc.pl - Validation test for physical page allocation routines

=head1 SYNOPSIS

test_alloc.pl [options]

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

This will examine the pages_high watermark of the allocation zone and allocate
a number of pages so that the watermark is not affected

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

Same as above except there will be 0 free pages and if --mapsize is used,
a region larger than physical memory can be created. This will test system
behaviour in really low memory conditions

=item B<--nounload>

If specified, kernel modules for this test will not be unloaded on exit.

=item B<--passes>

How many times to run the same test

=item B<--size>

Optionally specify the number of pages to allocate. The tests with the
exception of testzero may not run if the mapsize is too large.

=item B<-output>

By default the program will output all data to the current directory. This
switch will allow a differnet directory or name to be used. If the supplied
argument is a directory, then the directory will be used to place results
in with an intelligent prefix. Else, the argument is used as a prefix for
output files. For example, if the name is "prefix", the result HTML file is
called prefix.html and the time reference graph is called prefix-time.png.

=back

=head1 DESCRIPTION

No detailed description available. Consult the full documentation in the
docs/ directory

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
