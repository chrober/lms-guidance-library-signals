use strict;
use warnings;
use Test::More;
use lib '.';

{
    package TestPrefs;
    sub new { bless { values => {} }, shift }
    sub init { }
    sub get { $_[0]->{values}->{$_[1]} }
    sub set { $_[0]->{values}->{$_[1]} = $_[2] }

    package Slim::Utils::Prefs;
    my %prefs;
    sub preferences { $prefs{$_[0]} ||= TestPrefs->new }
    $INC{'Slim/Utils/Prefs.pm'} = __FILE__;

    package Slim::Plugin::Base;
    sub import { }
    sub initPlugin { 1 }
    $INC{'Slim/Plugin/Base.pm'} = __FILE__;

    package main;
    sub WEBUI { 0 }
}

require 'LibrarySignals/Provider.pm';
$INC{'Plugins/LibrarySignals/Provider.pm'} = $INC{'LibrarySignals/Provider.pm'};
require 'LibrarySignals/Plugin.pm';

is(Plugins::LibrarySignals::Plugin->getDisplayName,
    'PLUGIN_LIBRARYSIGNALS_NAME',
    'plugin publishes the localized provider name');
my $descriptor = Plugins::LibrarySignals::Plugin->guidance_provider_descriptor_v1;
is($descriptor->{provider_id}, 'library-signals',
    'plugin forwards the public provider descriptor');

{
    no warnings 'redefine';
    my @received;
    local *Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1 = sub {
        @received = @_;
        return { id => 'library-signals-guidance' };
    };

    my $policy = { playcount_influence => -80 };
    my $context = { candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1' } };
    my $config = Plugins::LibrarySignals::Plugin->guidance_provider_native_spi_config_v1(
        $policy, $context,
    );

    is_deeply($config, { id => 'library-signals-guidance' },
        'plugin returns the native provider configuration');
    is_deeply(\@received, [$policy, $context],
        'plugin removes its class invocant before forwarding native factory arguments');
}

done_testing;
