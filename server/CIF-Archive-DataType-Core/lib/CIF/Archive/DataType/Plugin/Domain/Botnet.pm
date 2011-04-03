package CIF::Archive::DataType::Plugin::Domain::Botnet;

use strict;
use warnings;

sub prepare {
    my $class = shift;
    my $info = shift;
    return(0) unless($info->{'impact'} =~ /botnet/);
    return('domain_botnet');
}

1;
