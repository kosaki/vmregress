#!/usr/bin/perl
#
# replot_time.pl
#
# This is a helper script to replot a Page Time Access graph. When doing 
# comparisons between two VM's, it's useful if the graphs are of the same
# scale. Of course, there is no way to know what the graph will look like
# in advance so this script will replot the graph once the new scale is
# known
#

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Graph;
use strict;

# Option variables
my $man  =0;
my $help =0;

my $filedata_time = "./default-time.data";	# Input time data
my $filetime      = "./default-time.png";	# Output graph name
my $miny=-1;					# New min y range 
my $maxy=-1;					# New max y range

# Get options
GetOptions(
	'help|h'   => \$help, 
	'man'      => \$man,
	'timedata=s' => \$filedata_time,
	'miny=s'   => \$miny,
	'maxy=s'     => \$maxy,
	'output=s'   => \$filetime);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Check usage
if ( ! -e $filedata_time) { die("Input data file $filedata_time doesn't exist"); }
if ( $miny == -1)	  { $miny=""; }
if ( $maxy == -1)         { $maxy=""; }

# Plot time information
print "Plotting page access time graph\n";
gnuplot("default",
	"Page Access Times (Adjustment $miny)",
	":", "$miny : $maxy",
	$filetime,
	$filedata_time,
	"times");

print "Finished\n";

# Below this line is help and manual page information
__END__

=head1 NAME

replot.pl - Plot a graph using VMR::Graph

=head1 SYNOPSIS

replot.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --timedata      Input time data file
  --miny          Minimum yrange (Referred to as Adjustment)
  --maxy          Maximum yrange
  --output        Output graph name
  
=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--timedata>

Input time data preserved from a test

=item B<--miny>

The minimum y value. This is referred to as Adjustment in benchmarks like
the bench_mmap.pl test. It is a best guess at the time overhead of the test
and kernel module itself. It should be preserved.

=item B<--maxy>

The manimum y value.

=item B<--output>

The output PNG filename. The postscript file will also be preserved

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
