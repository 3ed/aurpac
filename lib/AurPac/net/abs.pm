package AurPac::net::abs;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

sub new { 
    # TODO z arch zrobic tablice: qw/i686 any/
    # TODO dodac: verbose=0|1
    # TODO dodac: SyncTo

    my ($class, $arch) = @_;
    die("AurPac::net::abs->new(cpu_arch): cpu_arch is needed...\n") unless defined $arch;

    my $self = {};

    $self->{rsyncCmd} = "/usr/bin/rsync";

    @{$self->{rsyncArgs}} = (
        "--prune-empty-dirs",
        "--recursive",
        "--times",
        "--no-motd",
        "--delete-after",
        "--no-p",
        "--no-o",
        "--no-g",
        "--verbose"
    );

    @{$self->{SyncFrom}} = (
        'rsync.archlinux.org::abs/'.$arch.'/',
        'rsync.archlinux.org::abs/any/'
    );

    $self->{SyncTo} = "/var/tmp/aurpac-".$un."/abs/";

    return bless($self, $class);
}

sub pbget {
    my ($self, $n, $r) = @_;

    unless (defined $r) {
        $r = $self->determine_repo($n) or return;
    }

    system (
        $self->{rsyncCmd},
        @{$self->{rsyncArgs}},
        '--include=/'.$r,
        '--include=/'.$r.'/'.$n,
        '--exclude=/'.$r.'/*',
        '--exclude=/*',
        @{$self->{SyncFrom}},
        $self->{SyncTo}
    ) and return;

    return unless(-f $self->{SyncTo}.'/'.$r.'/'.$n.'/PKGBUILD');
    return $self->{SyncTo}.'/'.$r.'/'.$n
}

sub pbget_all {
    my ($self) = @_;

    system (
        $self->{rsyncCmd},
        @{$self->{rsyncArgs}},
        @{$self->{SyncFrom}},
        $self->{SyncTo}
    ) and return;

    return "$self->{SyncTo}"

}
sub determine_repo {
    my ($self, $n) = @_;

    warn "AurPac::net::abs->determine_repo(pkgname): Not implemented yet..";
    return
}

1;
