package Plugins::LibrarySignals::Plugin;

use strict;
use base qw(Slim::Plugin::Base);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use Plugins::LibrarySignals::Provider;

sub getDisplayName { return 'PLUGIN_LIBRARYSIGNALS_NAME'; }

sub initPlugin {
    my $class = shift;
    Plugins::LibrarySignals::Provider::init_preferences();
    _load_strings();
    if (main::WEBUI) {
        require 'Plugins/LibrarySignals/Settings.pm';
        Plugins::LibrarySignals::Settings->new;
    }
    $class->SUPER::initPlugin();
}

sub _load_strings {
    my $path = catfile(dirname(__FILE__), 'strings.txt');
    return unless -r $path;
    eval {
        require Slim::Utils::Strings;
        Slim::Utils::Strings::loadFile($path);
    };
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
