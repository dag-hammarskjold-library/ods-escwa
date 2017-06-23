use strict;
use warnings;
use feature 'say';
use Data::Dumper;

use constant LANG => {
	1 => 'EN',
	2 => 'FR',
	3 => 'AR',
	4 => 'ZH',
	5 => 'RU',
	6 => 'ES',
	7 => 'DE'
};

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
		$dls{$match}{files} = [(split /; /, $row[2])] if $row[2];
	}
}
my %ods;
open my $out1,'>','in_ods.tsv';
while (<$ods>) {
	s/[\r\n]//g;
	my @row = split ',', $_;
	$_ =~ s/"//g for @row;
	my $sym = $row[0];
	my $match = ds($sym);
	$ods{$match} = 1;
	if ($dls{$match}) {
		print $out1 join "\t", $sym, $dls{$match}{dls_id};
		my $dls_files = $dls{$match}{files};
		my %dls_langs;
		$dls_langs{substr($_,-6,2)} = 1 for grep {$_ =~ /\w/} @$dls_files;
		my %ods_langs;
		for (1..7) {
			$ods_langs{LANG->{$_}} = 1 if $row[$_];
		}
		my @missing = grep {! $dls_langs{$_}} keys %ods_langs;
		$missing[0] ||= 'NONE';
		say $out1 "\t".join "\t", 'missing files:', @missing;
	} else {
		say $out1 join "\t", $sym, 'NOT IN DLS';
	}
}
open my $out2,'>','in_dls.tsv';
for my $match (keys %dls) {
	if ($ods{$match}) {
		say $out2 join "\t", $dls{$match}{og_sym}, $dls{$match}{dls_id}, 'IN ODS';
	} else {
		say $out2 join "\t", $dls{$match}{og_sym}, $dls{$match}{dls_id}, 'NOT IN ODS';
	}
}

sub ds {
	my $sym = shift;
	$sym = lc $sym;
	$sym =~ s/ //g;
	return $sym;
}