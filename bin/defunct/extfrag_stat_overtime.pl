#!/usr/bin/perl
#
# extfrag_stat_overtime
#
# Records what the external fragmentation over time is and generates a report.
# This is useful to see what the trends are over time

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use VMR::File;
use VMR::Report;
use File::Basename;
use Term::ReadKey;
use strict;

# Option variables
my $man  =0;
my $help =0;
my $opt_delay = 1;
my $opt_output = "./external_fragmentation_overtime";
my $opt_zone = 'Normal';
my $opt_node = 0;
my $opt_orders = '0,1,2,3,4,5,6,7,8,9,10';
my $opt_replot = 0;
my $opt_verbose = 0;

# extfrag_output variables
my $extfrag_output;		# extfrag_output entry read into memory

# Output related

# Time related
my $starttime;
my $duration;

# Get options
GetOptions(
	'help|h'    => \$help, 
	'man'       => \$man,
	'verbose'   => \$opt_verbose,
	'delay'     => \$opt_delay,
	'output=s'  => \$opt_output,
	'node=s'    => \$opt_node,
	'zone=s'    => \$opt_zone,
	'orders=s'  => \$opt_orders,
	'replot'    => \$opt_replot,
	'delay|n'   => \$opt_delay);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
$opt_verbose && setVerbose();

# Print about what is going to happen
print "Graphing fragmentation for orders $opt_orders\n";
print "Checking fragmentation every $opt_delay second(s)\n";
print "Checking fragmentation in $opt_zone zone\n";
print "Hit q to stop graphing\n";
ReadMode 4;
my $key="a";
my $count=0;
my $no_orders=0;

if ( !$opt_replot) {
  open (FRAGPLOT, ">$opt_output-frag.plot") || die ("Failed to open $opt_output-frag.plot");
  open (FREEPLOT, ">$opt_output-free.plot") || die ("Failed to open $opt_output-free.plot");
}

# Print fragmentation
while (!$opt_replot && not defined ($key = ReadKey(-1)) && ($key eq "q" || $key eq "Q")) {

  open (EXTFRAG, "extfrag_stat.pl|") || die ("Failed to run extfrag_stat.pl");
  while (!eof(EXTFRAG)) {
    my $line = <EXTFRAG>;

    # process extfrag_output entry
    my @fraginfo = split(/\s+/, $line);
    my $max_order = $#fraginfo - 4;
    if ($fraginfo[0] ne "Node") { next; }
    if ($fraginfo[1] ne "$opt_node,") { next; }
    if ($fraginfo[2] ne $opt_zone) { next; }

    # Get the free pages information
    $line = <EXTFRAG>;
    my @freeinfo = split (/\s+/, $line);
    my $freepages = $freeinfo[4];
    $freepages =~ s/\)//;

    syswrite STDOUT, ".";

    my $order;
    print FRAGPLOT "$count ";
    print FREEPLOT "$count $freepages   ";
    $no_orders=0;
    foreach $order (split /,/, $opt_orders) {
      print FRAGPLOT $fraginfo[4+$order] . " ";
      print FREEPLOT (2**$order) * $freeinfo[4+$order] . " ";
      $no_orders++;
    }
    print FRAGPLOT "\n";
    print FREEPLOT "\n";
  }

  sleep($opt_delay);
  $count++;
  close EXTFRAG;
}      
ReadMode 0;
close FRAGPLOT;
close FREEPLOT;

print "\nplotting fragmentation graph\n";
my $plotcommand = "plot ";
my @orders = split /,/, $opt_orders;
for (my $i=2; $i<=$#orders+1 ; $i++) {
  if ($i != 2) { $plotcommand .= ", "; }
  $plotcommand .= "'$opt_output-frag.plot' using 1:$i with lines title 'order-" . $orders[$i-2] . "'"
}
print "DEBUG: $plotcommand\n";
print "DEBUG: $opt_orders\n";
open (gnuplot, "|gnuplot") or die ("could not find gnuplot");
print gnuplot "set yrange [0:100]\n";
print gnuplot "set terminal postscript color\n";
print gnuplot "set output '$opt_output-frag.ps'\n";
print gnuplot "$plotcommand\n";
close gnuplot;

print "plotting free graph\n";
my $plotcommand = "plot '$opt_output-free.plot' using 1:2 with lines title 'total free'";
my @orders = split /,/, $opt_orders;
for (my $i=3; $i<=$no_orders+2 ; $i++) {
  $plotcommand .= ",'$opt_output-free.plot' using 1:$i with lines title 'order-" . $orders[$i-2] . "'"
}
open (gnuplot, "|gnuplot") or die ("could not find gnuplot");
print gnuplot "set terminal postscript color\n";
print gnuplot "set output '$opt_output-free.ps'\n";
print gnuplot "$plotcommand\n";
close gnuplot;



      
# Below this line is help and manual page information
__END__

=head1 NAME

extfrag_stat_overtime - Record external fragmentation over time

=head1 SYNOPSIS

extfrag_stat_overtime [options]

 Options:
  --help          Print help messages
  --man           Print man page
  -n, --delay     Record statistics every n seconds
  -o, --output    Prefix the output files with this string
  -n, --node      Node ID to record statistics for
  -z, --zone      Zone to record statistics for
  -o, --order     Comma separated list of orders of interest
  --replot        Just replot the graphs, do not gather new data

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<-n, --delay>

By default, a single report is generated and the program exits. This option
will generate a report every requested number of seconds.

=back

=head1 DESCRIPTION

No detailed description available. Consult the full documentation in the
docs/ directory

=head1 AUTHOR

Written by Mel Gorman (mel@csn.ul.ie)

=head1 REPORTING BUGS

Report bugs to the author

=cut
