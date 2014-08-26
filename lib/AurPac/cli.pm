package AurPac::cli;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use Carp;

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

    require AurPac::cli::aur;

    defined $self->{aur} 
        or $self->{aur} = AurPac::cli::aur->new($self->{config})
        or croak __PACKAGE__."->aur: child module not loaded";

    return $self->{aur}
}

sub sysupdate {
    my ($self) = @_;

    # pacman -Sy
    $self->pacman->sysupdate;

    # [aur like] -Sy
    $self->pacman->has_query("foreign")
        or $self->pacman->set_query("foreign");
    $self->aur->sysupdate($self->pacman->get_query);

    return 1
}

sub sysupgrade {
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
