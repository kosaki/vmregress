#!/usr/bin/perl
#
# extfrag_stat
#
# Prints the current status of external fragmentation of the system

use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use Pod::Usage;
use VMR::File;
use VMR::Report;
use File::Basename;
use strict;

# Option variables
my $man  =0;
my $help =0;
my $opt_delay = -1;
my $opt_verbose = 0;
my $opt_proc = "/proc/buddyinfo";

# Proc variables
my $proc;		# Proc entry read into memory

# Output related

# Time related
my $starttime;
my $duration;

# Get options
GetOptions(
	'help|h'   => \$help, 
	'man'      => \$man,
	'verbose'  => \$opt_verbose,
	'proc|p=s'   => \$opt_proc,
	'delay|n=s'  => \$opt_delay);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
$opt_verbose && setVerbose();

# Print fragmentation
do {
  $proc = readproc($opt_proc);
  printVerbose("DEBUG\n$proc\nDEBUG\n\n");
  my $line;

  # Print header
  printf "%6s %7s %12s (%% Fragmentation Orders 2^0 -> 2^MAX_ORDER)\n", "Node", "Zone", "Pages Free";

  # Process proc entry
  foreach $line (split /\n/, $proc) {
    my @buddyinfo = split(/\s+/, $line);
    my $max_order = $#buddyinfo - 4;
    if ($buddyinfo[0] ne "Node") { next; }
    if ($buddyinfo[4] !~ /\d+/) { next; }

    my $output = sprintf "%4s %1s %8s (Fragment) ", $buddyinfo[0], $buddyinfo[1], $buddyinfo[3];

    # Print fragmentation at each order
    my ($sumhigh, $total, $frag);
    my $first=1;

    for (my $j=0; $j<=$max_order; $j++) {
      $sumhigh=0;
      $total=0;
      $frag=0;
      for (my $i=$j; $i<=$max_order; $i++) {
        $sumhigh += (2**$i) * $buddyinfo[4+$i];
      }
      $total = $sumhigh;

      for (my $i=0; $i<$j; $i++) {
        $total += (2**$i) * $buddyinfo[4+$i];
      }

      printVerbose("DEBUG: $buddyinfo[3] $j: $total $sumhigh\n");
      if ($first) { 
        $first = 0;
      }
      $frag = ($total - $sumhigh) / $total;
      $output .= sprintf "%6.3f ", $frag*100;
    }

    my $freeline = sprintf "      Free pages (%8d)", $total;
    for (my $j=0; $j<=$max_order; $j++) {
        $freeline .= sprintf "%7d", $buddyinfo[4+$j];
    }

    print "$output\n";
    print "$freeline\n";
  }

  if ($opt_delay != -1) { sleep $opt_delay; }
} while ($opt_delay != -1);
        
# Below this line is help and manual page information
__END__

=head1 NAME

extfrag_stat - Measure the extend of external fragmentation in the kernel

=head1 SYNOPSIS

extfrag_stat.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  n, --delay      Print a report every n seconds

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
