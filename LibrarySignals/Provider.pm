package Plugins::LibrarySignals::Provider;

use strict;
use warnings;
use Config qw(%Config);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use JSON::PP qw(encode_json);
use Slim::Utils::Prefs;

my $prefs = Slim::Utils::Prefs::preferences('plugin.guidancelibrarysignals');
my $log;

my %FACTORY_DEFAULTS = (
    playcount_influence => 0,
    last_played_influence => 0,
    last_played_horizon_days => 180,
    library_age_influence => 0,
    library_age_horizon_days => 365,
    use_alternative_play_count => 0,
    settings_revision => 1,
);

my %RANGES = (
    playcount_influence => [-100, 100],
    last_played_influence => [-100, 100],
    last_played_horizon_days => [30, 1825],
    library_age_influence => [-100, 100],
    library_age_horizon_days => [30, 3650],
);

sub init_preferences {
    $prefs->init({%FACTORY_DEFAULTS});
}

sub init_logging {
    return $log if $log;
    return unless eval { require Slim::Utils::Log; 1 };
    $log = Slim::Utils::Log->addLogCategory({
        category => 'plugin.guidancelibrarysignals',
        defaultLevel => 'WARN',
        description => 'PLUGIN_LIBRARYSIGNALS_NAME',
    });
    return $log;
}

sub guidance_provider_descriptor_v1 {
    return {
        protocol_version => 1,
        provider_id => 'library-signals',
        display_name => 'Bliss Guidance: Library Signals',
        settings_uri => 'plugins/LibrarySignals/settings/librarysignals.html',
        capabilities => [qw(play_count last_played library_age)],
        scopes => ['global_candidate'],
        settings_schema_version => 2,
        controls => [
            {
                key => 'use_alternative_play_count',
                type => 'boolean',
                factory_default => 0,
                host_overridable => 1,
                label_token => 'GUIDANCE_LIBRARY_SIGNALS_USE_APC',
                help_token => 'GUIDANCE_LIBRARY_SIGNALS_USE_APC_DESC',
            },
            _control('playcount_influence', 'integer', -100, 100, 0, 'playcount', 'slider'),
            _control('last_played_influence', 'integer', -100, 100, 0, 'last_played', 'slider'),
            _control('last_played_horizon_days', 'integer', 30, 1825, 180, undef, 'number'),
            _control('library_age_influence', 'integer', -100, 100, 0, 'library_age', 'slider'),
            _control('library_age_horizon_days', 'integer', 30, 3650, 365, undef, 'number'),
        ],
        native_spi => {
            provider_id => 'library-signals-guidance',
            spi_version => 2,
            protocol => 'bliss-guidance-jsonl-v2',
            channels => {
                play_count => 'playcount',
                last_played => 'last_played',
                library_age => 'library_age',
            },
            artifact_kinds => ['eligible-candidate-identities-v1'],
            resource_kinds => ['lms-persist-sqlite-v1'],
        },
    };
}

sub _control {
    my ($key, $type, $minimum, $maximum, $factory_default, $guidance_channel, $render_as) = @_;
    my $token = uc($key);
    return {
        key => $key,
        type => $type,
        minimum => $minimum,
        maximum => $maximum,
        factory_default => $factory_default,
        host_overridable => 1,
        (defined $guidance_channel ? (guidance_channel => $guidance_channel) : ()),
        (defined $render_as ? (render_as => $render_as) : ()),
        label_token => 'GUIDANCE_LIBRARY_SIGNALS_' . $token,
        help_token => 'GUIDANCE_LIBRARY_SIGNALS_' . $token . '_DESC',
    };
}

sub guidance_provider_defaults_v1 {
    init_preferences();
    my %defaults;
    for my $key (keys %RANGES) {
        my ($minimum, $maximum) = @{$RANGES{$key}};
        my $value = $prefs->get($key);
        $value = $FACTORY_DEFAULTS{$key} unless defined $value;
        $value = int($value);
        $value = $minimum if $value < $minimum;
        $value = $maximum if $value > $maximum;
        $defaults{$key} = $value;
    }
    $defaults{settings_revision} = int(
        $prefs->get('settings_revision') || $FACTORY_DEFAULTS{settings_revision}
    );
    $defaults{use_alternative_play_count} =
        $prefs->get('use_alternative_play_count') ? 1 : 0;
    return \%defaults;
}

sub guidance_provider_status_v1 {
    my $program = _program_path();
    my $apc_available = _alternative_play_count_available();
    my $apc_configured = $prefs->get('use_alternative_play_count') ? 1 : 0;
    my %apc_status = (
        alternative_play_count_available => $apc_available,
        alternative_play_count_configured => $apc_configured,
        alternative_play_count_fallback => $apc_configured && !$apc_available ? 1 : 0,
    );
    return {
        %apc_status,
        available => 0,
        reason => 'native_binary_missing',
        program => '',
        persist_db => '',
    } unless -x $program;

    my $version = _binary_version($program);
    return {
        %apc_status,
        available => 0,
        reason => 'native_binary_incompatible',
        program => $program,
        persist_db => '',
    } unless $version =~ /"provider_id"\s*:\s*"library-signals-guidance"/
        && $version =~ /"spi_version"\s*:\s*2/;

    my $persist_db = _persist_db();
    return {
        %apc_status,
        available => 0,
        reason => 'persist_db_unavailable',
        program => $program,
        persist_db => '',
    } unless $persist_db && -r $persist_db;

    return {
        %apc_status,
        available => 1,
        reason => '',
        program => $program,
        persist_db => $persist_db,
        version => $version,
    };
}

sub guidance_provider_native_spi_config_v1 {
    my ($resolved_policy, $trusted_job_context) = @_;
    $resolved_policy ||= {};
    $trusted_job_context ||= {};
    my $status = guidance_provider_status_v1();
    die 'Library signals provider is unavailable: ' . ($status->{reason} || 'unknown')
        unless $status->{available};

    my $artifact = $trusted_job_context->{candidate_identity_artifact};
    die 'Library signals requires a trusted candidate identity artifact'
        unless ref($artifact) eq 'HASH' && $artifact->{path} && $artifact->{sha256};
    die 'Library signals candidate identity artifact must be eligible-candidate-identities-v1'
        unless ($artifact->{kind} || 'eligible-candidate-identities-v1')
            eq 'eligible-candidate-identities-v1';

    my $defaults = guidance_provider_defaults_v1();
    my $effective = _effective_policy($resolved_policy, $defaults);
    my $as_of = $trusted_job_context->{as_of_unix_seconds};
    die 'Library signals requires a frozen non-negative as_of_unix_seconds'
        unless defined $as_of && $as_of =~ /^\d+$/;

    my $use_apc = $effective->{use_alternative_play_count}
        && $status->{alternative_play_count_available};
    if ($effective->{use_alternative_play_count} && !$use_apc) {
        _log_warning('Library Signals: Alternative Play Count is unavailable; using Lyrion listening history');
    }
    return {
        id => 'library-signals-guidance',
        program => $status->{program},
        options => {
            as_of_unix_seconds => 0 + $as_of,
            listening_history_source => $use_apc
                ? 'alternative_play_count' : 'lyrion',
            last_played_horizon_days => $effective->{last_played_horizon_days},
            library_age_horizon_days => $effective->{library_age_horizon_days},
            diagnostic_level => _diagnostic_level(),
        },
        artifacts => [{
            kind => 'eligible-candidate-identities-v1',
            path => $artifact->{path},
            sha256 => $artifact->{sha256},
        }],
        resources => [{
            kind => 'lms-persist-sqlite-v1',
            path => $status->{persist_db},
            access => 'read_only',
        }],
        timeout_ms => 5000,
    };
}

sub guidance_provider_log_events_v1 {
    my ($events, $context) = @_;
    for my $event (@{ref($events) eq 'ARRAY' ? $events : []}) {
        next unless ref($event) eq 'HASH';
        my $message = _render_log_event($event);
        next unless length $message;
        my $level = $event->{level} || 'warning';
        $level eq 'debug' ? _log_debug($message)
            : $level eq 'info' ? _log_info($message)
            : $level eq 'error' ? _log_error($message)
            : _log_warning($message);
    }
    return 1;
}

sub _render_log_event {
    my $event = shift;
    my $name = $event->{event} || '';
    my $details = ref($event->{details}) eq 'HASH' ? $event->{details} : {};
    if ($name eq 'library_signals_prepare_started') {
        return sprintf('Library Signals: preparing signals for %d candidate tracks',
            $details->{candidates} || $event->{result_count} || 0);
    }
    if ($name eq 'library_signals_sources') {
        my $sources = ref($details->{source_by_channel}) eq 'HASH'
            ? $details->{source_by_channel} : {};
        return sprintf('Library Signals sources: play-count=%s, last-played=%s, library-age=%s',
            _source_label($sources->{playcount}),
            _source_label($sources->{last_played}),
            _source_label($sources->{library_age}));
    }
    if ($name eq 'library_signals_prepared') {
        return sprintf('Library Signals prepared: candidates=%d, play-count known=%d, last-played known=%d, library-age known=%d',
            $event->{result_count} || 0, $details->{known_playcounts} || 0,
            $details->{known_last_played} || 0, $details->{known_library_age} || 0);
    }
    return 'Library Signals request JSON: ' . _safe_json($details->{request})
        if $name eq 'library_signals_request_json';
    if ($name eq 'library_signals_database_lookup') {
        return sprintf('Library Signals database lookup: queried=%d, cache hits=%d, batches=%d, elapsed=%d ms',
            $details->{queried} || 0, $details->{cached} || 0,
            $details->{batches} || 0, $details->{elapsed_ms} || 0);
    }
    return 'Library Signals result JSON: ' . _safe_json($details->{result})
        if $name eq 'library_signals_result_json';
    if ($name eq 'library_signals_scored') {
        return sprintf('Library Signals scoring: candidates=%d, signals=%d, database queried=%d, cache hits=%d',
            $details->{candidates} || 0, $details->{signals} || $event->{result_count} || 0,
            $details->{queried} || 0, $details->{cached} || 0);
    }
    return '';
}

sub _source_label {
    my $source = shift || '';
    return 'Alternative Play Count' if $source eq 'alternative_play_count';
    return 'Lyrion' if $source eq 'lyrion';
    return $source || 'unknown';
}

sub _diagnostic_level {
    my $logger = init_logging();
    return 'warning' unless $logger;
    return 'debug' if eval { $logger->is_debug };
    return 'info' if eval { $logger->is_info };
    return 'warning';
}

sub _safe_json {
    my $value = shift;
    return '{}' unless defined $value;
    my $json = eval { encode_json($value) } || '{}';
    return length($json) > 16384 ? substr($json, 0, 16384) . '...' : $json;
}

sub _log_debug { my $logger = init_logging(); $logger->debug($_[0]) if $logger && eval { $logger->is_debug }; }
sub _log_info { my $logger = init_logging(); $logger->info($_[0]) if $logger && eval { $logger->is_info }; }
sub _log_warning { my $logger = init_logging(); $logger->warn($_[0]) if $logger; }
sub _log_error { my $logger = init_logging(); $logger->error($_[0]) if $logger; }

sub _alternative_play_count_available {
    return 0 unless eval { require Slim::Utils::PluginManager; 1 };
    return scalar grep { $_ eq 'Plugins::AlternativePlayCount::Plugin' }
        Slim::Utils::PluginManager->enabledPlugins();
}

sub _effective_policy {
    my ($policy, $defaults) = @_;
    my %effective;
    for my $key (keys %RANGES) {
        my ($minimum, $maximum) = @{$RANGES{$key}};
        my $value = exists $policy->{$key} ? $policy->{$key} : $defaults->{$key};
        die "Invalid library-signals value for $key"
            unless defined $value && $value =~ /^-?\d+$/;
        $value = int($value);
        die "Out-of-range library-signals value for $key"
            if $value < $minimum || $value > $maximum;
        $effective{$key} = $value;
    }
    my $apc_value = exists $policy->{use_alternative_play_count}
        ? $policy->{use_alternative_play_count}
        : $defaults->{use_alternative_play_count};
    die 'Invalid library-signals value for use_alternative_play_count'
        unless defined $apc_value && $apc_value =~ /^(?:0|1)$/;
    $effective{use_alternative_play_count} = $apc_value ? 1 : 0;
    return \%effective;
}

sub _program_path {
    my $directory = dirname(__FILE__);
    my $platform = _platform();
    my $name = $^O eq 'MSWin32'
        ? 'bliss-guidance-library-signals.exe'
        : 'bliss-guidance-library-signals';
    return catfile($directory, 'Bin', $platform, $name);
}

sub _platform {
    return 'windows' if $^O eq 'MSWin32';
    return 'mac' if $^O eq 'darwin';
    my $arch = lc($Config{archname} || '');
    return 'aarch64-linux' if $arch =~ /(?:aarch64|arm64)/;
    return 'armhf-linux' if $arch =~ /(?:armv6|armv7|armhf|gnueabihf)/;
    return 'x86_64-linux';
}

sub _binary_version {
    my $program = shift;
    my $quoted = $program;
    $quoted =~ s/"/\\"/g;
    return eval { qx("$quoted" version --json) } || '';
}

sub _persist_db {
    return eval {
        require Slim::Utils::SQLiteHelper;
        Slim::Utils::SQLiteHelper->dbFile('persist.db', 'persistent');
    } || '';
}

1;
