package AurPac::cli;
use v5.18;
no if $] >= 5.018, warnings => "experimental::smartmatch";

use Carp;
use AurPac::CORE;

sub new {
    my ($class, %opts) = @_;
    my $self = {};

    while (my ($a, $b) = each %opts) {
        $self->{config}->{$a} = $b;
    }

    $self->{core} = AurPac::CORE->new(\%{$self->{config}});

    return bless($self, $class)
}

sub run {
    my ($self, $mode, @argv) = @_;

    given($mode) {
        when("search") {
            my $depth = 3;
            if ($argv[0] =~ m/^-([0-4])$/) {
                $depth = $1;
                shift @argv;
            }
            $self->search($depth, @argv);
        }
        when("update") {
            print $_->[0]." " foreach ($self->update(1));
            print "\b\n";
        }
        when("update-alpm") {
            print "update-alpm: not implemented yet...\n";
        }
        when("update-aur") {
            print $_->[0]." " foreach ($self->aur->update(1));
            print "\b\n";
        }
#        when("update-cpan") { $self->cpan_update(1) }
        when("pbget")       { $self->aur->prepare($_) foreach @argv }
        default             { $self->usage }
    }
    return 1;
}

sub usage {
    my $self = shift;
    my $ver = $self->{core}->{Version};

    print <<EOF
aurpac $ver (c) 3ED @ terms of GPL3

WARNING: THIS IS FIRST PRE! ALPHA VERSION.

USAGE:
    ap [MODE] [ARGS]

    ap [-h|--help]
    ap [MODE] [-h|--help]

MODES:
    update          invoke all „update-*” modes
    update-aur      update only aur packages
    update-cpan     update cpan packages
    pbget           get this pkgbuilds from aur
    search          search, and args:
        -0, .., -4  from quiet to verbosity
EOF
}

sub pacman {
    my ($self) = @_;
    return $self->{core}->{pacman}
}

sub aur {
    my ($self) = @_;
    return $self->{core}->{aur}
}

sub update {
    my ($self) = @_;

#    $self->pacman->update();
#    $self->aur->update();
#    $self->cpan->update();

    return [1]
}

sub upgrade {
    my ($self) = @_;

#    # pacman -Su
#    $self->pacman->sysupdate;
#
#    # [aur like] -Su
#    $self->aur->sysupdate;

    return [1]

}

sub search { # TODO
    my ($self, $format, @what) = @_;

    $self->pacman->search($format, @what);
    $self->aur->search($format, @what);
    $self->cpan->search($format, @what);

    return 1
}

1;
