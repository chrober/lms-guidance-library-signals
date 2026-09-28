use strict;
use warnings;
use Test::More;
use lib '.';

{
    package TestPrefs;
    sub new { bless { values => {} }, shift }
    sub init {
        my ($self, $defaults) = @_;
        $self->{values}{$_} = $defaults->{$_}
            for grep { !exists $self->{values}{$_} } keys %$defaults;
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
}

require 'LibrarySignals/Provider.pm';

my $descriptor = Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
is($descriptor->{protocol_version}, 1, 'publishes descriptor protocol v1');
is($descriptor->{provider_id}, 'library-signals', 'publishes stable provider ID');
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

my $defaults = Plugins::LibrarySignals::Provider::guidance_provider_defaults_v1();
is($defaults->{playcount_influence}, 0, 'play-count factory default is neutral');
is($defaults->{last_played_influence}, 0, 'last-played factory default is neutral');
is($defaults->{library_age_influence}, 0, 'library-age factory default is neutral');
is($defaults->{last_played_horizon_days}, 180, 'last-played default horizon is 180 days');
is($defaults->{library_age_horizon_days}, 365, 'library-age default horizon is 365 days');

my $status = Plugins::LibrarySignals::Provider::guidance_provider_status_v1();
ok(!$status->{available}, 'unavailable binary/database reports inactive provider');

done_testing;
