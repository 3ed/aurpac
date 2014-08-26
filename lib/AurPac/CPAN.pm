package AurPac::CPAN;
use strict;
use warnings;
use feature q/switch/;

sub new {
    my ($class, $config) = @_;

    my $self = {};

    $self->{config} = $config || {};

    return bless($self, $class);
}

sub net {
    my $self = shift;

    require AurPac::net;

    defined $self->{net}
        or $self->{net} = AurPac::net->new(\%{$self->{config}});

    return $self->{net}
}

sub get_api {
    my ($self, @param) = @_;

    ($#param >= 0)
        or return;

    return $self->net->cpan_api(@param);
}

sub get_meta {
    my ($self, @param) = @_;

    ($#param >= 0)
        or return;

    return $self->net->cpan_meta(@param);
}

# TODO
sub create_pkgbuild {
    my ($self, $dist) = @_;

    my $cpan_api = $self->get_api("dist", $dist) or die;
    my $cpan_meta = $self->get_meta(
        $dist,
        $cpan_api->{releases}->[0]->{version},
        $cpan_api->{releases}->[0]->{cpanid}
    );

    my $pkgname = "perl-" . lc($dist);
    my $_lastauthor = substr($cpan_api->{releases}->[0]->{cpanid}, 0, 1) . "/"
                    . substr($cpan_api->{releases}->[0]->{cpanid}, 0, 2) . "/"
                    . $cpan_api->{releases}->[0]->{cpanid};

    my $licenses;
    given($#{$cpan_meta->{license}}) {
        when(-1) {
            $licenses = "()";
        };
        when(0) {
            $licenses = "('" . $cpan_meta->{license}->[0] . "')";
        };
        default {
            $licenses = "('" . join("' '", @{$cpan_meta->{license}}) . "')";
        };
    };

    my (@makedepends, $makedepends);
    for my $type (keys $cpan_meta->{prereqs}->{build}) {
        for my $pkg (keys $cpan_meta->{prereqs}->{build}->{type}) {
            if ($cpan_meta->{prereqs}->{build}->{type}->{pkg}) {
                push @makedepends, $pkg . ">=" . $cpan_meta->{prereqs}->{build}->{type}->{pkg};
            } else {
                push @makedepends, $pkg;
            }
        }
    }
    given($#makedepends) {
        when(-1) {
            $makedepends = "('perl')";
        };
        when(0) {
            $makedepends = "('" . $makedepends[0] . "')";
        };
        default {
            $makedepends = "('" . join("' '", @makedepends) . "')";
        };
    };

    print <<EOF
pkgname=$pkgname
_lastauthor=$_lastauthor
_pkgname=$dist
pkgver=$cpan_api->{releases}->[0]->{version}
pkgrel=1
pkgdesc=$cpan_meta->{abstract}
arch=('i686' 'x86_64')
license=$licenses
options=('!emptydirs')
makedepends=$makedepends
EOF

}

1;

__END__
=head1 TODO

 Funkcje:
   - create_pkgbuild - z get_meta będzie można automatycznie wygenerować pkgbuild

=cut
