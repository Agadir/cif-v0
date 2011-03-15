package CIF::Archive::Storage::Plugin::Iodef::Ipv4;
use base 'CIF::Archive::Storage::Plugin::Iodef';

use Regexp::Common qw/net/;
use XML::IODEF;

sub prepare {
    my $class   = shift;
    my $info    = shift;

    my $address = $info->{'address'};
    return(1) if($address && $address =~ /^$RE{'net'}{'IPv4'}/);
    return(0);
}

sub to {
    my $class = shift;
    my $info = shift;
    
    my $iodef = $class->SUPER::to($info);
    
    $iodef->add('IncidentEventDataFlowSystemNodeAddress',$info->{'address'});
    return $iodef->out();
}

1;