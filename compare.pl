use strict;
use warnings;
use feature 'say';
use Data::Dumper;

open my $ods,'<',$ARGV[0];
open my $dls,'<',$ARGV[1];
my %dls;
while (<$dls>) {
	s/[\r\n]//g;
	my @row = split "\t", $_;
	my $id = $row[0];
	for my $sym (split /; /, $row[1]) {
		my $match = ds($sym);
		$dls{$match}{dls_id} = $id;
		$dls{$match}{og_sym} = $sym;
	}
}
my %ods;
open my $out1,'>','in_ods.tsv';
while (<$ods>) {
	s/[\r\n]//g;
	my @row = split ',', $_;
	my $sym = $row[0];
	$sym =~ s/"//g;
	my $match = ds($sym);
	$ods{$match} = 1;
	if ($dls{$match}) {
		say $out1 join "\t", $dls{$match}{dls_id}, $sym, 'IN DLS';
	} else {
		say $out1 join "\t", '', $sym, 'NOT IN DLS';
	}
}
open my $out2,'>','in_dls.tsv';
for my $match (keys %dls) {
	if ($ods{$match}) {
		say $out2 join "\t", $dls{$match}{dls_id}, $dls{$match}{og_sym}, 'IN ODS';
	} else {
		say $out2 join "\t", $dls{$match}{dls_id}, $dls{$match}{og_sym}, 'NOT IN ODS';
	}
}

sub ds {
	my $sym = shift;
	$sym = lc $sym;
	$sym =~ s/ //g;
	return $sym;
}