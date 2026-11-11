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

    package TestLog;
    sub new { bless { lines => [] }, shift }
    sub is_debug { 1 }
    sub is_info { 1 }
    sub debug { push @{$_[0]{lines}}, ['debug', $_[1]] }
    sub info { push @{$_[0]{lines}}, ['info', $_[1]] }
    sub warn { push @{$_[0]{lines}}, ['warning', $_[1]] }
    sub error { push @{$_[0]{lines}}, ['error', $_[1]] }

    package Slim::Utils::Log;
    our $LOGGER = TestLog->new;
    sub addLogCategory { return $LOGGER }
    $INC{'Slim/Utils/Log.pm'} = __FILE__;
}

require 'LibrarySignals/Provider.pm';

{
    no warnings 'redefine';
    local *Slim::Utils::SQLiteHelper::dbFile = sub { return @_ == 1 ? '/configured/custom-library.db' : '/incorrect/library.db' };
    is(Plugins::LibrarySignals::Provider::_catalogue_db(), '/configured/custom-library.db',
        'uses the actual configured catalogue path rather than assuming its filename');
}

my $without_apc = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
my ($identity_without_lab) = grep { $_->{key} eq 'artist_identity_mode' } @{$without_apc->{controls}};
ok($identity_without_lab, 'provider exposes artist identity policy');
ok(!grep($_ eq 'follow_lab', @{$identity_without_lab->{values}}), 'follow Lab is unavailable when Lab is disabled');
my %identity_values = map { $_ => 1 } @{$identity_without_lab->{values}};
ok(!grep(!$identity_values{$_}, keys %{$identity_without_lab->{option_labels}}), 'identity labels only reference available choices');
ok(!scalar(grep { $_->{key} eq 'use_alternative_play_count' } @{$without_apc->{controls}}),
    'hosts receive no APC control when Alternative Play Count is unavailable');
@Slim::Utils::PluginManager::ENABLED = ('Plugins::AlternativePlayCount::Plugin');
my $descriptor = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
is($descriptor->{protocol_version}, 1, 'publishes descriptor protocol v1');
is($descriptor->{provider_id}, 'library-signals', 'publishes stable provider ID');
is($descriptor->{settings_schema_version}, 3,
    'descriptor schema revision covers aggregate listening controls');
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
        album_play_count => 'album_playcount',
        artist_play_count => 'artist_playcount',
        album_last_played => 'album_last_played',
        artist_last_played => 'artist_last_played',
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
is($defaults->{artist_identity_mode}, 'shared_artist', 'shared artist is default without Lab');
{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::_lab_artist_mode = sub { 'primary_artist' };
    @Slim::Utils::PluginManager::ENABLED = ('Plugins::BlissMixerLab::Plugin');
    my $with_lab = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
    my ($identity) = grep { $_->{key} eq 'artist_identity_mode' } @{$with_lab->{controls}};
    ok(grep($_ eq 'follow_lab', @{$identity->{values}}), 'follow Lab is offered when Lab is enabled');
    is(Plugins::LibrarySignals::Provider::_resolve_artist_identity('follow_lab'), 'primary_artist', 'follow Lab uses its current artist identity');
    is(Plugins::LibrarySignals::Provider::_resolve_artist_identity('shared_artist'), 'shared_artist', 'explicit provider choice overrides Lab');
}
{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::_lab_artist_mode = sub { 'invalid_mode' };
    @Slim::Utils::PluginManager::ENABLED = ('Plugins::BlissMixerLab::Plugin');
    is(Plugins::LibrarySignals::Provider::_resolve_artist_identity('follow_lab'), 'shared_artist',
        'an invalid Lab setting uses the common shared-artist default');
}
@Slim::Utils::PluginManager::ENABLED = ('Plugins::AlternativePlayCount::Plugin');
for my $key (qw(album_playcount_influence artist_playcount_influence album_last_played_influence artist_last_played_influence)) {
    my ($control) = grep { $_->{key} eq $key } @{$descriptor->{controls}};
    ok($control && $control->{host_overridable} && $control->{render_as} eq 'slider', "$key is a host-overridable slider");
    is($defaults->{$key}, 0, "$key is neutral before the provider settings are saved");
}
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
is($status->{effective_default_fallbacks}->{artist_identity_mode}, 'follow_lab',
    'hosts can explain that the inherited identity temporarily falls back when Lab is unavailable');
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
is($config->{options}->{diagnostic_level}, 'debug',
    'native configuration follows the provider log category level');
ok(!exists $config->{options}->{aggregate_identity_mode}, 'track-only configuration does not activate catalogue aggregation');

{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub {
        return { available => 1, program => 'provider-binary', persist_db => 'persist.db', alternative_play_count_available => 0 };
    };
    local *Plugins::LibrarySignals::Provider::_catalogue_db = sub { return __FILE__ };
    my $aggregate = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { album_playcount_influence => -50 },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1, candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    );
    is($aggregate->{options}->{aggregate_identity_mode}, 'shared_artist', 'aggregate request uses shared-artist fallback');
    is_deeply([map { $_->{kind} } @{$aggregate->{resources}}], ['lms-persist-sqlite-v1', 'lms-catalogue-sqlite-v1'], 'aggregate configuration adds the trusted catalogue resource');
    is($aggregate->{resources}->[1]->{access}, 'read_only', 'catalogue resource is read-only');
    my $legacy_host = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { album_playcount_influence => -50 },
        { as_of_unix_seconds => 123, candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    );
    ok(!exists $legacy_host->{options}->{aggregate_identity_mode}, 'a host without bounded-family support receives no aggregate guidance');
}
{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub {
        return { available => 1, program => 'provider-binary', persist_db => 'persist.db', alternative_play_count_available => 0 };
    };
    local *Plugins::LibrarySignals::Provider::_catalogue_db = sub { return '' };
    my $without_catalogue = eval { Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { playcount_influence => -50, album_playcount_influence => -50 },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1, candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    ) };
    ok($without_catalogue, 'unavailable catalogue does not disable existing track guidance');
    ok(!exists $without_catalogue->{options}->{aggregate_identity_mode}, 'unavailable catalogue leaves aggregate guidance neutral');
}
{
    no warnings 'redefine';
    local *Plugins::LibrarySignals::Provider::guidance_provider_status_v1 = sub { return { available => 1, program => 'provider-binary', persist_db => 'persist.db' } };
    local *Plugins::LibrarySignals::Provider::_catalogue_db = sub { return __FILE__ };
    local *Plugins::LibrarySignals::Provider::_lab_artist_mode = sub { return 'exact_bliss_credit' };
    @Slim::Utils::PluginManager::ENABLED = ('Plugins::BlissMixerLab::Plugin');
    my $album_only = eval { Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { album_playcount_influence => -50, artist_identity_mode => 'follow_lab' },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1, candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    ) };
    ok($album_only, 'an unsupported artist identity does not block album-only guidance');
    is($album_only->{options}{aggregate_identity_mode}, 'shared_artist', 'album aggregation is enabled independently of Lab artist identity');
    my $artist_fallback = eval { Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { artist_playcount_influence => -50, artist_identity_mode => 'follow_lab' },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1, candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    ) };
    ok($artist_fallback, 'unsupported exact credit does not disable existing track guidance');
    ok(!exists $artist_fallback->{options}->{aggregate_identity_mode}, 'unsupported artist aggregation remains neutral rather than using a different identity silently');
    local *Plugins::LibrarySignals::Provider::_bliss_analysis_db = sub { return __FILE__ };
    my $exact = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { artist_playcount_influence => -50, artist_identity_mode => 'follow_lab' },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1,
          track_identity_snapshot => __FILE__, track_identity_snapshot_sha256 => ('c' x 64),
          candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    );
    is($exact->{options}->{aggregate_identity_mode}, 'exact_bliss_credit',
        'following Lab uses exact Bliss-credit aggregation when trusted inputs are present');
    is_deeply([map { $_->{kind} } @{$exact->{resources}}],
        ['lms-persist-sqlite-v1', 'lms-catalogue-sqlite-v1',
         'lyrion-track-identities-sqlite-v1', 'bliss-analysis-sqlite-v1'],
        'exact-credit inputs are supplied as trusted read-only resources');
    my $realtime = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { artist_playcount_influence => -50, artist_identity_mode => 'follow_lab' },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1,
          track_identity_snapshot => __FILE__, track_identity_snapshot_sha256 => ('c' x 64), realtime_budget_ms => 500,
          candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    );
    ok(!exists $realtime->{options}->{aggregate_identity_mode},
        'slow exact-credit scan is not started inside a short real-time budget');
    ok(scalar(grep { $_->[0] eq 'warning' && $_->[1] =~ /real-time budget/ }
        @{$Slim::Utils::Log::LOGGER->{lines}}),
        'real-time identity fallback explains its budget limitation in the log');
    my $realtime_album = Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(
        { artist_playcount_influence => -50, album_playcount_influence => -50, artist_identity_mode => 'follow_lab' },
        { as_of_unix_seconds => 123, bounded_signal_families_v1 => 1,
          track_identity_snapshot => __FILE__, track_identity_snapshot_sha256 => ('c' x 64), realtime_budget_ms => 500,
          candidate_identity_artifact => { kind => 'eligible-candidate-identities-v1', path => 'identities.json', sha256 => ('a' x 64) } },
    );
    is($realtime_album->{options}->{aggregate_identity_mode}, 'shared_artist',
        'album guidance stays available when exact-credit artist guidance exceeds the budget');
    is($realtime_album->{options}->{omit_artist_aggregates}, 1,
        'real-time fallback does not substitute a different artist identity');
}

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

Plugins::LibrarySignals::Provider::guidance_provider_log_events_v1([
    {
        event_version => 'guidance_log_event_v1', level => 'info', phase => 'prepare',
        event => 'library_signals_sources', provider_id => 'library-signals-guidance',
        details => { source_by_channel => {
            playcount => 'alternative_play_count',
            last_played => 'alternative_play_count',
            library_age => 'lyrion',
        } },
    },
    {
        event_version => 'guidance_log_event_v1', level => 'info', phase => 'prepare',
        event => 'library_signals_prepared', provider_id => 'library-signals-guidance',
        result_count => 20,
        details => { known_playcounts => 18, known_last_played => 17, known_library_age => 20 },
    },
    {
        event_version => 'guidance_log_event_v1', level => 'debug', phase => 'score',
        event => 'library_signals_scored', provider_id => 'library-signals-guidance',
        details => { candidates => 20, signals => 54, queried => 0, cached => 20 },
    },
], { host => 'fixture' });
ok(
    scalar(grep {
        $_->[1] eq 'Library Signals sources: play-count=Alternative Play Count, last-played=Alternative Play Count, library-age=Lyrion'
    } @{$Slim::Utils::Log::LOGGER->{lines}}),
    'native provenance event is rendered in the provider log category',
);
ok(
    scalar(grep {
        $_->[1] eq 'Library Signals prepared: candidates=20, play-count known=18, last-played known=17, library-age known=20'
    } @{$Slim::Utils::Log::LOGGER->{lines}}),
    'native preparation summary is rendered in the provider log category',
);
ok(
    scalar(grep {
        $_->[1] eq 'Library Signals scoring: candidates=20, signals=54, database queried=0, cache hits=20'
    } @{$Slim::Utils::Log::LOGGER->{lines}}),
    'native score event renders bounded debug diagnostics',
);

done_testing;
