package Plugins::LibrarySignals::Settings;

use strict;
use warnings;
use base qw(Slim::Web::Settings);
use Slim::Utils::Prefs;

use Plugins::LibrarySignals::Provider;

my $prefs = Slim::Utils::Prefs::preferences('plugin.guidancelibrarysignals');

my @POLICY_KEYS = qw(
    playcount_influence
    album_playcount_influence
    artist_playcount_influence
    last_played_influence
    album_last_played_influence
    artist_last_played_influence
    last_played_horizon_days
    library_age_influence
    library_age_horizon_days
);

sub name {
    return 'PLUGIN_LIBRARYSIGNALS_NAME';
}

sub page {
    return 'plugins/LibrarySignals/settings/librarysignals.html';
}

sub prefs {
    return ($prefs, @POLICY_KEYS);
}

sub beforeRender {
    my ($class, $params) = @_;
    Plugins::LibrarySignals::Provider::init_preferences();
    $params->{provider_defaults} =
        Plugins::LibrarySignals::Provider::guidance_provider_defaults_v1();
    $params->{provider_status} =
        Plugins::LibrarySignals::Provider::guidance_provider_status_v1();
    $params->{alternative_play_count_available} =
        $params->{provider_status}->{alternative_play_count_available} ? 1 : 0;
    $params->{lab_available} = Plugins::LibrarySignals::Provider::_lab_available() ? 1 : 0;
    $params->{artist_identity_follow_fallback} = !$params->{lab_available}
        && ($prefs->get('artist_identity_mode') || 'follow_lab') eq 'follow_lab' ? 1 : 0;
    $params->{prefs}->{artist_identity_mode} = $params->{artist_identity_follow_fallback}
        ? 'shared_artist' : ($prefs->get('artist_identity_mode') || 'follow_lab');
    $params->{prefs}->{use_alternative_play_count} =
        $prefs->get('use_alternative_play_count') ? 1 : 0;
}

sub handler {
    my ($class, $client, $params) = @_;
    Plugins::LibrarySignals::Provider::init_preferences();
    my $changed = 0;
    if ($params->{saveSettings} && exists $params->{pref_artist_identity_mode}) {
        my $identity = $params->{pref_artist_identity_mode};
        my $lab_available = Plugins::LibrarySignals::Provider::_lab_available();
        my $hidden_follow = !$lab_available && ($prefs->get('artist_identity_mode') || 'follow_lab') eq 'follow_lab';
        if ($identity =~ /^(?:shared_artist|primary_artist)$/ || ($identity eq 'follow_lab' && $lab_available)) {
            unless ($hidden_follow && $identity eq 'shared_artist' && !$params->{artist_identity_changed}) {
                $prefs->set('artist_identity_mode', $identity);
                $changed = 1;
            }
        }
    }
    if ($params->{saveSettings}
        && Plugins::LibrarySignals::Provider::_alternative_play_count_available()) {
        my $value = exists $params->{pref_use_alternative_play_count} ? 1 : 0;
        if (($prefs->get('use_alternative_play_count') ? 1 : 0) != $value) {
            $changed = 1;
            $prefs->set('use_alternative_play_count', $value);
        }
    }
    for my $key (@POLICY_KEYS) {
        my $param = 'pref_' . $key;
        next unless exists $params->{$param};
        $changed = 1;
        $prefs->set($key, _clamp($key, $params->{$param}));
    }
    if ($changed) {
        my $revision = $prefs->get('settings_revision') || 1;
        $prefs->set('settings_revision', $revision + 1);
    }
    return $class->SUPER::handler($client, $params);
}

sub _clamp {
    my ($key, $value) = @_;
    my $descriptor = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
    my ($control) = grep { $_->{key} eq $key } @{$descriptor->{controls}};
    $value = $control->{factory_default}
        unless defined $value && $value =~ /^-?\d+$/;
    $value = int($value);
    $value = $control->{minimum} if $value < $control->{minimum};
    $value = $control->{maximum} if $value > $control->{maximum};
    return $value;
}

1;
