package CIF::Message::Domain;
use base 'CIF::Archive';

use strict;
use warnings;

use Regexp::Common qw/net/;
use Regexp::Common::net::CIDR;
use DateTime::Format::DateParse;
use Data::Dumper;
use DateTime;
use IO::Select;
use CIF::Message;

__PACKAGE__->table('domain');
__PACKAGE__->columns(Primary => 'id');
__PACKAGE__->columns(All => qw/id uuid description address type rdata cidr asn asn_desc cc rir class ttl whois impact confidence source alternativeid alternativeid_restriction severity restriction detecttime created/);
__PACKAGE__->columns(Essential => qw/id uuid description address rdata impact restriction created/);
__PACKAGE__->sequence('domain_id_seq');

my $tests = {
    'severity'      => qr/^(low|medium|high)$/,
    'confidence'    => qr/^\d+/,
    'address'       => qr/[a-zA-Z0-9.-]+\.[a-zA-Z]{2,5}$/,
};

sub insert {
    my $self = shift;
    my $info = {%{+shift}};

    my ($ret,$err) = $self->check_params($tests,$info);
    return($ret,$err) unless($ret);

    my $uuid    = $info->{'uuid'};

    unless($uuid){
        $uuid = CIF::Message->insert({
            storage => 'IODEF',
            %$info
        });
        $uuid = $uuid->uuid();
    }
    if($info->{'severity'} eq ''){
        # work-around for domain_whitelist and cif_feed_parser
        $info->{'severity'} = undef;
    }

    my $id = eval { $self->SUPER::insert({
        uuid        => $uuid,
        description => lc($info->{'description'}),
        address     => $info->{'address'},
        type        => $info->{'type'},
        rdata       => $info->{'rdata'},
        cidr        => $info->{'cidr'},
        asn         => $info->{'asn'},
        asn_desc    => $info->{'asn_desc'},
        cc          => $info->{'cc'},
        rir         => $info->{'rir'},
        class       => $info->{'class'},
        ttl         => $info->{'ttl'},
        source      => $info->{'source'},
        impact      => $info->{'impact'} || 'malicious domain',
        confidence  => $info->{'confidence'},
        severity    => $info->{'severity'},
        restriction => $info->{'restriction'} || 'private',
        detecttime  => $info->{'detecttime'},
        alternativeid => $info->{'alternativeid'},
        alternativeid_restriction => $info->{'alternativeid_restriction'} || 'private',
    }) };
    if($@){
        return(undef,$@) unless($@ =~ /duplicate key value violates unique constraint/);
        $id = $self->retrieve(uuid => $uuid);
    }
    return($id);    
}

# send in a Net::DNS $res and the domain
# returns an array

sub getrdata {
    my ($res,$d) = @_;
    return undef unless($d);

    my @rdata;

    if($res){
        my $default = $res->bgsend($d);
        my $ns      = $res->bgsend($d,'NS');
        my $mx      = $res->bgsend($d,'MX');
        
        my $sel = IO::Select->new([$mx,$ns,$default]);
        my @ready = $sel->can_read(5);
        
        if(@ready){
            foreach my $sock (@ready){
                for($sock){
                    $default    = $res->bgread($default) if($default);
                    $ns         = $res->bgread($ns) if($ns);
                    $mx         = $res->bgread($mx) if($mx);
                }
                $sel->remove($sock);
                $sock = undef;
            }
        }
        if(ref($default) eq 'Net::DNS::Packet' && $default->answer()){
            push(@rdata,$default->answer());
        } else {
            push(@rdata, { name => $d, address => undef, type => 'A', class => 'IN', ttl => -1 });
        }
        push(@rdata,$ns->answer()) if(ref($ns) eq 'Net::DNS::Packet');
        push(@rdata,$mx->answer()) if(ref($mx) eq 'Net::DNS::Packet');
    }

    if($#rdata == -1){
        push(@rdata, { name => $d, address => undef, type => 'A', class => 'IN', ttl => undef });
    }

    return(@rdata);
}

sub lookup {
    my ($self,$address,$apikey,$limit,$nolog) = @_;
    $limit = 5000 unless($limit);
    my @recs;
    if($address =~ /^$RE{'net'}{'IPv4'}/){
        @recs = $self->search_rdata($address,$limit);
    } else {
        @recs = $self->search_by_address('%'.$address.'%',$limit);
    }

    return @recs if($nolog);

    my $t = $self->table();
    $self->table('domain_search');
    my $source = CIF::Message::genMessageUUID('api',$apikey);
    my $asn;
    my $description = 'search '.$address;
    my $dt = DateTime->from_epoch(epoch => time());
    $dt = $dt->ymd().'T'.$dt->hour().':00:00Z';

    my $sid = $self->insert({
        address => $address,
        impact  => 'search',
        source  => $source,
        description => $description,
        detecttime  => $dt,
    });
    $self->table($t);
    return @recs;
}

sub isWhitelisted {
    my $self = shift;
    my $a = shift;

    return undef unless($a && $a =~ /\.[a-zA-Z]{2,4}$/);
    return(1) unless($a =~ /\.[a-zA-Z]{2,4}$/);

    my $sql = '';

    ## TODO -- do this by my $parts = split(/\./,$a); foreach ....
    for($a){
        if(/([a-zA-Z0-9-]+\.[a-zA-Z]{2,4})$/){
            $sql .= qq{address LIKE '$1'};
        }
        if(/((?:[a-zA-Z0-9-]+\.){2,2}[a-zA-Z]{2,4})$/){
            $sql .= qq{ OR address LIKE '$1'};
        }
        if(/((?:[a-zA-Z0-9-]+\.){3,3}[a-zA-Z]{2,4})$/){
            $sql .= qq{ OR address LIKE '$1'};
        }
        if(/((?:[a-zA-Z0-9-]+\.){4,4}[a-zA-Z]{2,4})$/){
            $sql .= qq{ OR address LIKE '$1'};
        }
    }
    #if($sql eq ''){ return(0); }

    $sql .= qq{\nORDER BY detecttime DESC, created DESC, id DESC};
    my $t = $self->table();
    $self->table('domain_whitelist');
    my @recs = $self->retrieve_from_sql($sql);
    $self->table($t);
    return @recs;
}

__PACKAGE__->set_sql('feed' => qq{
    SELECT * FROM __TABLE__
    WHERE type = 'A'
    AND severity >= ?
    AND restriction <= ?
    AND NOT (lower(impact) = 'search' OR lower(impact) = 'domain whitelist' OR lower(impact) LIKE '% whitelist %')
    ORDER BY detecttime DESC, created DESC, id DESC
    LIMIT ?
});

__PACKAGE__->set_sql('by_address' => qq{
    SELECT * FROM __TABLE__
    WHERE lower(address) LIKE lower(?)
    AND lower(impact) NOT LIKE '% whitelist %'
    LIMIT ?
});

__PACKAGE__->set_sql('by_rdata' => qq{
    SELECT * FROM __TABLE__
    WHERE lower(rdata) LIKE lower(?)
    ORDER BY detecttime DESC, created DESC, id DESC,
    LIMIT ?
});

__PACKAGE__->set_sql('by_asn' => qq{
    SELECT * FROM __TABLE__
    WHERE asn = ?
    ORDER BY detecttime DESC, created DESC, id DESC
    LIMIT ?
});

1;
