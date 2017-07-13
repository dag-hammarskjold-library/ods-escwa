#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';
use utf8;
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
		$data{$row[0]} = $row[1];
	}
	return \%data;
};

package S3;
use API;

has 'file', is => 'rw', param => 1;

has 'data', is => 'ro', default => sub {
	my $self = shift;
	open my $s3,'<',$self->file;
	my %data;
	while (<$s3>) {
		chomp;
		my @parts = split /\s+/, $_;
		my $key = join ' ', @parts[3..$#parts];
		next unless $key;
		my $id = (split m|/|, $_)[2];
		my $lang = substr $key,-6,2;
		my $sym = substr((split m|/|, $key)[-1], 0, -7);
		$sym =~ tr/_*/\/!/;
		push @{$data{$sym}}, $key;
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
use Encode;
use MARC::Set2;
use URI::Escape;

RUN: {
	MAIN(options());
}

sub options {
	my $opts = {
		'h' => 'help',
		#'3:' => 's3 file (path)',
		#'o:' => 'ods file'
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
		#UnbisTitle => \&_246,
		TitleA => \&_246,
		TitleC => \&_246,
		#TitleE => \&_246,
		TitleF => \&_246,
		TitleR => \&_246,
		TitleS => \&_246,
	);
	
	my $in_dls = IN::DLS->new(file => 'in_ods.tsv')->data;
	my $s3 = S3->new(file => 'escwa_s3.txt')->data;
	$opts->{tcodes} = TCODES->new(file => 'tcodes.tsv')->data;
	
	open my $new_recs,'>:utf8','new.xml';
	open my $update_recs,'>:utf8','update.xml';
	say {$_} '<collection>' for $new_recs,$update_recs;
	open my $ods,'<:utf8','EESCWAST';
	$/ = "\x{C}";
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
		for (@{$s3->{$symbol}}) {
			my $field = MARC::Field->new(tag => 'FFT');
			$field->set_sub('a','http://undhl-dgacm.s3.amazonaws.com/'.uri_escape($_));
			$field->set_sub (
				'd',
				{AR=>'العربية',ZH=>'中文',EN=>'English',FR=>'Français',RU=>'Русский',ES=>'Español',DE=>'Other'}->{substr $_,-6,2},
			);
			my $newfn = (split /\//,$_)[-1];
			$newfn = dls_fn($_);
			$field->set_sub('n',$newfn);
			$record->add_field($field);
		}
		if (! $in_dls->{$symbol}) {
			print {$new_recs} $record->to_xml;
		} else {
			$record->delete_tag($_) for qw/191 245 269 650/;
			$record->id($in_dls->{$symbol});
			print {$update_recs} $record->to_xml;
		}
	}
	say {$_} '</collection>' for $new_recs,$update_recs;
}

sub _191 {
	my ($record,$val) = @_;
	for (split /,/, $val) {
		my $field = MARC::Field->new(tag => '191');
		$_ =~ s/\([ACEFRSO]\)$//;
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

sub dls_fn {
	my $str = shift;
	my $newfn = (split /\//,$str)[-1];
	$newfn = (split /;/, $newfn)[0];
	$newfn =~ s/\.pdf//;
	$newfn =~ s/\s//;
	$newfn =~ tr/./-/;
	$newfn .= '.pdf';
	return $newfn;
}

__END__