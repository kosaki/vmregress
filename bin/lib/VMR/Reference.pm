#
# Reference.pm
#
# This module is responsible for producing page reference information. The
# caller names the reference pattern they are looking for and they are
# returned an array. The module doesn't determine whether the accesses are
# read or write. That is for the caller to decide.

package VMR::Reference;
require Exporter;
use vars qw (@ISA @EXPORT);
use strict;

@ISA    = qw(Exporter);
@EXPORT = qw(&generate_references &lognormal &zipf05);

use constant PI => 3.14159265358979;

##
# generate_references - Select which worker function to provide page references
# @pattern: String denoting which reference pattern to use
# @references: Number of references to generate
# @range: Number of pages that can be addressed
# @burst: Boolean to denote if the pattern should block read pages
#
# Three patterns can be generated. linear will reference each page in the address
# space in order until the number of required references is generated. 
# smooth_sin will generate a set of page references that looks like a sin
# curve when plotted. Random will touch all pages in the range once in a linear
# pattern before referencing the rest in a random fashion
#
sub generate_references {
	my ($pattern, $references, $range, $burst, $output) = @_;

	# Sanity check
	die("Bogus page range $range") if $range <= 0;

	return linear    ($references, $range, $burst, $output) if $pattern eq "linear";
	return smooth_sin($references, $range, $burst, $output) if $pattern eq "smooth_sin";
	return random    ($references, $range, $burst, $output) if $pattern eq "random";
	return zipf1    ($references, $range, $burst, $output) if $pattern eq "zipf1";
	return zipf05F    ($references, $range, $burst, $output) if $pattern eq "zipf05";
	return lognormalF ($references, $range, $burst, $output) if $pattern eq "lognormal";

	die("Do not recognise reference pattern '$pattern'");
}

# Generate a linear page reference pattern. Will read the range from 
# beginning to end until the number of references is generated. This ignores
# the burst parameter because the pattern is already linear.
sub linear {
	my ($references, $range, $burst, $output) = @_;
	my $pageidx=0;	# Page index to reference
	my $refidx=0;	

	open (REFDATA, ">$output") || die ("Could not open refdata file $output");
	print REFDATA "$range $references\n";

	for ($refidx=0; $refidx < $references; $refidx++) {
		print REFDATA "$pageidx\n";
		if ($refidx % 10000 == 0) {syswrite STDOUT, "\rDumped $refidx/$references references"; }
		$pageidx = ($pageidx + 1) % $range;
	}
	syswrite STDOUT, "\rDumped $references/$references references\n";
	close REFDATA;
	return 1;
}

# Generate a smooth reference pattern that looks like part of
# a sin wave. It uses the values of sin from 0 to 5 to generate
# the pattern. sin returns a value between 0 and 1. The integer
# value of that result * 10 is how many times a page is referenced
#
sub smooth_sin {
	my ($references, $range, $burst, $output) = @_;
	my @sin_vals;
	my $linear_fill=0;
	my $index=0;
	my $count=0;
	my $step=1;
	my $error;

	# Sin related step
	my $sin_val;		# Value returned by sin()

	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $references\n";
	
	# Calculate sin for the range. Get the refences within 10% of
	# what was requested
	while ($count <= $references / 2 ) {
		$count=0;
		for ($index=0; $index<$range; $index++) {
			$sin_vals[$index] = (1*$step) + (sin($index / ($range/(PI*6/2) )) * $step);
			$count += int $sin_vals[$index];
		}
		$step *= 2;

	}

	# Linear fill the rest
	$index=0;
	while ($count < $references) {
		$sin_vals[$index] += 1;
		$count++;
		$index = ($index + 1) % $range;
	}

	# Dump references to disk
	$count=0;
	for ($index=0; $index<$range; $index++) {
		$sin_vals[$index] = int $sin_vals[$index];

		while ($sin_vals[$index]-- > 0) {
			print REFDATA "$index\n";
			$count++;
			if ($count % 10000 == 0) {syswrite STDOUT, "\rDumped $count/$references references"; }
		}
	}

	print "\rDumped $references/$references references\n";
	close REFDATA;

	return 1;
	
}
sub zipf {
	my ($references, $range, $burst, $output) = @_;
	my $index;
	my $count=0;
	my $refs;
	my $exp_refs=$range * int(log($range) + 1.5);

	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $exp_refs\n";

	
	while ($count < $exp_refs) {
		$index = int ( $range / (rand($range) + 1));
		print REFDATA "$index\n";
		if (++$count % 10000 == 0)
			 {syswrite STDOUT, "\rDumped $count/$exp_refs references"; }
	}
	close REFDATA;
	return 1;
}
sub zipf1 {
	my ($references, $range, $burst, $output) = @_;
	my $index;
	my $refs;
	my $exp_refs;
	my $ln_rng;

	$ln_rng = log($range);
	$exp_refs=$range * int(log($range) + 1) * 2;
	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $exp_refs\n";
	for ($refs=1; $refs<$exp_refs; $refs++){
		$index = 0;
		while ($index <= 0 || $index > $range ) {
			$index = int(exp(rand($ln_rng)));
		}
		print REFDATA "$index\n";
		if ($refs % 10000 == 0){
		    syswrite STDOUT, "\rDumped $refs of $exp_refs references";
		}
	}
	close REFDATA;
	return 1;
}
sub zipf05 {
	my ($range) = @_;
	my $index;
	my $r;

	while ($index <= 0 || $index > $range) {
		$r = rand;
		$index = int ($range * $r * $r + 0.5);
	}
	return $index;
}
sub zipf05F {
	my ($references, $range, $burst, $output) = @_;
	my $index;
	my $refs;
	my $exp_refs;

	$exp_refs= 3 * $range;
	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $exp_refs\n";

	for ($refs=1; $refs<$exp_refs; $refs++){
		$index = zipf05($range);
		print REFDATA "$index\n";
		if ($refs % 10000 == 0){
		    syswrite STDOUT, "\rDumped $refs of $exp_refs references";
		}
	}
	close REFDATA;
	print "\nGenerated $refs references\n";
	return 1;
}
sub lognormal {
	my ($range) = @_;
	my $index=0;
	my $i;
	my $sum;
	my $sigma;
	use constant mu => 8;

	$sigma = log($range + exp(mu)) - mu + 1;
	while ($index <= 0 || $index >= $range) {
		$sum = -6;
		for ($i=1; $i <= 12; $i++) { $sum+= rand };
		$sum = abs($sum);
		$index = int(exp(mu + $sigma * $sum) - exp(mu) + 0.5);
	}
	return $index;
}
sub lognormalF {
	my ($references, $range, $burst, $output) = @_;
	my $index;
	my $count;
	my $exp_refs;

	srand(42);
	$exp_refs=$range * (int(log($range)));
	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $exp_refs\n";

	while ($count < $exp_refs) {
		$index = lognormal($range);
		print REFDATA "$index\n";
		if (++$count % 10000 == 0)
		    {syswrite STDOUT, "\rDumped $count/$exp_refs references."; }
	}
	close REFDATA;
	print "\nGenerated $count references\n";
	return 1;
}

##
#  random - Generate a set of page references that are purely random

sub random {
	my ($references, $range, $burst, $output) = @_;
	my $index;
	my $ref;
	my $count;

	open REFDATA, ">$output" || die("Failed to open refdata $output\n");
	print REFDATA "$range $references\n";

	# Linear reference once so all pages are hit at least once
	$index=0;
	while ($count < $references && $index < $range) {
		print REFDATA "$index\n";
		$count++;
		$index++;
		if ($count % 10000 == 0) {syswrite STDOUT, "\rDumped $count/$references references"; }
	}

	# Dump random information
	while ($count < $references) {
		$ref = int rand $range;
		print REFDATA "$ref\n";
		$count++;
		if ($count % 10000 == 0) {syswrite STDOUT, "\rDumped $count/$references references"; }
	}

	close REFDATA;
	print "\nGenerated $count references\n";

	return 1;
}
		



