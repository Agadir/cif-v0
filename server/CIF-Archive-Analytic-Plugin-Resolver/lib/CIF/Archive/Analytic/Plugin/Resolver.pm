package CIF::Archive::Analytic::Plugin::Resolver;

use 5.008008;
use strict;
use warnings;

our $VERSION = '0.01_01';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use Net::Abuse::Utils qw(:all); 

sub process {
    my $self = shift;
    my $data = shift;

    return unless(ref($data) eq 'HASH');
    my $a = $data->{'address'};
    return unless($a);
    return if($data->{'rdata'});
    return unless($data->{'type'} && $data->{'type'} eq 'A'); 
    $a = lc($a);
    return unless($a =~ /[a-z0-9\.-]+\.[a-z]{2,5}$/);

    require Net::DNS::Resolver;
    my $r = Net::DNS::Resolver->new(recursive => 0);
    my $pkt = $r->send($a);
    my $ns = $r->send($a,'NS');
    my $mx = $r->send($a,'MX');
    my @rdata = $pkt->answer();
    push(@rdata,$mx->answer());
    # work-around for things like co.cc, co.uk, etc..
    ## TODO -- clean this up with official TLD lists
    unless($ns->answer()){
        $a =~ m/([a-z0-9-]+\.[a-z]{2,5})$/;
        $a = $1;
        $ns = $r->send($a,'NS');
    }
    push(@rdata,$ns->answer());
    return unless(@rdata);

    my $sev = ($data->{'severity'} eq 'high') ? 'medium' : 'low';
    my $conf = ($data->{'confidence'} >= 2) ? ($data->{'confidence'} - 2) : 0;

    foreach(@rdata){
        my ($as,$network,$ccode,$rir,$date,$as_desc) = asninfo($_->{'address'});
        my ($err,$id) = CIF::Archive->insert({
            impact      => $data->{'impact'},
            description => $data->{'description'},
            relatedid   => $data->{'uuid'},
            address     => $data->{'address'},
            rdata       => $_->{'address'} || $_->{'nsdname'},
            type        => $_->{'type'},
            class       => $_->{'class'},
            severity    => $sev,
            restriction => $data->{'restriction'},
            alternativeid   => $data->{'alternativeid'},
            alternativeid_restriction   => $data->{'alternativeid_restriction'},
            detecttime  => $data->{'detecttime'},
            confidence  => $conf,
            asn         => $as,
            asn_desc    => $as_desc,
            cc          => $ccode,
            cidr        => $network,
            rir         => $rir,
            portlist    => $data->{'portlist'},
            protocol    => $data->{'protocol'},
        });
        warn $err if($err);
    }
}

sub asninfo {
    my $a = shift;
    return undef unless($a);

    my ($as,$network,$ccode,$rir,$date) = get_asn_info($a);
    my $as_desc;
    $as_desc = get_as_description($as) if($as);

    $as         = undef if($as && $as eq 'NA');
    $network    = undef if($network && $network eq 'NA');
    $ccode      = undef if($ccode && $ccode eq 'NA');
    $rir        = undef if($rir && $rir eq 'NA');
    $date       = undef if($date && $date eq 'NA');
    $as_desc    = undef if($as_desc && $as_desc eq 'NA');
    $a          = undef if($a eq '');
    return ($as,$network,$ccode,$rir,$date,$as_desc);
}

1;
__END__

=head1 NAME

CIF::Archive::Analytic::Plugin::Resolver - a CIF::Archive::Analytic plugin for resolving domain data

=head1 SEE ALSO

 http://code.google.com/p/collective-intelligence-framework/
 CIF::Archive

=head1 AUTHOR

 Wes Young, E<lt>wes@barely3am.comE<gt>

=head1 COPYRIGHT AND LICENSE

 Copyright (C) 2011 by Wes Young (claimid.com/wesyoung)
 Copyright (C) 2011 by the Trustee's of Indiana University (www.iu.edu)
 Copyright (C) 2011 by the REN-ISAC (www.ren-isac.net)

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=cut