package CIF::Archive::DataType::Plugin::Domain::Whitelist;
use base 'CIF::Archive::DataType::Plugin::Domain';

__PACKAGE__->table('domain_whitelist');

sub prepare {
    my $class = shift;
    my $info = shift;
    return unless($info->{'impact'});
    return(0) unless($info->{'impact'} =~ /whitelist/);
    return('whitelist');
}

1;
