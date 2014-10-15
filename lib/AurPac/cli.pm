package AurPac::cli;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use Carp;
use AurPac::Version;
use AurPac::AUR;
use AurPac::PACMAN;

# TODO Może pacmana wstawić tutaj? Będzie mniej zachodu z kombinowaniem..
#      Poprostu: my $foreign = $self->pacman( ipc => 1, argv => "-Qqm" );

sub new {
    my ($class, %opts) = @_;
    my $self = {};

    while (my ($a, $b) = each %opts) {
        $self->{$a} = $b;
    }

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
    1;
}

sub usage {
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
    1;
}

sub pacman {
    my ($self) = @_;

    require AurPac::cli::pacman;

    defined $self->{pacman}
        or $self->{pacman} = AurPac::cli::pacman->new($self->{config})
        or croak __PACKAGE__."->pacman: child module not loaded";

    return $self->{pacman}
}

sub aur {
    my ($self) = @_;

    defined $self->{aur} 
        or $self->{aur} = AurPac::AUR->new($self->{config})
        or croak __PACKAGE__."->aur: child module not loaded";

    return $self->{aur}
}

sub update {
    my ($self) = @_;

    $self->pacman->update();
    $self->aur->update();
    $self->cpan->update();

    return 1
}

sub upgrade {
    my ($self) = @_;

    # pacman -Su
    $self->pacman->sysupdate;

    # [aur like] -Su
    $self->aur->sysupdate;

    return 1

}

sub search { # TODO
    my ($self, $what, @where) = @_;

    $self->pacman->search($format, @what);
    $self->aur->search($format, @what);
    $self->cpan->search($format, @what);

    return 1
}
