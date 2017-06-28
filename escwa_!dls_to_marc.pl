#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';
use lib 'c:\drive\modules';

package IN::DLS;
use API;

has 'file', is => 'rw', param => 1;

has 'data', is => 'ro', default => sub {
	my $self = shift;
	open my $fh,'<',$self->file;
	my %data;
	while (<$fh>) {
		chomp;
		my @row = split "\t";
		next if $row[1] eq 'NOT IN DLS';
		$data{$row[0]} = 1;
	}
	return \%data;
};

package TCODES;
use API;

has 'file', is => 'rw', param => 1;

has 'data', is => 'ro', default => sub {
	my $self = shift;
	open my $fh,'<',$self->file;
	my %data;
	while (<$fh>) {
		chomp;
		my @row = split "\t";
		$data{$row[0]} = [$row[1],$row[2]]; # tcode, auth, term
	}
	return \%data;
};

package Child;
use API;
use parent -norequire, 'Class';

package main;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use Getopt::Std;
use MARC::Set2;

RUN: {
	MAIN(options());
}

sub options {
	my $opts = {
		'h' => 'help',
		'3:' => 's3 file (path)',
		'o:' => 'ods file'
	};
	getopts ((join '',keys %$opts), \my %opts);
	if ($opts{h}) {
		say "$_ - $opts->{$_}" for keys %$opts;
		exit; 
	}
	return \%opts;
}

sub MAIN {
	my $opts = shift;
	
	my %take = (
		ALLDS => \&_191,
		PubDate => \&_269,
		Subject => \&_650,
		Title => \&_245,
		UnbisTitle => \&_246,
		TitleA => \&_246,
		TitleC => \&_246,
		TitleE => \&_246,
		TitleF => \&_246,
		TitleR => \&_246,
		TitleS => \&_246,
	);
	
	my $in_dls = IN::DLS->new(file => 'in_ods.tsv')->data;
	$opts->{tcodes} = TCODES->new(file => 'tcodes.tsv')->data;

	say '<collection>';
	$/ = "\x{C}";
	open my $ods,'<',$opts->{o};
	while (<$ods>) {
		chomp;
		s/[\x{0}\x{1B}]//g;
		my $record = MARC::Record->new;
		my @fields = split "\n", $_;
		for (@fields) {
			my ($key,$val) = ($1,$2) if $_ =~ /(.*?): *(.*)/;
			if ($key && $val && grep {$_ eq $key} keys %take) {
				$take{$key}->($record,$val,$opts);
			}
		}
		my $symbol = $record->get_field_sub('191','a');
		next if $in_dls->{$symbol};
		print $record->to_xml;
	}
	say '</collection>';
}

sub _191 {
	my ($record,$val) = @_;
	for (split /,/, $val) {
		my $field = MARC::Field->new(tag => '191');
		$field->set_sub('a',$_);
		$record->add_field($field);
	}
}

sub _245 {
	my ($record,$val) = @_;
	my $field = MARC::Field->new(tag => '245');
	$field->set_sub('a',$val);
	$record->add_field($field);
}

sub _246 {
	my ($record,$val) = @_;
	my $field = MARC::Field->new(tag => '246');
	$field->set_sub('a',$val);
	$record->add_field($field);
}

sub _269 {
	my ($record,$val) = @_;
	my ($day,$mon,$yr) = split /[\/ ]/, $val;
	my $field = MARC::Field->new(tag => '269');
	$field->set_sub('a',"$yr$mon$day");
	$record->add_field($field);
}

sub _650 {
	my ($record,$val,$opts) = @_;
	for my $tcode (split /,/, $val) {
		my $field = MARC::Field->new(tag => '650');
		my ($auth,$term) = map {$opts->{tcodes}->{$tcode}->[$_]} 0,1;
		$auth ||= '?';
		$term ||= $tcode.'?';
		$field->set_sub('a',$term);
		$field->set_sub('0','(DHLAUTH)'.$auth);
		$record->add_field($field);
	}
}

__END__