#!/usr/bin/perl
# Loads the bundled IsletMedia.dylib into the Apple-signed perl process.
# MediaRemote only exposes browser now-playing data to that process on
# macOS 15.4+. Called by Islet; not meant to be run by hand.

use strict;
use warnings;
use DynaLoader;

my $library = shift @ARGV;
my $mode = shift @ARGV // 'stream';

my $handle = DynaLoader::dl_load_file($library, 0)
    or die "IsletMedia: could not load library\n";

sub load_function {
    my ($name) = @_;
    my $symbol = DynaLoader::dl_find_symbol($handle, $name)
        or die "IsletMedia: missing symbol $name\n";
    return DynaLoader::dl_install_xsub("main::$name", $symbol);
}

if ($mode eq 'stream') {
    my $stream = load_function('islet_stream');
    &$stream();
} elsif ($mode eq 'command') {
    my $command = load_function('islet_command');
    &$command($ARGV[0]);
} elsif ($mode eq 'seek') {
    my $seek = load_function('islet_seek');
    &$seek($ARGV[0]);
}
