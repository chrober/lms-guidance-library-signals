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

done_testing;
