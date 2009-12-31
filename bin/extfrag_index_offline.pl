#!/usr/bin/perl
# This script generates a graph showing the fragmentation index at each time an
# allocation failed.
#
use FindBin qw($Bin);
use lib "$Bin/lib";

use Getopt::Long;
use VMR::Graph;
use VMR::Report;
use VMR::File;
use strict;

# Option variables
my $opt_inputfiles = "--##--";
my $opt_inputNames;
my $opt_help = 0;
my $opt_verbose = 0;
my $opt_zone = "Normal";
my $opt_node = "0";
my $opt_order = 10;
my $opt_yrange = "";
my $opt_xrange = "";
my $opt_title = "";
my $opt_output = "default.ps";
my $opt_xlabel = "Allocation Attempt";
my $opt_ylabel = "Fragmentation Index";
my $opt_includefail = 0;

# Get options
GetOptions(
        'help|h'        => \$opt_help,
        'input|i=s'        => \$opt_inputfiles,
	'inputNames|j=s'   => \$opt_inputNames,
        'zone|z=s'         => \$opt_zone,
	'node=s'	   => \$opt_node,
	'order|s=s'	   => \$opt_order,
	'yrange=s'	   => \$opt_yrange,
	'xrange=s'	   => \$opt_xrange,
	'title|t=s'        => \$opt_title,
        'verbose|v'        => \$opt_verbose,
	'fail|f'	   => \$opt_includefail,
	'xlabel|x=s'       => \$opt_xlabel,
	'ylabel|y=s'	   => \$opt_ylabel,
	'output|o=s'	   => \$opt_output
        );
if ($opt_verbose) {
  setVerbose;
}

my $outputFileCount=0;
my @outputFilenames;
my @failCount;
my $allocationAttempt = 0;

# Process each input file
my $inputfile;
foreach $inputfile (split /,/, $opt_inputfiles) {
  # Make sure the input file looks ok
  if ($inputfile eq "" || ! -e $inputfile) {
    print("File $inputfile does not exist or was not specified\n");
    next;
  }

  # Open the file
  printVerbose("Processing $inputfile\n");
  if (!open(INPUT, $inputfile)) {
    print("Failed to open $inputfile for reading\n");
    next;
  }

  # Open the output file
  my $OUTPUT = mktempname;
  if (!open(OUTPUT, ">$OUTPUT")) {
    print("Failed to open $OUTPUT for writing\n");
    close INPUT;
    next;
  }
  $outputFilenames[$outputFileCount] = $OUTPUT;
  $outputFileCount++;

  # Process the file
  my $line;
  my $inFailure=0;
  my $SKIP_NEXT_READ = 0;
  $allocationAttempt = 0;
  while (!eof(INPUT)) {

    # Check if this is a failed allocation attempt
    if ($line =~ /^Buddyinfo ([a-z]+) attempt/) {
      my $status = $1;
      $allocationAttempt++;
      if ($status eq "failed") {
        $failCount[$outputFileCount-1]++;
        $inFailure = 1;
      } else {
        $inFailure = 0;
      }
    }

    # If this is a normal line, process it if this is a failed allocation and
    # we are looking at the correct zone type
    $SKIP_NEXT_READ=0;
    if ($inFailure && $line =~ /^Node [0-9], zone\s*([a-zA-Z]*)/ &&
    							( $opt_zone eq $1 || $opt_zone eq "All")) {
      printVerbose("Processing failure at attempt $allocationAttempt\n");

      my $totalFree = 0;
      my $totalBlocks = 0;
      my $sizeRequested = 2 ** $opt_order;

      my @info = split(/\s+/, $line);
      my $i;
      $SKIP_NEXT_READ = 0;
      if ($opt_zone ne "All") {
        for (my $i=4; $i <= $#info; $i++) {
          $totalBlocks += $info[$i];
	  $totalFree += $info[$i] * (2 ** ($i-4));
        }
      } else {
        while ($line =~ /^Node/) {
          for (my $i=4; $i <= $#info; $i++) {
            $totalBlocks += $info[$i];
	    $totalFree += $info[$i] * (2 ** ($i-4));
          }
	  $line = <INPUT>;
	  @info = split(/\s+/, $line);
	}
	$SKIP_NEXT_READ = 1;
     }
	



      # Output the fragmentation index
      my $fragindex = 1 - (($totalFree / $sizeRequested) / $totalBlocks);
      print OUTPUT "$allocationAttempt $fragindex\n";

    }

    if ($SKIP_NEXT_READ == 0) {
      $line = <INPUT>
    }

  }

  # Cleanup
  close INPUT;
  close OUTPUT;
}

# Set xrange
if ($opt_xrange eq "") {
  $opt_xrange="0:$allocationAttempt";
}

# Setup gnuplot
my $graphs;
my @inputNames = split /,/, $opt_inputNames;
printVerbose("Processing $outputFileCount files for plotting\n");
for (my $i=0; $i < $outputFileCount; $i++) {
  if ($i > 0) {
    $graphs .= ",";
  }
  $graphs .= "'$outputFilenames[$i]'";
  if ($inputNames[$i] ne "" ) {
    if ($opt_includefail) {
      $inputNames[$i] .= " (Failures: $failCount[$i])"
    }
    $graphs .= " title \"$inputNames[$i]\"";
  }
}

# Call gnuplot
printVerbose("Calling gnuplot: plot $graphs\n");
open (GNUPLOT, "|gnuplot") or die ("Could not find gnuplot. Please install\n");
print GNUPLOT "set yrange [$opt_yrange]\n" if $opt_yrange ne "";
print GNUPLOT "set xrange [$opt_xrange]\n" if $opt_xrange ne "";
print GNUPLOT "set title '$opt_title'\n" if $opt_title ne "";
print GNUPLOT "set xlabel '$opt_xlabel'\n" if $opt_xlabel ne "";
print GNUPLOT "set ylabel '$opt_ylabel'\n" if $opt_ylabel ne "";
print GNUPLOT "set terminal postscript\n";
print GNUPLOT "set output '$opt_output'\n";
print GNUPLOT "plot $graphs\n";
close GNUPLOT;

# Cleanup temp files
for (my $i=0; $i < $outputFileCount; $i++) {
  printVerbose("Unlinking $outputFilenames[$i]\n");
  unlink $outputFilenames[$i];
}




