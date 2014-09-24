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

=head2 list_sync_upgrades

 all packages that need to be upgaded

 output: [ my_name, sync_do, local_ver, repo_ver ]
   my_name   - package name
   ssync_do  - "u"(pgrade) or "d"(owngrade)
   local_ver - ver from query db
   repo_ver  - ver from sync db

=cut

sub list_sync_upgrades {
    my $self = shift;
    my @upgrades;

    foreach my $db ($self->{alpm}->syncdbs) {
        foreach my $repo ($self->{alpm}->register($db->name)) {
            foreach my $pkg ($repo->pkgs) {
                if (defined (my $local = $self->{alpm}->localdb->find($pkg->name))) {
                    my $vercmp = $self->vercmp($pkg->version, $local->version);
                    ($vercmp != 0)
                        and push @upgrades, [
                            $pkg->name,
                            ($vercmp == 1) ? "u" : "d",
                            $local->version,
                            $pkg->version
                        ];
                }
            }
        }
    }
    return @upgrades
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
