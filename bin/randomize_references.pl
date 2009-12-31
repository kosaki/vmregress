#!/usr/bin/perl
#
# randomize_references
#
# Takes a file of page references and randomizes them in an ad-hoc manner.
# This is not a brillant way of randomizing but it does the trick.
#

use FindBin qw($Bin);
use lib "$Bin/lib/";

use Getopt::Long;
use Pod::Usage;
use VMR::Reference;
use VMR::File;
use strict;

# Option variables
my $man  =0;
my $help =0;
my $input = "-references-";		# Input file
my $output = "-references-";		# Base name of output filenames
my $tempfile = mktempname("randomize");

my $reference;
my $mapsize;
my $refcount;
my $count;
my $random;

# Get options
GetOptions(
	'help|h'      	=> \$help, 
	'man'         	=> \$man,
	'input|i=s'	=> \$input,
	'output|o=s'  	=> \$output);

# Print usage if necessary
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

# Check usage
if ($input eq 'references') { die("You must supply an input dataset"); }
if (-d $output)		    { $output .= "/$input" . "_random"; }

# Open output file
open (OUTPUT, ">$tempfile") || die("Failed to open output file $tempfile");

# Open input file and read header
open (INPUT, $input);
$reference = <INPUT>;
($mapsize, $refcount) = split(/ /, $reference);
chop($refcount);
print "Mapsize:    $mapsize\n";
print "References: $refcount\n";

# Read input file and print progress
$count=0;
print "Reading input file\n";
while (!eof(INPUT)) {
	# Read a reference
	$reference = <INPUT>;
	$count++;

	# Print out the reference with a random number at the beginning
	$random = rand $refcount;
	print OUTPUT "$random $reference";

	if ($count % 10000 == 0) {
		syswrite STDOUT, "\r$count references of $refcount read.";
	}
}
close INPUT;
close OUTPUT;

# Write header to output
open (OUTPUT, ">$output") || (
	unlink($tempfile) && die("Failed to open output file $output"));
print OUTPUT "$mapsize $refcount\n";

print "\nExecing sort... This could take a long time!\n";
open(PIPE, "sort -n $tempfile|") || (
	unlink($tempfile) && die("Failed to open pipe to sort"));

$count=0;
while (!eof(PIPE)) {
	$reference = <PIPE>;
	($random, $reference) = split(/ /, $reference);
	print OUTPUT "$reference";

	$count++;
	if ($count % 10000 == 0) {
		syswrite STDOUT, "\r$count references of $refcount written.";
	}
}

close PIPE;
close OUTPUT;

print "\nRandomized reference data outputted to $output\n";
unlink($tempfile);

# Below this line is help and manual page information
__END__

=head1 NAME

randomize_references.pl - Randomize a set of page references

=head1 SYNOPSIS

generate_references.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  --input         Input reference file
  --output        Output reference file

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<--input>

The input page reference data

=item B<-output>

The output file for the randomized page reference data

=back

=head1 DESCRIPTION

B<randomize_references.pl> is used for randomizing a set of page references.
B<generate_references.pl> has a tendancy to be linear in it's output. For
example smooth_sin generates page reference data that graphs to be a sin
wave. Unfortunatly the output references each page in turn a number of times
which doesn't help in determinining if the VM can detect the working set. This
script will randomize the references while still producing the sin wave

It outputs the whole input file with a random number before each reference. It
then uses the sort command to sort by the random number and prints it to
the output file. It is not graceful but it works.

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
