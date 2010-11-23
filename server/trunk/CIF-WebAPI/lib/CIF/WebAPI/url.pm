package CIF::WebAPI::url;
use base 'CIF::WebAPI';

use strict;
use warnings;

use CIF::Message::URL;
use CIF::WebAPI::url::url;

sub mapIndex {
    my $r = shift;
    my $idx = CIF::WebAPI::mapIndex($r);
    delete($idx->{'rec'});
    return {
        %$idx,
        address     => $r->address(),
        url_md5     => $r->url_md5(),
        url_sha1    => $r->url_sha1(),
        malware_md5 => $r->malware_md5(),
        malware_sha1 => $r->malware_sha1(),
    };
}

sub aggregateFeed {
    my @recs = @{CIF::WebAPI::aggregateFeed('url_md5',@_)};
    my @feed = map { mapIndex($_->{'rec'}) } @recs;
    return(@feed);
}

sub generateFeed {
    my $resp = shift;
    my @feed = aggregateFeed(@_);
    $resp->data()->{'result'} = \@feed;
    return Apache2::Const::HTTP_OK;
}

sub GET {
    my ($self, $request, $response) = @_;

    my $detecttime = DateTime->from_epoch(epoch => (time() - (84600 * 30)));
    my @recs = CIF::Message::URL->search_feed($detecttime,10000);
    return generateFeed($response,@recs);
}

sub buildNext {
    my ($self,$frag,$req) = @_;

    my $subh;
    for(lc($frag)){
        if(/^(cache|malware|phishing|searches)$/){
            my $mod = 'CIF::WebAPI::urls::'.$frag;
            eval "require $mod";
            if($@){
                return Apache2::Const::FORBIDDEN;
            }
            return $mod->new($self);
            last;
        }
        $subh = CIF::WebAPI::urls::url->new($self);
        $subh->{'url'} = $frag;
        return $subh;
    }
}

1;