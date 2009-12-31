#!/usr/bin/perl
#
# mapfrag_stat
#
# This uses the test_allocmap module to determin the dispersion of userspace
# and kernel space allocations. This can help determine how easy it would be
# to get large free blocks of memory

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
my $opt_nounload;

# Proc variables
my $proc;		# Proc entry read into memory
my $procentry="none";	# Proc entry to write to
my $procarguments;	# Arguements passed to proc entries

# Output related
my $output="./allocmap";
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
	'nounload' => \$opt_nounload,
	'output|o=s' => \$output);

# Set option based information
$passes = 1 		        if ($passes <= 0);
$mapsize = ""		        if ($mapsize <= 0);
$procarguments = "$passes $mapsize";

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Check for the correct kernel modules
checkmodule("vmregress_core");
checkmodule("trace_allocmap");

# Set the output filenames
($output, $path, $dummy) = fileparse($output,"");
$filehtml     = $path . "$output.html";

# Open output files
reportOpen($filehtml);

# Print HTML report header
reportHeader("Allocation Distribution Map Report");

# Read in all block information form /proc
my $line;
my @blockName;
my @block="";
my $blockIndex=-1;
my $patch_check=0;
foreach $line (split /\n/, readproc("trace_allocmap")) {
  if (!$patch_check) {
    $patch_check=1;
    if ($line =~ /Kernel patch trace_pagealloc.diff/) {
      die("Kernel patch is not applied that is required for mapfrag_stat.pl to work");
    }
  }

  if ($line =~ /^Node/) { 
  	print "Reading: $line\n"; 
	$blockIndex++;
	$blockName[$blockIndex] = $line;
	next;
  }

  # Append this block information
  $block[$blockIndex] .= $line;
}

# Analyse the block
my $page;
my $lastPage;
my $tmpfile;

# Go through all the blocks in the system
for ($blockIndex=0; $blockIndex<=$#block; $blockIndex++) {
  print "Analysing: $blockName[$blockIndex]\n";

  # Open gnuplot input file
  my ($dummy, $node, $dummy, $zone)  = split /\s+/, $blockName[$blockIndex];
  my $tmpfile = "/tmp/$node-$zone.plot";
  open (TMPOUTPUT, ">$tmpfile") || die("Temp open failed");

  # Print report header
  reportPrint("$blockName[$blockIndex]\n");
  my ($pageCount, $freeCount, $userrclmCount, $kernrclmCount, $kernnorclmCount);
  my ($contigSize, $maxContigSize, $contigNo, $maxContigType);

  # Go through every page in the map
  my $lastPage='-';
  foreach $page (split //, $block[$blockIndex]) {
    if ($lastPage eq '-') { $lastPage = $page; }

    # Update bean counters
    my $type = 3;
    if ($page eq '.') { $freeCount++;   $type = 0; }
    if ($page eq 'u') { $userrclmCount++;   $type = 1; }
    if ($page eq '|') { $kernrclmCount++; $type = 2; }
    if ($page eq 'O') { $kernnorclmCount++; $type = 3; }
    print TMPOUTPUT "$pageCount $type\n";
    $pageCount++;

    # Check the size of the contig block
    if ($lastPage ne $page) {
      $contigNo++;
      if ($contigSize > $maxContigSize) { 
        $maxContigSize = $contigSize; 
	$maxContigType = $lastPage;
      }
      $lastPage = $page;
      $contigSize=0;
    } else {
      $contigSize++;
    }
  }

  # Plot map
  close TMPOUTPUT;
  my $nkp = $kernnorclmCount * 100 / $pageCount;
  my $kp = $kernrclmCount * 100 / $pageCount;
  my $fp = $freeCount * 100 / $pageCount;
  my $up = $userrclmCount * 100 / $pageCount;
  my $title = sprintf("Fragmentation map KernNoRclm (%4.2f%%) KernRclm (%4.2f%%) UserRclm (%4.2f%%) Free (%4.2f%%)", $nkp, $kp, $up, $fp);
  gnuplot("Boxes",
          $title,
          "0 : $pageCount", "0:3.5",
          "$output-$node-$zone.png",
          "$tmpfile",
          "0 = free 1 = user reclaim 2 = kernel reclaim 3 = kernel unreclaim");
  reportGraph("Distribution Map: Node $node Zone $zone\n", 
		$path,
		"$output-$node-$zone.png.ps",
		"$output-$node-$zone.png");

  reportPrint("Total pages:      $pageCount\n");
  reportPrint("Free pages:       $freeCount\n");
  reportPrint("UserRclm pages:   $userrclmCount\n");
  reportPrint("KernRclm pages:   $kernrclmCount\n");
  reportPrint("KernNoRclm pages: $kernnorclmCount\n\n");

  reportPrint("Contiguous size report\n");
  reportPrint("No contiguous blocks: $contigNo\n");
  reportPrint("Max contiguous size:  $maxContigSize ($maxContigType)\n\n");
}

# Print test results
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

mapfrag_stat.pl - Generate maps showing the distribution of allocation types

=head1 SYNOPSIS

mapfrag_stat.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --nounload      Do not unload kernel modules
  --output        Prefix the output files with this string

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--nounload>

If specified, kernel modules for this test will not be unloaded on exit.

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
