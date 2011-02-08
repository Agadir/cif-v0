#!/usr/bin/perl -w

use strict;
use Getopt::Std;
use CIF::FeedParser;
use Config::Simple;
use Data::Dumper;
use Net::DNS::Resolver;

my %opts;
getopts('dFc:f:',\%opts);
my $debug = $opts{'d'};
my $full_load = $opts{'F'} || 0;
my $config = $opts{'c'} || $ENV{'HOME'}.'/.cif';
my $f = $opts{'f'} || die('missing feed');
my $c = Config::Simple->new($config) || die($!.' '.$config);
$c = $c->param(-block => $f);

my $nsres;
unless($full_load){
    $c->{nsres} = Net::DNS::Resolver->new(recursive => 0);
}

my @items = CIF::FeedParser::parse($c);

CIF::FeedParser::insert($full_load,@items);