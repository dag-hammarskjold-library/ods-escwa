use strict;
use warnings;
use feature 'say';

open my $ods,'<',$ARGV[0];
open my $esc,'<',$ARGV[1];
my %esc;
while (<$esc>) {
	chomp;
	my @row = split "\t", $_;
	$esc{$_} = $row[0] for split /; /, $row[1];
}
while (<$ods>) {
	chomp;
	my $sym = $_;
	if ($esc{$sym}) {
		say join "\t", $esc{$sym}, $sym, 'IN DLS';
	} else {
		say join "\t", '', $sym, 'NOT IN DLS';
	}
}

