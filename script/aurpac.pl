#!/usr/bin/perl
$|=1;

use v5.18;
use strict;
use warnings;
use AurPac::AUR;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

my $aur = AurPac::AUR->new;

# TODO move that to AurPac::cli
loop(@ARGV);

sub loop {
    my (@argv) = @_;
    my $mode = shift @argv || "";
    given($mode) {
        when("search") {
            my $depth = 3;
            if ($argv[0] =~ m/^-([0-4])$/) {
                $depth = $1;
                shift @argv;
            }
            $aur->search($depth, @argv);
        }
        when("update") {
            loop("update-alpm", @argv);
            loop("update-aur", @argv);
            loop("update-cpan", @argv);
        }
        when("update-alpm") {
            print "update-alpm: not implemented yet...\n";
        }
        when("update-aur") {
            print $_->[0]." " foreach ($aur->aur_update(1));
            print "\b\n";
        }
        when("update-cpan") {
            $aur->cpan_update(1);
        }
        when("pbget") {
            $aur->prepare_aursrc($_) foreach @argv;
        }
        default {
            usage();
        }
    }
    return 1
}

sub usage {
    require AurPac::Version;
    my $ver = AurPac::Version->new->ver;
    print <<EOF
aurpac $ver (c) 3ED @ terms of GPL3

WARNING: THIS IS FIRST PRE! ALPHA VERSION.

USAGE:
    aurpac [mode] [args]

MODES:
    update          invoke all „update-*” modes
    update-aur      update only aur packages
    update-cpan     update cpan packages
    pbget           get this pkgbuilds from aur
    search          search, and args:
        -0, .., -4  from quiet to verbosity
EOF
}

