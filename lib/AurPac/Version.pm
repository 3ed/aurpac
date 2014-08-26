package AurPac::Version;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use version; our $VERSION = qv(0.1.8.12.2);

sub new {
    return bless(
        {
            Version => $VERSION,
            Stage => "predev",
            CodeName => "Tardy_Snail",
            Name => "aurpac-ng"
        },
        shift
    )
}

sub name {
    my ($self) = @_;
    return $self->{Name};
}

sub ver {
    my ($self) = @_;
    return $self->{Version};
}

sub ua {
    my ($self) = @_;
    return sprintf("%s/%s%s", $self->{Name}, $self->{Stage}, $self->{Version});
}

1;
