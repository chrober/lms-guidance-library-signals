use strict;
use warnings;
use Test::More;
use lib '.';

{
    package TestPrefs;
    sub new { bless { values => {} }, shift }
    sub init {
        my ($self, $defaults) = @_;
        $self->{values}->{$_} = $defaults->{$_}
            for grep { !exists $self->{values}->{$_} } keys %{$defaults};
    }
    sub get { $_[0]->{values}->{$_[1]} }
    sub set { $_[0]->{values}->{$_[1]} = $_[2] }

    package Slim::Utils::Prefs;
    my %prefs;
    sub preferences { $prefs{$_[0]} ||= TestPrefs->new }
    $INC{'Slim/Utils/Prefs.pm'} = __FILE__;

    package Slim::Web::Settings;
    sub import { }
    sub new { bless {}, shift }
    sub handler { return 1 }
    $INC{'Slim/Web/Settings.pm'} = __FILE__;

    package Slim::Utils::PluginManager;
    our @ENABLED = ('Plugins::AlternativePlayCount::Plugin');
    sub enabledPlugins { return @ENABLED }
    $INC{'Slim/Utils/PluginManager.pm'} = __FILE__;

    package Slim::Utils::Strings;
    sub string { return $_[0] }
    $INC{'Slim/Utils/Strings.pm'} = __FILE__;
}

require 'LibrarySignals/Provider.pm';
$INC{'Plugins/LibrarySignals/Provider.pm'} = $INC{'LibrarySignals/Provider.pm'};
require 'LibrarySignals/Settings.pm';

is(Plugins::LibrarySignals::Settings->name, 'PLUGIN_LIBRARYSIGNALS_NAME',
    'provider has its own settings-page title');
is(Plugins::LibrarySignals::Settings->page,
    'plugins/LibrarySignals/settings/librarysignals.html',
    'provider owns a separate settings template');
ok(Plugins::LibrarySignals::Settings->prefs,
    'settings page owns a provider preference namespace');

my $descriptor = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
my %render_as = map { $_->{key} => $_->{render_as} } @{$descriptor->{controls}};
my %control_type = map { $_->{key} => $_->{type} } @{$descriptor->{controls}};
is($control_type{use_alternative_play_count}, 'boolean',
    'APC source is published to host settings as a checkbox');
is($render_as{playcount_influence}, 'slider',
    'play-count influence declares the slider UI used on the provider page');
is($render_as{last_played_horizon_days}, 'number',
    'last-played horizon declares the plain numeric UI used on the provider page');
is($render_as{library_age_horizon_days}, 'number',
    'library-age horizon declares the plain numeric UI used on the provider page');

open my $template, '<', 'LibrarySignals/HTML/EN/plugins/LibrarySignals/settings/librarysignals.html'
    or die "Cannot read settings template: $!";
my $template_source = do { local $/; <$template> };
like($template_source, qr/\[% PROCESS settings\/footer\.html %\]/,
    'settings template includes the standard footer with its Save button');
like($template_source, qr/pref_use_alternative_play_count/,
    'settings page exposes the provider-owned Alternative Play Count source checkbox');
like($template_source, qr/alternative_play_count_available/,
    'settings page renders the Alternative Play Count availability state');
like($template_source, qr/alternative_play_count_fallback/,
    'settings page reports when a saved APC preference falls back to native Lyrion data');
like($template_source, qr/name="pref_artist_identity_mode"/, 'settings page exposes artist identity');
like($template_source, qr/IF lab_available/, 'follow Lab choice is only shown while Lab is available');
my @groups = map { $_->{group_label_token} || '' } @{$descriptor->{controls}};
is_deeply([grep { length } @groups], [
    ('GUIDANCE_LIBRARY_SIGNALS_GROUP_SHARED') x 2,
    ('GUIDANCE_LIBRARY_SIGNALS_GROUP_TRACKS') x 4,
    ('GUIDANCE_LIBRARY_SIGNALS_GROUP_ALBUMS') x 2,
    ('GUIDANCE_LIBRARY_SIGNALS_GROUP_ARTISTS') x 3,
], 'provider controls declare ordered shared, track, album and artist groups');
for my $group (qw(SHARED TRACKS ALBUMS ARTISTS)) {
    like($template_source, qr/GUIDANCE_LIBRARY_SIGNALS_GROUP_$group/, "$group section is present on provider settings page");
}
for my $group (qw(TRACKS ALBUMS ARTISTS)) {
    like($template_source, qr{<br/><hr style="opacity:0\.4" class="sub-sep"/><br/>\s*<h4>\[% "GUIDANCE_LIBRARY_SIGNALS_GROUP_$group"}, "$group follows a Bliss Mixer-style separator");
}
open my $strings, '<:encoding(UTF-8)', 'LibrarySignals/strings.txt' or die $!;
my $translations = do { local $/; <$strings> };
like($translations, qr/GUIDANCE_LIBRARY_SIGNALS_PLAYCOUNT_INFLUENCE\s+EN\s+Track play-count influence\s+DE\s+Einfluss der Titelwiedergaben/, 'play-count label identifies tracks in both languages');
like($translations, qr/GUIDANCE_LIBRARY_SIGNALS_LAST_PLAYED_INFLUENCE\s+EN\s+Track last-played influence\s+DE\s+Einfluss der letzten Titelwiedergabe/, 'last-played label identifies tracks in both languages');
for my $key (qw(album_playcount_influence artist_playcount_influence album_last_played_influence artist_last_played_influence)) {
    like($template_source, qr/name="pref_$key"/, "$key has a provider-owned setting");
    is($render_as{$key}, 'slider', "$key uses the same slider style in hosts");
}
unlike($template_source, qr/<h3>\s*\[%\s*"PLUGIN_LIBRARYSIGNALS_STATUS"/,
    'settings page does not show a provider status section');
my $prefs = Slim::Utils::Prefs::preferences('plugin.guidancelibrarysignals');
$prefs->set('artist_identity_mode', 'follow_lab');
@Slim::Utils::PluginManager::ENABLED = ();
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1 });
is($prefs->get('artist_identity_mode'), 'follow_lab', 'hidden follow Lab preference survives saving while Lab is unavailable');
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1, pref_artist_identity_mode => 'shared_artist' });
is($prefs->get('artist_identity_mode'), 'follow_lab', 'displayed fallback does not overwrite a hidden follow preference');
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1, pref_artist_identity_mode => 'shared_artist', artist_identity_changed => 1 });
is($prefs->get('artist_identity_mode'), 'shared_artist', 'an explicit selection of the displayed fallback replaces the hidden follow preference');
$prefs->set('artist_identity_mode', 'follow_lab');
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1, pref_artist_identity_mode => 'primary_artist' });
is($prefs->get('artist_identity_mode'), 'primary_artist', 'artist identity can be explicitly overridden');
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1, pref_album_playcount_influence => -60 });
is($prefs->get('album_playcount_influence'), -60, 'saving persists the aggregate influence');
$prefs->set('use_alternative_play_count', 1);
@Slim::Utils::PluginManager::ENABLED = ();
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1 });
is($prefs->get('use_alternative_play_count'), 1,
    'saving while APC is unavailable preserves its hidden provider setting');
@Slim::Utils::PluginManager::ENABLED = ('Plugins::AlternativePlayCount::Plugin');
Plugins::LibrarySignals::Settings->handler(undef, { saveSettings => 1 });
is($prefs->get('use_alternative_play_count'), 0,
    'when APC is available, saving an unchecked control disables the setting');

done_testing;
