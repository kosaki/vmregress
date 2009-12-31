#
# Time.pm
#
# This module is concerned with timing related information

package VMR::Time;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&gettime &elaspedtime &difftime);

use Time::HiRes qw( usleep ualarm gettimeofday tv_interval );

##
# gettime - Return a token representing the current time
#
# The token should be passed to difftime directly to get the elasped time
# in microseconds
sub gettime {
	my ($sec, $mic);
	($sec, $mic) = gettimeofday;
	return "$sec|$mic";
}

##
#  elaspedtime - Return the elasped time since the token was taken
#
#  returns the difference and a token representing the current time
sub elaspedtime {
	my $old = $_[0];	# Time returned by gettime
	my $current;
	my $elasped;		# Elapsed time
	my ($sec,  $mic);
	my ($osec, $omic);

	# Get current time
	$current = gettime;

	# Get difference
	$elasped = difftime($old, $current, 0);

	# Get new time token to get a fine as time as possible
	($sec, $mic) = gettimeofday;

	return ($elasped, "$sec|$mic");
}

##
#  difftime - Return the difference between two time tokens in milliseconds
#  @old: The old time token
#  @new: The new time token
#  @return_milliseconds: Set to 1 if the difference should be in milliseconds
#
#  returns the difference and a token representing the current time
sub difftime {
	my ($old, $new, $return_milliseconds) = @_;
	my $difference;
	my ($sec,  $mic);
	my ($osec, $omic);

	# Decode tokens
	($osec, $omic) = split(/\|/, $old);
	($sec, $mic)   = split(/\|/, $new);

	if ($return_milliseconds == 1) {
		# Get difference in time in milliseconds
		$difference = (1000 * ($sec - $osec)) + (($mic - $omic)/1000);
	} else {
		# Get difference in time in microseconds
		$difference = (1000000 * ($sec - $osec)) + $mic - $omic;
	}

	return $difference;
}

1;
