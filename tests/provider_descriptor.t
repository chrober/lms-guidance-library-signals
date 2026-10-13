use strict;
use warnings;
use Test::More;
use lib '.';

{
    package TestPrefs;
    sub new { bless { values => {} }, shift }
    sub init {
        # Mimic a newly installed provider before its settings page has ever
        # persisted a preference file. Defaults must still be published.
        return;
    }
    sub get { $_[0]->{values}{$_[1]} }
    sub set { $_[0]->{values}{$_[1]} = $_[2] }

    package Slim::Utils::Prefs;
    our $PREFS = TestPrefs->new;
    sub import { }
    sub preferences { return $PREFS }
    $INC{'Slim/Utils/Prefs.pm'} = __FILE__;

    package Slim::Utils::SQLiteHelper;
    sub dbFile { return '' }
    $INC{'Slim/Utils/SQLiteHelper.pm'} = __FILE__;

    package Slim::Utils::PluginManager;
    our @ENABLED;
    sub enabledPlugins { return @ENABLED }
    $INC{'Slim/Utils/PluginManager.pm'} = __FILE__;
}

require 'LibrarySignals/Provider.pm';

my $descriptor = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
is($descriptor->{protocol_version}, 1, 'publishes descriptor protocol v1');
is($descriptor->{provider_id}, 'library-signals', 'publishes stable provider ID');
is($descriptor->{settings_schema_version}, 2,
    'descriptor schema revision covers the host-overridable APC source');
is($descriptor->{display_name}, 'Bliss Guidance: Library Signals',
    'publishes the Bliss Guidance family name for host discovery');
is($descriptor->{native_spi}{provider_id}, 'library-signals-guidance',
    'maps to native provider ID');
is_deeply(
    $descriptor->{native_spi}{channels},
    {
        play_count => 'playcount',
        last_played => 'last_played',
        library_age => 'library_age',
    },
    'publishes stable capability-to-channel mapping',
);
my ($apc_control) = grep {
    $_->{key} eq 'use_alternative_play_count'
} @{$descriptor->{controls}};
ok($apc_control, 'publishes the Alternative Play Count source as a host control');
is($apc_control->{type}, 'boolean', 'APC source is a checkbox control');
is($apc_control->{factory_default}, 0, 'APC source defaults to native Lyrion data');
ok($apc_control->{host_overridable}, 'hosts may override the provider APC default');

my $defaults = Plugins::LibrarySignals::Provider::guidance_provider_defaults_v1();
is($defaults->{playcount_influence}, 0, 'play-count factory default is available before provider settings are saved');
is($defaults->{last_played_influence}, 0, 'last-played factory default is neutral');
is($defaults->{library_age_influence}, 0, 'library-age factory default is neutral');
is($defaults->{last_played_horizon_days}, 180, 'last-played default horizon is 180 days');
is($defaults->{library_age_horizon_days}, 365, 'library-age default horizon is 365 days');
is($defaults->{use_alternative_play_count}, 0,
    'native Lyrion listening history is the provider default');

@Slim::Utils::PluginManager::ENABLED = ();
ok(!Plugins::LibrarySignals::Provider::_alternative_play_count_available(),
    'missing Alternative Play Count is detected');
@Slim::Utils::PluginManager::ENABLED = ('Plugins::AlternativePlayCount::Plugin');
ok(Plugins::LibrarySignals::Provider::_alternative_play_count_available(),
    'enabled Alternative Play Count is detected');

my $status = Plugins::LibrarySignals::Provider::guidance_provider_status_v1();
ok(!$status->{available}, 'unavailable binary/database reports inactive provider');
ok($status->{alternative_play_count_available},
    'provider status reports Alternative Play Count independently of native availability');

my $config;
{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub {
        return {
            available => 1,
            reason => '',
            program => 'provider-binary',
            persist_db => 'persist.db',
            alternative_play_count_available => 1,
        };
    };
    $Slim::Utils::Prefs::PREFS->{values}->{use_alternative_play_count} = 0;
    $config = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { use_alternative_play_count => 1 },
        {
            as_of_unix_seconds => 123,
            candidate_identity_artifact => {
                kind => 'eligible-candidate-identities-v1',
                path => 'identities.json',
                sha256 => ('a' x 64),
            },
        },
    );
}
is($config->{options}->{listening_history_source}, 'alternative_play_count',
    'native configuration selects APC when a host override enables it and the backend is available');

{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub {
        return {
            available => 1,
            reason => '',
            program => 'provider-binary',
            persist_db => 'persist.db',
            alternative_play_count_available => 1,
        };
    };
    $Slim::Utils::Prefs::PREFS->{values}->{use_alternative_play_count} = 1;
    $config = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { use_alternative_play_count => 0 },
        {
            as_of_unix_seconds => 123,
            candidate_identity_artifact => {
                kind => 'eligible-candidate-identities-v1',
                path => 'identities.json',
                sha256 => ('a' x 64),
            },
        },
    );
}
is($config->{options}->{listening_history_source}, 'lyrion',
    'an explicit host override can select native Lyrion history over the provider APC default');

{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub {
        return {
            available => 1,
            reason => '',
            program => 'provider-binary',
            persist_db => 'persist.db',
            alternative_play_count_available => 0,
        };
    };
    $config = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { use_alternative_play_count => 1 },
        {
            as_of_unix_seconds => 123,
            candidate_identity_artifact => {
                kind => 'eligible-candidate-identities-v1',
                path => 'identities.json',
                sha256 => ('a' x 64),
            },
        },
    );
}
is($config->{options}->{listening_history_source}, 'lyrion',
    'native configuration falls back to Lyrion when a saved APC choice is unavailable');

done_testing;
