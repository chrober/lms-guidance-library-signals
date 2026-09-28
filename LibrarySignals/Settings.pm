package Plugins::LibrarySignals::Settings;

use strict;
use warnings;
use base qw(Slim::Web::Settings);
use Slim::Utils::Prefs;

require 'LibrarySignals/Provider.pm';

my $prefs = Slim::Utils::Prefs::preferences('plugin.guidancelibrarysignals');

my @POLICY_KEYS = qw(
    playcount_influence
    last_played_influence
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
}

sub handler {
    my ($class, $client, $params) = @_;
    Plugins::LibrarySignals::Provider::init_preferences();
    my $changed = 0;
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
