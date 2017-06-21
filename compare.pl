use strict;
use warnings;
use feature 'say';
use Data::Dumper;

open my $ods,'<',$ARGV[0];
open my $esc,'<',$ARGV[1];
my %esc;
while (<$esc>) {
	s/[\r\n]//g;
	my @row = split "\t", $_;
	$esc{$_} = $row[0] for split /; /, $row[1];
}
my %ods;
open my $out1,'>','in_ods.tsv';
while (<$ods>) {
	s/[\r\n]//g;
	my @row = split ',', $_;
	my $sym = $row[0];
	$sym =~ s/"//g;
	$ods{$sym} = 1;
	#print @row if $sym eq 'E/ESCWA/ED/2002/1';
	say $sym;
	if ($esc{$sym}) {
		say $out1 join "\t", $esc{$sym}, $sym, 'IN DLS';
	} else {
		say $out1 join "\t", '', $sym, 'NOT IN DLS';
	}
}
open my $out2,'>','in_dls.tsv';
for (keys %esc) {
	if (! $ods{$_}) {
		say $out2 join "\t", $esc{$_}, $_, 'NOT IN ODS';
	} else {
		say $out2 join "\t", $esc{$_}, $_, 'IN ODS';
	}
}

