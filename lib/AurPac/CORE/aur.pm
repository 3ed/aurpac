package AurPac::CORE::aur;
use strict;
use warnings;
#use parent qw/AurPac::CORE/;

sub new {
    my $class = shift;
    return bless({parent => shift}, $class);
}

sub parent { shift->{parent} }

1;
