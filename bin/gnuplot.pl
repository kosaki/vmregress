#!/usr/bin/perl
#
# gnuplot.pl
#
# This is a simple frontend to the VMR::Graph library for gnuplot. Arguements
# given to the script are passed in directory to the function
#
# This script reads the given proc entry and generates a graph using gnuplot

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Graph;
use strict;

# Option variables
my $man  =0;
my $help =0;

# Get options
GetOptions(
	'help|h'   => \$help, 
	'man'      => \$man);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Print out information about the graph
print "Calling gnuplot";
print "\nType:          " . @ARGV[0];
print "\nTitle:         " . @ARGV[1];
print "\nX Range:       " . @ARGV[2];
print "\nY Range:       " . @ARGV[3];
print "\nOutput Graph:  " . @ARGV[4];
print "\nData Source 1: " . @ARGV[5];
print "\nName Source 1: " . @ARGV[6];
print "\nData Source 2: " . @ARGV[7];
print "\nName Source 2: " . @ARGV[8];
print "\n";

gnuplot(@ARGV);

print "Finished\n";

# Below this line is help and manual page information
__END__

=head1 NAME

gnuplot.pl - Plot a graph using VMR::Graph

=head1 SYNOPSIS

gnuplot [options] parameters

 Options:
  -help          Print help messages
  -man           Print man page

=head1 OPTIONS

=over 8

=item B<-help>

Print a help message and exit

=item B<parameters>

These are the parameters to pass to the gnuplot function. They are, in order

type:    Type of source data

title:   Title for the graph

range:   The X range described as from:to

range:   The Y range described as from:to

output:  Output PNG file

ds1:     The first data source

ds1name: Name of the data been graphed

ds2:     The second data source

ds2name: Name of the second data been graphed

See the VMR::Graph documentation for more details

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
