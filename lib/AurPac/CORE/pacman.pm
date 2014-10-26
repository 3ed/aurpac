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

=head2 query

=head3 query_list

 return packages query array

 @pkgs = $core->{pacman}->query_list

=cut

sub query_list {
    my $self = shift;
    return $self->{alpm}->localdb->pkgs
}

=head3 query_filter_foreign

  return foreign packages from any packages array

  @pkgs = $core->{pacman}->query_filter_foreign($core->{pacman}->query_list)

=cut

sub query_filter_foreign {
    my ($self, @pkgs) = @_;
    my @foreign;
    my @syncdbs = $self->{alpm}->syncdbs;

=for comment TODO investigate
 perl -e '
   use AurPac::CORE;
   my $c = AurPac::CORE->new;
   printf("%s\n", $_->name)
       foreach (
           $c->{pacman}->query_filter_foreign(
               $c->{pacman}->query_list
           )
       )
 '|wc -l  
 -- gives: 148

 pacman -Qqm|wc -l
 -- gives: 150
=cut

    foreach my $pkg (@pkgs) {
        $self->{alpm}->find_dbs_satisfier($pkg->name, @syncdbs)
            or push @foreign, $pkg;
    }
    return @foreign;
}

=head3 query_filter_search

 search which works like filter (maybe slower but much more powerful), eg:

 @pkgs = $core->{pacman}->query_filter_search(
    [qw/one two/],
    [$core->{pacman}->query_filter_foreign(
        $core->{pacman}->query_list
    )]
 )

 return only this foreign packages that contains this two words/regexps! inside package name or desc

=cut

sub query_filter_search {
    my ($self, $query, $pkgs) = @_;

    npkg: for (my $npkg = 0; $npkg >= $#{$pkgs}; $npkg++) {
        str: foreach my $str (@{$query}) {
            unless (
                (@{$pkgs}[$npkg]->name =~ /$str/x)
                    or (@{$pkgs}[$npkg]->desc =~ /$str/x)
            ) {
                # remove 1 element at n
                splice @{$pkgs}, $npkg, 1;

                # move n to next after last not deleted
                $npkg--;

                # do next in npkg loop
                next npkg;
            }
        }
    }
    return @{$pkgs}
}

1;
