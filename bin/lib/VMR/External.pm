#
# External.pm
#
# This module is concern with handling IO with external programs such as
# vmstat, oprofpp and any other program the user wishs to capture data
# from. It presumes that only one instance of each program is opened. If
# that presumption changes, the caller will have to start tracking the
# file handles returned from openpipe themselves as @HANDLES will be
# useless

package VMR::External;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&openexternal &readexternal &closeexternal);

# Hash table of file handles
my %HANDLES;
my $handle_count=0;

##
# openextrnal - Opens a pipe to an external program
# @program: The name of the program to exec
# @arguments: Arguements to pass to the program
#
# This function will exec an external program and record a handle to it that 
# may be read later. Because of the weird way PERL handles file handle names,
# the function is limited to execing 3 programs. If more are required, add
# new pipe names below

sub openexternal {
	my ($program, $arguments) = @_;
	my $handle;
	
	if ($handle_count >= 3) {
		print("WARNING: Unable to exec any more programs. Check External.pm\n");
		return -1;
	}

	$HANDLES{"$program"} = -1;
	if ($handle_count == 0) {open(PIPE0, "$program $arguments|") && ( $HANDLES{"$program"} = 'PIPE0'); }
	if ($handle_count == 1) {open(PIPE1, "$program $arguments|") && ( $HANDLES{"$program"} = 'PIPE1'); }
	if ($handle_count == 2) {open(PIPE2, "$program $arguments|") && ( $HANDLES{"$program"} = 'PIPE2'); }

	if ($HANDLES{"$program"} == -1) {
		print "Failed to exec $program\n";
		return -1;
	}

	$handle_count++;
	return $HANDLES{"$program"};
}

##
# readexternal - Read from an external pipe
# @program - The program name to read
#
# This will read a pipe to a program that was execed using openexternal
 
sub readexternal {
	my ($program, $handle) = @_;
	my $readdata = "";

	$handle = $HANDLES{"$program"};
	$readdata = <$handle>;

	return $readdata;
}

##
# closeexternal - Close a pipe to an external program
# @program - Name of the program to close

sub closeexternal {
	my ($program, $handle) = @_;

	close $HANDLES{"$program"};
}

1;
