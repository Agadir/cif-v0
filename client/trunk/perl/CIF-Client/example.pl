#!/usr/bin/perl -w

use strict;

use Data::Dumper;
use Getopt::Std;
use CIF::Client;

my %opts;
getopt('hq:c:', \%opts);
die(usage()) if($opts{'h'});

my $query = $opts{'q'} || shift || die(usage());
my $debug = ($opts{'d'}) ? 1 : 0;
my $c = $opts{'c'} || $ENV{'HOME'}.'/.cif';

sub usage {
    return <<EOF;
Usage: perl $0 -q xyz.com
        -h  --help:                 this message
        -q <string>:                query string (use 'url\\/<md5|sha1>' for url hash lookups)
     
    \$> perl $0 -q url\\/f8e74165fb840026fd0fce1fd7d62f5d0e57e7ac
    \$> perl $0 -q hut2.ru
    \$> perl $0 -q hut2.ru,url\\/f8e74165fb840026fd0fce1fd7d62f5d0e57e7ac
    \$> perl $0 hut2.ru

    configuration file ~/.cif should be readable and look something like:

    [client]
    host = https://example.com:443/api
    apikey = xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    timeout = 60

EOF
}
my ($client,$err) = CIF::Client->new({ 
    config  => $c,
});
die($err) unless($client);

my @q = split(/\,/,$query);
foreach (@q){
    $client->GET($_);
    die('request failed with code: '.$client->responseCode()) unless($client->responseCode == 200);
    my $text = $client->responseContent();
    print "Query: ".$_."\n";
    print $client->table($text) || print 'no records'."\n";
    print "\n";
}
