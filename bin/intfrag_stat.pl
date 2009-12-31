#!/usr/bin/perl
#
# intfrag_stat
#
# Prints the current status of internal fragmentation of the system,
# specifically in the slab allocator

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
my $opt_all = 0;
my $opt_unused = 0;
my $opt_sortcolumn = "Frag";
my $opt_hidefull = 0;

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
	'all|a'    => \$opt_all,
	'unused|u' => \$opt_unused,
	'f|hidefull'   => \$opt_hidefull,
	'sort|s=s' => \$opt_sortcolumn,
	'delay|n'  => \$opt_delay);

# Print usage if requested
pod2usage(-exitstatus => 0, -verbose => 0) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;
$opt_verbose && setVerbose();

# Function to sort output columns
sub OutputSort {
  my (@lElements, @rElements);
  @lElements = split(/\s+/, $a);
  @rElements = split(/\s+/, $b);

  my $index=-1;
  if ($opt_sortcolumn =~ /Frag/i) 	 { $index = 1; }
  if ($opt_sortcolumn =~ /Inactive/i) 	 { $index = 2; }
  if ($opt_sortcolumn =~ /ObjSize/i) 	 { $index = 3; }
  if ($opt_sortcolumn =~ /NumObjects/i)  { $index = 4; }
  if ($opt_sortcolumn =~ /TotalSize/i)   { $index = 5; }
  if ($opt_sortcolumn =~ /TotalPageSize/i) { $index=6; }
  if ($opt_sortcolumn =~ /WastedBytes/i) { $index = 7; }

  $index == -1 && die("Unknown sort column '$opt_sortcolumn' specified");

  return $lElements[$index] <=> $rElements[$index];
}

# Print header if necessary
if ($opt_delay != -1) {
  printf("%7s %10s %10s %10s %10s %%\n", "Inactive", "TotalSize", "TotalPageSize", "WastedBytes", "Frag %");
}  

# Print fragmentation
do {
  $proc = readproc("/proc/slabinfo");
  my $line;
  my $total_used=0;
  my $total_unused=0;
  my $total_inactive;
  my $total_wastage;
  my $total_inactivecaches;
  my $total_fullcaches;

  # Process proc entry
  my @output;
  my $count=0;
  foreach $line (split /\n/, $proc) {
    if ($line =~ /.*:.*:.*/ && $line !~ /^\#/) {
      my @elements = split(/\s+/, $line);
      my $cache = $elements[0];
      my $active = $elements[1];
      my $numobjects = $elements[2];
      my $objsize = $elements[3];
      my $inactive = $numobjects - $active;
      my $used_memory = $numobjects * $objsize;
      my $unused_memory = $inactive * $objsize;
      printVerbose("DEBUG: $cache $inactive $active $objsize\n");
      if ($active > $numobjects) { die("active > numobjects, makes no sense\n"); }

      if ($opt_all) { 
      	my $frag;
        if ($used_memory == 0) { $frag = 0; }
        else { $frag = $unused_memory / $used_memory; }
	if ( (!$opt_unused   || $numobjects) &&
	     (!$opt_hidefull || $inactive)) {
          $output[$count] = sprintf "%-25s %6.3f%% %8d %7d %6d %15d %15d %15d\n",
	  						$cache,
							$frag * 100, 
							$inactive,
							$objsize,
							$numobjects,
							$used_memory,
							$used_memory / 4096,
							$unused_memory;
          $count++;
	}
      }

      $total_used += $used_memory;
      $total_unused += $unused_memory;
      $total_inactive += $inactive;
      $total_wastage += $unused_memory;

      if (!$numobjects) { $total_inactivecaches++; }
      if (!$inactive)   { $total_fullcaches++; }
    }

  }

  if ($opt_all) {
    printf "%-25s %7s %8s %7s %6s %15s %15s %15s\n", "Cache name",
    					"Frag %",
					"Inactive",
					"ObjSize",
					"NumObjects",
					"TotalSize",
					"TotalPageSize",
					"WastedBytes";

    my @sortedOutput = sort OutputSort @output;
    print @sortedOutput; 
    print "\n\n";
  }

  if ($opt_delay == -1) {
    print "Total memory used by slab:   $total_used\n";
    print "Total inactive objects:      $total_inactive\n";
    print "Total wasted bytes:          $total_wastage\n";
    print "Total unused caches:         $total_inactivecaches\n";
    print "Total fully utilized caches: $total_fullcaches\n";
    printf "Internal fragmentation:      %6.3f%%\n", $total_unused / $total_used * 100;
  } else {
    printf("%7d %10d %6.4f%%\n", $total_inactive, $total_wastage, $total_unused / $total_used * 100);
  }

  if ($opt_delay != -1) { sleep $opt_delay; }
} while ($opt_delay != -1);
        
# Below this line is help and manual page information
__END__

=head1 NAME

intfrag_stat - Measure the extent of internal fragmentation in the kernel

=head1 SYNOPSIS

intfrag_stat.pl [options]

 Options:
  --help          Print help messages
  --man           Print man page
  -a, --all       Show fragmentation on individual caches, not just the total
  -s, --sort      Sort the "all" output by a column
  -u, --unused    Strip out caches that are not used at all
  -f, --hidefull  Hide fully used caches
  -n, --delay     Print a report every n seconds

=head1 OPTIONS

=over 8

=item B<--help>

Print a help message and exit

=item B<-a, --all>

By default, just the total internal fragmentation for the system is displayed.
This option will print the fragmentation of each individual cache to help 
identify where the problems are

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
