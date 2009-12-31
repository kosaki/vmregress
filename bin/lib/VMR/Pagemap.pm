#
# Pagemap.pm
#
# This perl pack provides page map decoding routines. VMR Regress tests
# that affect memory regions sometimes dump an ecoded map of the memory
# space. This module will decode it
#
#
package VMR::Pagemap;
require Exporter;
use vars qw(@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&decodemap &findmap &stripmap);

##
# decodemap - Decode the map provided by the pagemap module
# @map: String provided by pagemap
# @mark: What to print out for page presense
#
# This will take the encoded string from the proc entry and print out a set
# of lines, each containing the page offset and if the page is present or not.
# If present, $mark is printed, otherwise 0.
sub decodemap {
	my ($map,$mark) = @_;	# Map passed in
	my $decode="";	# Decoded string
	my $pagemap;	# Individual page
	my $index=0;	# Index within map
	my $bitidx=0;	# Bit index
	my $bit;	# A bit

	# Set mark, mark is what decodemap will print out to denote
	# a present page
	if ($mark eq "") { $mark = 1; }

        $pagemap = substr $map, $index, 1;
        do {    
                # Unpack pagemap to be a binary string. In this unpacking
                # the right most bit of the string is the 0th page so we
                # read from the end of the string to the beginning. 
                # Remember only the right 4 bits are page information

                $pagemap = unpack "B8", $pagemap;

                # Print out pages
                for ($bitidx=3; $bitidx >= 0; $bitidx--) {
			$bit = substr $pagemap, 4+$bitidx, 1;
                        $decode .= $index*4 + (3-$bitidx);
			if ($bit) { $decode .= " $mark\n"; }
			else      { $decode .= " 0\n"; }
                }

                # Read next 4 pages
                $index++;
                $pagemap = substr $map, $index, 1;

        } while ($pagemap ne "\n" && $pagemap ne "" );

	# Return decoded string
	return $decode;
}

##
# findmap - Find a map belonging to a particular address and decode it
# @proc: The full output from the proc entry
# @addr: The address of interest
# @mark: Used by decodemap
#
# If no addr is provided, the first map occured is decoded and returned
# to the caller. It returns in order
#
# $range: The address range of the map decoded
# $decode: A line seperated file showing pages and if it is present
# $present: The number of present pages
# $total: The total number of pages

sub findmap {
	# Remove arguements
	my ($proc, $addr, $mark) = @_;
	my $line;		# Line from the proc entry

	# Address space information
	my $range;
	my ($start, $end);	# start and end of range
	my ($istart, $iend, $iaddr); # Converted hex addresses

	my $decode;		# Decoded map

	my $found=0;		# 0 normal
				# 1 found map
				# 2 end map
				
	my $present;		# Number of present pages
	my $total;		# Total number of pages
	my $dummy;
	
	# Check addr and convert to hex string if necessary
	if ($addr != 0) {
	  if ($addr =~ /0x/) { $iaddr = int $addr; }
	  else { $iaddr = $addr; }
	}

	# Read each line from the proc entry
	foreach $line (split ("\n", $proc)) {
		if ($found == 2) {
			($dummy, 
			$dummy, 
			$dummy, 
			$dummy, 
			$present, 
			$dummy, 
			$dummy, 
			$total, 
			$dummy) = split(/ /, $line);
			return ($range, $decode, $present, $total);
		}
			
		# If the map was found, decode it
		if ($found == 1) {
			$decode = decodemap($line, $mark);
			$found=2;
		}

		# Is this the beginning of a map
		if ($line =~ /^BEGIN PAGE MAP/) {
			$range = substr($line, 15);

			($start, $dummy, $end) = split(/ /, $range);
			$istart = int $start;
			$iend   = int $end;

			# See if this address is in the requested range
			# addr == 0 => print first map
			if ($addr == 0 || ($iaddr >= $istart && $iaddr < $iend)) { 
				$found=1; 
			}

		}
	}

	print "Warning: Map address $addr not found\n";
	return ("", "", 0, 0);
}

##
# stripmap - Removes the pagemap data from a proc entry
# @proc: output from proc
sub stripmap {
	my ($proc) = @_;

	$proc = substr $proc, 0, (index $proc, "BEGIN PAGE MAP");
	return $proc;
}

1;
