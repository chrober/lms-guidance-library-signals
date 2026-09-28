package Plugins::LibrarySignals::Provider;

use strict;
use warnings;
use Config qw(%Config);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use Slim::Utils::Prefs;

my $prefs = Slim::Utils::Prefs::preferences('plugin.guidancelibrarysignals');

my %FACTORY_DEFAULTS = (
    playcount_influence => 0,
    last_played_influence => 0,
    last_played_horizon_days => 180,
    library_age_influence => 0,
    library_age_horizon_days => 365,
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

sub guidance_provider_descriptor_v1 {
    return {
        protocol_version => 1,
        provider_id => 'library-signals',
        display_name => 'Local library signals',
        settings_uri => 'plugins/LibrarySignals/settings/librarysignals.html',
        capabilities => [qw(play_count last_played library_age)],
        scopes => ['global_candidate'],
        settings_schema_version => 1,
        controls => [
            _control('playcount_influence', 'integer', -100, 100, 0, 'playcount'),
            _control('last_played_influence', 'integer', -100, 100, 0, 'last_played'),
            _control('last_played_horizon_days', 'integer', 30, 1825, 180),
            _control('library_age_influence', 'integer', -100, 100, 0, 'library_age'),
            _control('library_age_horizon_days', 'integer', 30, 3650, 365),
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
    my ($key, $type, $minimum, $maximum, $factory_default, $guidance_channel) = @_;
    my $token = uc($key);
    return {
        key => $key,
        type => $type,
        minimum => $minimum,
        maximum => $maximum,
        factory_default => $factory_default,
        host_overridable => 1,
        (defined $guidance_channel ? (guidance_channel => $guidance_channel) : ()),
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
    return \%defaults;
}

sub guidance_provider_status_v1 {
    my $program = _program_path();
    return {
        available => 0,
        reason => 'native_binary_missing',
        program => '',
        persist_db => '',
    } unless -x $program;

    my $version = _binary_version($program);
    return {
        available => 0,
        reason => 'native_binary_incompatible',
        program => $program,
        persist_db => '',
    } unless $version =~ /"provider_id"\s*:\s*"library-signals-guidance"/
        && $version =~ /"spi_version"\s*:\s*2/;

    my $persist_db = _persist_db();
    return {
        available => 0,
        reason => 'persist_db_unavailable',
        program => $program,
        persist_db => '',
    } unless $persist_db && -r $persist_db;

    return {
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

    return {
        id => 'library-signals-guidance',
        program => $status->{program},
        options => {
            as_of_unix_seconds => 0 + $as_of,
            last_played_horizon_days => $effective->{last_played_horizon_days},
            library_age_horizon_days => $effective->{library_age_horizon_days},
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
