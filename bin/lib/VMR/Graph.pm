#
# Graph.pm
#
# This is a frontend to gnuplot. A number of parameters has to be passed
# o Name of the source data. This is the graph been plotted, at the moment
#   the options are "default" which is a straight xy plot. The second
#   is "PageReference" which is plotting of page referenced Vs pages present
#   and the last is "vmstat" which graphs the output of vmstat in a more
#   readable format.
# o Title of the graph
# o Output PNG filename
# o xrange "from:to" or 0 for no ranging
# o yrange "from:to" or 0 for no ranging
# o Data source 1
# o Data source 1 name
# o Data source 2
# o Data source 2 name
# 

package VMR::Graph;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&gnuplot);

##
#  gnuplot - Call gnuplot to generate a graph
#  @type: Type of source data
#  @title: Title for the graph
#  @xrange: The X range described as from:to
#  @yrange: The Y range described as from:to
#  @output: Output PNG file
#  @ds1: The first data source
#  @ds1name: Name of the data been graphed
#  @ds2: The second data source
#  @ds2name: Name of the second data been graphed
#
#  This opens a pipe to gnuplot and prepares to plot. It understands a number
#  of different data types. They are vmstat, PageReference and default.
#  vmstat takes the output of vmstat as input. PageReference takes two
#  data sources, the page reference cound and page presense. The last
#  default will just plot a normal graph
sub gnuplot {
  my ($type, $title, $xrange, $yrange, $output, $ds1, $ds1name, $ds2, $ds2name) = @_;
  my ($ymin, $ymax, $yhalf);
  my $plotcommand = "none";

  # Parse the yrange, needed for some graphs
  ($ymin, $ymax) = split(/:/, $yrange);
  $yhalf = int $ymax / 2;

  # Call setup functions if they exist
  plotsetup_vmstat($ds1, $output) if $type eq "vmstat";

  # Decide how to plot
  $plotcommand = "plot '$ds1' using \"%lf\" title '$ds1name' with steps\n" if $type eq "Refdata";
  $plotcommand = "plot '$ds1' title '$ds1name' with boxes\n" if $type eq "Boxes";
  $plotcommand = "plot '$ds1' using 1:(\$2==1 ? $yhalf : 0) title '$ds1name' with steps, '$ds2' title '$ds2name' with steps\n" if $type eq "PageReference";
  $plotcommand = "plot '$output-swpddata' title 'swpd' with lines, '$output-freedata' title 'free' with lines, '$output-buffdata' title 'buff' with lines, '$output-cachedata' title 'cache' with lines" if $type eq "vmstat";
  $plotcommand = "plot '$ds1' title '$ds1name' with points\n" 		if $type eq "default";
  die("Unknown gnuplot type '$type'\n") 				if $plotcommand eq "none";
  print ("Plot command: $plotcommand\n");

  # Unlink old output
  unlink("$output.ps");

  # gnuplot instructions
  open (GNUPLOT, "|gnuplot 2> /dev/null") or die ("Could not find gnuplot. Please install\n");
  print GNUPLOT "set title \"$title\"\n";
  print GNUPLOT "set xrange [$xrange]\n";
  print GNUPLOT "set yrange [$yrange]\n";
  print GNUPLOT "set style fill solid 1\n" if $type eq "Boxes";
  print GNUPLOT "set terminal postscript grayscale\n";
  print GNUPLOT "set output '$output.ps'\n";
  print GNUPLOT $plotcommand;

  close GNUPLOT;

  # Convert to PNG if possible
  if ( -e "$output.ps" ) {
    system("convert -rotate 90 $output.ps PNG:$output");

    # Make sure convert succeeded
    if ( ! -e $output ) {
      print "Call to convert (supplied with imagemagick) failed\n";
    }

  } else {

    # Chances are this is harmless as many tests do not run long
    # enough to have graphable output
    print "No output graph generated: xrange probably too small\n";
  }

  # Call cleanup functions if appropraite
  plotfinish_vmstat($output) if $type eq "vmstat";
  
}

##
# plotset_vmstat - Parse vmstat data and print to temp files for plotting
# @ds1: Output from vmstat
# @output: Output graph name
#
# This will parse the data in ds1 and output the 4 pieces of relevant 
# information to temp files. The relevant information is swap usage, free
# memory, buffer usage and cache usage
sub plotsetup_vmstat {
	my ($ds1, $output) = @_;
	my ($d, $swpd, $free, $buff, $cache); # $d = dummy variable
	my $newFormat=0;	# vmstat changed output format at version 3.1 
				# which we have to trap
	my ($line, $lineno);

	# Remove first header line
	$ds1 =~ s/.*\n//;

	# Decide what the format is based on the header
	# 3.1.x has just "r  b   swpd" at the top
	# old format has "r  b  w"
	
	if ($ds1 =~ / r  b  w/) { $newFormat=0; }
	else { $newFormat=1; }

	# Remove the second header line
	$ds1 =~ s/.*\n//;

	# Open temp files
	open(SWPD, ">$output-swpddata");
	open(FREE, ">$output-freedata");
	open(BUFF, ">$output-buffdata");
	open(CACHE, ">$output-cachedata");
	
	# Dump vmstat output
	foreach $line (split(/\n/, $ds1)) {
		$lineno++;
		if ($newFormat == 1) {
		  ($d, $d, $d, $swpd, $free, $buff, $cache, $d, $d, $d, $d, $d, $d, $d, $d, $d, $d) = split(/[ ]+/, $line);
		} else {
		  ($d, $d, $d, $d, $swpd, $free, $buff, $cache, $d, $d, $d, $d, $d, $d, $d, $d, $d) = split(/[ ]+/, $line);
		}
		
		print SWPD  "$lineno $swpd\n";
		print FREE  "$lineno $free\n";
		print BUFF  "$lineno $buff\n";
		print CACHE "$lineno $cache\n";
	}

	# Close temp files
	close SWPD;
	close FREE;
	close BUFF;
	close CACHE;
}

##
# plotfinish_vmstat - Clean up the temp files used for plotting vmstat data
# @output: The graph output name was used to generate temp filenames
#
sub plotfinish_vmstat {
	my ($output) = @_;

	unlink("$output-swpddata");
	unlink("$output-freedata");
	unlink("$output-buffdata");
	unlink("$output-cachedata");
}
