package CIF::WebAPI::infrastructure::networks;
use base 'CIF::WebAPI';

use strict;
use warnings;

use CIF::Message::InfrastructureNetwork;

sub GET {
    my ($self, $request, $response) = @_;
    my $maxdays = $request->{'r'}->param('age') || $request->dir_config->{'CIFFeedAgeDefault'} || 30;
    my $maxresults = $request->{'r'}->param('maxresults') || $request->dir_config->{'CIFFeedResultsDefault'} || 10000;

    my $detecttime = DateTime->from_epoch(epoch => (time() - (84600 * $maxdays)));
    my @recs = CIF::Message::InfrastructureNetwork->search_feed($detecttime,$maxresults);
    return CIF::WebAPI::infrastructure::generateFeed($response,@recs);
}

1;