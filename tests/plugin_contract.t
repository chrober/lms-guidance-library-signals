use strict;
use warnings;
use Test::More;
use lib '.';

{
    package TestPrefs;
    sub new { bless { values => {} }, shift }
    sub init { }
    sub get { $_[0]->{values}->{$_[1]} }
    sub set { $_[0]->{values}->{$_[1]} = $_[2] }

    package Slim::Utils::Prefs;
    my %prefs;
    sub preferences { $prefs{$_[0]} ||= TestPrefs->new }
    $INC{'Slim/Utils/Prefs.pm'} = __FILE__;

    package Slim::Plugin::Base;
    sub import { }
    sub initPlugin { 1 }
    $INC{'Slim/Plugin/Base.pm'} = __FILE__;

    package main;
    sub WEBUI { 0 }
}

require 'LibrarySignals/Provider.pm';
$INC{'Plugins/LibrarySignals/Provider.pm'} = $INC{'LibrarySignals/Provider.pm'};
require 'LibrarySignals/Plugin.pm';

is(Plugins::LibrarySignals::Plugin->getDisplayName,
    'PLUGIN_LIBRARYSIGNALS_NAME',
    'plugin publishes the localized provider name');
my $descriptor = Plugins::LibrarySignals::Plugin->guidance_provider_descriptor_v1;
is($descriptor->{provider_id}, 'library-signals',
    'plugin forwards the public provider descriptor');

done_testing;
