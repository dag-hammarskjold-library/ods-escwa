#!/usr/bin/perl

use strict;
use warnings;
use feature 'say';

package main;
use Data::Dumper;
$Data::Dumper::Indent = 1;
use Getopt::Std;
use WWW::Mechanize;
use WWW::Mechanize::Plugin::FollowMetaRedirect;

use constant LANG => {
	AR => 'A',
	ZH => 'C',
	EN => 'E',
	FR => 'F',
	RU => 'R',
	ES => 'S',
	DE => 'O'
};

RUN: {
	$| = 1;
	MAIN(options());
}

sub options {
	my $opts = {
		'h' => 'help',
		'i:' => 'ods file (path)',
		'd:' => 'save directory'
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
	
	my $mech = WWW::Mechanize->new ( 
		agent => 'Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/43.0.2357.81 Safari/537.36',
		cookie_jar => {},
		timeout => 10,
		autocheck => 0,
		stack_depth => 5
	);
	
	open my $ods,'<',$opts->{i};
	my %seen;
	my $c;
	while (<$ods>) {
		$c++;
		chomp;
		my @row = split "\t", $_;
		my @langs = grep {defined($_)} @row[3..10] if $row[3];
		next if $langs[0] eq 'NONE';
		my ($sym,$id) = @row[0,1];
		$seen{$id}++ if $id ne 'NOT IN DLS';
		#next if $seen{$id} and $seen{$id} > 1;
		#next unless $sym =~ '^E/ESCWA/16/8'; # SUPPL.1';
		#next unless $. >= 170 and $. <= 200;
		for my $lang (@langs) {
			my $sdir;
			if ($id eq 'NOT IN DLS') {
				$sdir = 'temp_id_'.$.;
			} else {
				$sdir = $id;
			}
			my $save = join '/', $opts->{d}, $sdir, encode_fn([$sym],$lang);
			next if -e $save;
			mkdir $opts->{d}.'/'.$sdir; 
			my $url = 'http://daccess-ods.un.org/access.nsf/Get?Open&DS='.$sym.'&Lang='.LANG->{$lang};
			print "$save\t";
			download($mech,$url,$save);
			print "\n";
		}
		
	}
}

sub encode_fn {
	my ($syms,$lang) = @_;
	$lang ||= '';
	tr/\/\*/_!/ for @$syms;
	return join(';',sort @$syms)."-$lang.pdf";
}

sub download {
	my ($mech,$url,$save) = @_;
	#local $| = 1;
	print "navigating ODS... ";
	my $response = $mech->get($url);
	print "no response" and return if ! $response;
	$response = $mech->follow_link(url_regex => qr/TMP/);
	$response = $mech->follow_link(tag => q/frame/);
	$mech->back;
	print "downloading... ";
	$response = $mech->follow_meta_redirect;
	$mech->save_content($save); #, binmode => ':utf8');
	print qq/save failed/
		and unlink $save 
		and return 
			unless is_pdf("$save");
	print "OK";
	$mech->get('https://documents.un.org');
	return 1;
}

sub is_pdf {
	my $path = shift;	
	open my $check,"<",$path;
	while (<$check>) {
		return 1 if index($_,'%PDF') > 0;
		return 1 if $_ =~ /\%pdf/i;
		last if $. > 1;	
	}
	return 0;
}

__END__