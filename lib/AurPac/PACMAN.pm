package AurPac::PACMAN;
use strict;
use warnings;
use utf8;

use ALPM::Conf;

sub new {
    my ($class, $config) = @_;

    my $self = {config => $config || undef};

    $self->{alpm_conf} =
    ALPM::Conf->new($self->{config}->{pacman_conf} || '/etc/pacman.conf');

    $self->{alpm} = $self->{alpm_conf}->parse;

    return bless($self, $class);
}

sub alpm {
    my $self = shift;
    return $self->{alpm}
}

sub vercmp {
    my ($self, $a, $b) = @_;
    return ALPM->vercmp($a, $b)
}

# TODO too much clumsy, rewrite...
# eg: $orphaned = $self->query_filtr_orphan($self->query_all("version"));
sub Qm {
    my ($self) = @_;

    my $local = {};
    $local->{$_->name} = $_->version foreach $self->{alpm}->localdb->pkgs;

    foreach my $db ($self->{alpm}->syncdbs) {
        foreach my $repo ($self->{alpm}->register($db->name)) {
            foreach my $pkg ($repo->pkgs) {
                defined $local->{$pkg->name} and delete $local->{$pkg->name}
            }
        }
    }

    return $local
}

1;
