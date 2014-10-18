=encoding utf8
=head1 NAME
 AurPac::CORE - glue things together
=cut

=head1 SYNOPSIS
 # all objects you need:
 my $all = AurPac::CORE->new(opt => val);
=cut

=head1 DESCRIPTION
=cut

package AurPac::CORE;

use strict;
use warnings;
use AurPac::CORE::pacman;
use AurPac::CORE::aur;
#use AurPac::CORE::cpan;

sub new {
    my $class = shift;
    my $self = {};
    
    while (my ($key, $val) = each @_) {
        defined $key
            and $self->{$key} = $val;
    }

    $self = bless($self, $class);

    $self->{aur}    = AurPac::CORE::aur->new(    \%{$self} );
#    $self->{cpan}   = AurPac::CORE::cpan->new(  \%{$self} );
    $self->{pacman} = AurPac::CORE::pacman->new( \%{$self} );

    $self->{config} = AurPac::CONFIG->new( \%{$self} );

    return $self;
}

package AurPac::CONFIG;
use parent qw/AurPac::CORE/;

sub new {
    my $class = shift;
    my $self = {parent => shift};
    return bless($self, $class)
}

1;
