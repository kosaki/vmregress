#!/usr/bin/perl
#
# generate_references
#
# Generates page reference data for a given mapsize, number of references and
# pattern
#
# This script reads the given proc entry and generates a graph using gnuplot

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Reference;
use strict;

# Option variables
my $man  =0;
my $help =0;
my $pattern = "linear";			# Reference pattern to use	
my $mapsize=-1;				# Size to mmap in pages
my $references=-1;			# Total number of page references
my $output = "-references-";		# Base name of output filenames

# Get options
GetOptions(
	'help|h'      	=> \$help, 
	'man'         	=> \$man,
	'size|s=s'    	=> \$mapsize,
	'pattern|p=s' 	=> \$pattern,
	'references|r=s'=> \$references,
	'output|o=s'  	=> \$output);

# Print usage if necessary
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Check usage
if ($mapsize == -1)         { die("Must supply a --size arguement"); }
if ($references == -1)      { $references = $mapsize; }
if (-d $output)		    { $output .= "/references" . "_pattern"; }

# Set output filename if not set
if ($output eq "-references-") { $output = $references . "_$pattern"; }

# Get reference data
generate_references($pattern, $references, $mapsize, 0, $output);

# Finish
print "Reference data outputted to $output\n";

# Below this line is help and manual page information
__END__

=head1 NAME

generate_references.pl - Generate page reference data for use with benchmarks

=head1 SYNOPSIS

generate_references.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --pattern       Page reference pattern (default: linear)
  --size          Size of area to benchmark with  
  --references    Number of references to generate
  --output        Output filename 

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--pattern>

This is the pattern to reference pages at. There is two types, linear and
smooth_sin.  linear will refer to pages from beginning to end and smooth_sin
will reference pages in a sin wave pattern. Note the page references are
quiet ordered and randomize_references.pl should be used to randomize them.

=item B<--size>

This is the size in pages the memory area been referenced is.

=item B<--references>

This is the number of references within the range to make. Note that to get
a noticable sin curve with smooth_sin, the number of references will need
to exceed the range considerably

=item B<--output>

The output file for the reference data

=back

=head1 DESCRIPTION

B<generate_references.pl> generates page reference data for use with
benchmarks. Data is dumped to disk because keeping all the references in
memory skews tests for large amounts of references. Note that this is *NO*
substitute for real reference data from a real program but this is very
handy for quick tests.

Two patterns can be generated, linear or smooth_sin . linear is referncing
each page in memory in a linear pattern. smooth_sin will refernece some
pages more than others so that the page reference graph looks like a sin curve.

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
