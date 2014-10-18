package AurPac::CORE::pacman;
use strict;
use warnings;
use utf8;

use ALPM::Conf;

sub new {
    my ($class, $parent) = @_;

    my $self = {parent => $parent};

    $self->{alpm_conf} = ALPM::Conf->new(
        $self->{parrent}->{config}->{pacman_conf} || '/etc/pacman.conf'
    );

    $self->{alpm} = $self->{alpm_conf}->parse;

    return bless($self, $class);
}

sub parent { shift->{parent} }

sub alpm {
    my $self = shift;
    return $self->{alpm}
}

sub vercmp {
    my ($self, $a, $b) = @_;
    return ALPM->vercmp($a, $b)
}

=head2 list_sync_upgrades

 all packages that need to be upgaded or downgraded (eg. for warning message)

 output:
 { 
   upgrades => [
     {
       'repo'  => <blessed ALPM::Package object>,
       'local' => <blessed ALPM::Package object>
     },
     {
       ..........
     }
   ],
   downgrades => [
     { ........ }
   ]
 }

=cut

sub list_sync_upgrades {
    my $self = shift;
    my $upgrades = {};

    db: foreach my $db ($self->{alpm}->syncdbs) {
        repo: foreach my $repo ($self->{alpm}->register($db->name)) {
            pkg: foreach my $pkg ($repo->pkgs) {
                if (defined (my $local = $self->{alpm}->localdb->find($pkg->name))) {
                    my $vercmp = $self->vercmp($pkg->version, $local->version);
                    if ($vercmp == 0) {
                        next pkg;
                    } elsif ($vercmp == 1) {
                        $vercmp = "upgrades";
                    } else {
                        $vercmp = "downgrades";
                    }

                    push @{$upgrades->{$vercmp}}, {
                        repo  => $pkg,
                        local => $local
                    };
                }
            }
        }
    }
    return $upgrades
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
