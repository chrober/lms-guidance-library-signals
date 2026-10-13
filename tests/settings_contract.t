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
    $INC{'Slim/Web/Settings.pm'} = __FILE__;

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

done_testing;
