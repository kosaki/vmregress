#
# Kernel.pm
#
# This module is concerned with the VM Regress kernel modules. It
# checks for the existance of certain kernel modules. If they are
# not available, it attempts to load them. If it fails, the caller
# is killed

package VMR::Kernel;
require Exporter;
use FindBin qw($Bin);
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&checkmodule &unloadmodules);

# List of kernel modules loaded
my @KERNEL_MODULES;
my $module_count=0;

##
# lookupproc - Look up a proc entry a given module provides
# @name: Name of the module been looked up
sub lookupproc {
	my $name = shift;
	my $line;
	my $found=0;

	open LSMOD, "/sbin/lsmod|" or die("Couldn't exec /sbin/lsmod");
	while (!eof(LSMOD)) {
		$line = <LSMOD>;
		if ($line =~ /^$name/) { $found=1; }
	}
	close LSMOD;

	return $found;

}

##
#  checkmodule - Check if a particular module is loaded. If not, load it
#  @name: Name of the module to check
#  @arguments: Arguements to pass to the module
sub checkmodule {
	my ($name, $arguments) = @_;

	my $loaded = lookupproc($name);

	if ($loaded == 0) {
		# Load it
		print "Loading $name\n";
		system("modprobe $name 2> /dev/null");

		# Remember the module was loaded by us
		$KERNEL_MODULES[$module_count] = $name;
		$module_count++;

		# Check again
		$loaded = lookupproc($name);

		if ($loaded == 0) {
		  open FIND, "find $Bin/.. -name $name.ko|" || die("Failed to exec find to locate kernel modules");
		  my $modulepath;
		  while (!eof(FIND)) {
		    $modulepath = <FIND>;
		  }
		  close FIND;
		  if ($modulepath ne "") {
		    system("insmod $modulepath");
		  }

		}

		$loaded = lookupproc($name);

	}
		
	if ($loaded == 0) { 
		unloadmodules();
		die("Module $name can't be loaded"); 
	}

	return $loaded;
}

##
# unloadmodules - Unloads all modules that was loaded with this session
sub unloadmodules {
	my $mod=0;

	for ($mod=$module_count-1; $mod>=0; $mod--) {
		print "Unloading $KERNEL_MODULES[$mod]\n";
		system("rmmod $KERNEL_MODULES[$mod]");
	}

	return 1;
}

1;
