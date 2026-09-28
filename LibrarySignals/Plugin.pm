package Plugins::LibrarySignals::Plugin;

use strict;
use base qw(Slim::Plugin::Base);
require 'LibrarySignals/Provider.pm';

sub getDisplayName { return 'PLUGIN_LIBRARYSIGNALS_NAME'; }

sub initPlugin {
    my $class = shift;
    Plugins::LibrarySignals::Provider::init_preferences();
    if (main::WEBUI) {
        require 'LibrarySignals/Settings.pm';
        Plugins::LibrarySignals::Settings->new;
    }
    $class->SUPER::initPlugin();
}

sub guidance_provider_descriptor_v1 {
    return Plugins::LibrarySignals::Provider::guidance_provider_descriptor_v1();
}

sub guidance_provider_defaults_v1 {
    return Plugins::LibrarySignals::Provider::guidance_provider_defaults_v1();
}

sub guidance_provider_status_v1 {
    return Plugins::LibrarySignals::Provider::guidance_provider_status_v1();
}

sub guidance_provider_native_spi_config_v1 {
    return Plugins::LibrarySignals::Provider::guidance_provider_native_spi_config_v1(@_);
}

1;
