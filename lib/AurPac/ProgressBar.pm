package AurPac::ProgressBar;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";
use Term::ReadKey qw(GetTerminalSize);

sub new {
    my ($class, $config) = @_;
    
    my $self = {
        config => $config,
        term => {
            cols => ((GetTerminalSize())[0])
        }
    };
    #defaults
    $self->{colors}->{results} ||= "\e[0;34;1m"; #TODO nie result a counter
    $self->{colors}->{reset}   ||= "\e[0m";
    $self->{term}->{cols}      ||= ((GetTerminalSize())[0]);

    $self->{_pbar} = {
        max => 100,
        min => 0,
        msg => "Work in progress...",
        lazy_refresh => 0,
        pbar_width => 30,
        show_pbar => 1,
        show_proc => 1,
        show_pulsate => 0,
        show_timeout => 1,
        show_counter => 1
    };

    return bless($self, $class);
}


sub print { # /simple just print/   deprached!!
    my ($self, $msg, $count, $max) = @_;

    $self->{_pbar}->{msg}   = $msg   if (defined $msg);
    $self->{_pbar}->{count} = $count if (defined $count);
    $self->{_pbar}->{max}   = $max   if (defined $max);

    $self->refresh;
    $self->show;

    $self->end(1) if ($self->{_pbar}->{count} eq $self->{_pbar}->{max});

    return 1
}

sub set {
    my ($self, @opts) = @_;

    for (my $c = 0 ; $c <= $#opts ; $c += 2) {
        my $n = $c + 1;
        my $opt = $opts[$c] or next;
        my $arg = $opts[$n] or next;
        defined $self->{_pbar}->{$opt} or next;

        $self->{_pbar}->{$opt} = $arg;
    }

    return $self
}

sub get {
    my ($self, @opts) = @_;
    my @get;

    push @get, $self->{_pbar}->{$_} || undef foreach (@opts);

    return @get
}

sub next {
    my ($self, $msg) = @_;
    $self->{_pbar}->{count}++;
    $self->{_pbar}->{msg} = $msg if defined $msg;
    $self->refresh;
    return $self
}

sub nl {
    my ($self) = @_;
    print "\n";
    return $self
}

sub end {
    my ($self, $nl) = @_;
    $self->nl if defined $nl;
    undef $self->{__pbar};
    return $self
}

sub refresh { # rename to „build”?
    my ($self) = @_;

    # correcting counter
    $self->{_pbar}->{count} ||= $self->{_pbar}->{min};

    if ($self->{_pbar}->{count} > $self->{_pbar}->{max}) {
        $self->{_pbar}->{count} = $self->{_pbar}->{max};
    } elsif ($self->{_pbar}->{count} < $self->{_pbar}->{min}) {
        $self->{_pbar}->{count} = $self->{_pbar}->{min};
    }


    # setup time (ETA, lazy)
    my $time_now = time();

    $self->{__pbar}->{started_at}  ||= $time_now;
    $self->{__pbar}->{last_update} ||= $time_now;

    # lazy refresh
    return ("no need to refresh") if (
        ($self->{_pbar}->{lazy_refresh}) && 
        ($self->{__pbar}->{started_at} ne $self->{__pbar}->{last_update}) &&
        ($self->{_pbar}->{count} ne $self->{_pbar}->{max}) &&
        ($time_now eq $self->{__pbar}->{last_update})
    );

    # updating time (ETA, lazy)
    $self->{__pbar}->{last_update} = $time_now;

    return $self->_do_all
}

sub show { # rename to „draw”?
    my ($self) = @_;
    printf("\r%s", $self->{progressbar_line});
    return $self
}

sub hide { # rename to „cleanup”?
    my ($self) = @_;
#    printf("\r%$self->{term}->{cols}s\r", "");
    print "\r\e[K";
    return $self
}

sub _do_pbar {
    my ($self) = @_;
    
    return unless ($self->{_pbar}->{show_pbar});

    my $width;
    if (defined $self->{__pbar}->{width_bar}) {
        $width = $self->{__pbar}->{width_bar};
    } else {
        $width = sprintf("%.f", ($self->{term}->{cols} * ($self->{_pbar}->{pbar_width} / 100)) );
        $width -= 2;
        $self->{__pbar}->{width_bar} = $width;
    }

    my $proc = (($self->{_pbar}->{count} / $self->{_pbar}->{max}) *  100);
    my $left = sprintf("%.f", ($width * ($proc / 100)) );

    return sprintf( " [%s%s]", ("#" x $left), ("-" x ($width - $left)) );
}

sub _do_proc {
    my ($self) = @_;

    return unless ($self->{_pbar}->{show_proc});
    return sprintf(
        " %3d%%",
        sprintf(
            "%.f",
            (($self->{_pbar}->{count} / $self->{_pbar}->{max}) *  100)
        )
    );
}

sub _do_pulsate {
    my ($self) = @_;

    return unless ($self->{_pbar}->{show_pulsate});

    unless (defined $self->{__pbar}->{pulsate_char}) {
        @{$self->{__pbar}->{pulsate_chars}} = qw:\|/-:;
        $self->{__pbar}->{pulsate_char} = 0;
    }

    if ($self->{__pbar}->{pulsate_char} > $#{$self->{__pbar}->{pulsate_chars}}) {
        $self->{__pbar}->{pulsate_char} = 0;
    }

    my $char = @{$self->{__pbar}->{pulsate_chars}}[$self->{__pbar}->{pulsate_char}];

    $self->{__pbar}->{pulsate_char}++;

    return " ".$char;
}

sub _do_timeout {
    my ($self) = @_;

    return unless ($self->{_pbar}->{show_timeout});

    defined $self->{__pbar}->{started_at} or return;
    defined $self->{__pbar}->{last_update} or return;

    return if ($self->{__pbar}->{last_update} eq $self->{__pbar}->{started_at});

    # this ETA: time left after start
    my $ETA = ($self->{__pbar}->{last_update} - $self->{__pbar}->{started_at});

    unless ($self->{_pbar}->{max} eq $self->{_pbar}->{count}) {
        # this ETA: time left to the end
        $ETA = sprintf("%.f",
            (($ETA / $self->{_pbar}->{count}) * ($self->{_pbar}->{max} - $self->{_pbar}->{count}))
        );
    }


    if ($ETA >= 60) {
        my $ETA_m = int($ETA / 60);
        my $ETA_s = int($ETA - ($ETA_m * 60));
        return sprintf(" %02d:%02d", $ETA_m, $ETA_s);
    } else {
        return sprintf(" 00:%02d", int $ETA);
    }
}

sub _do_counter {
    my ($self) = @_;

    return unless ($self->{_pbar}->{show_counter});

    my $count_cols = length $self->{_pbar}->{max};

    return sprintf("(%${count_cols}d/%d) ",
        $self->{_pbar}->{count},
        $self->{_pbar}->{max}
    );
}

sub _do_msg {
    my ($self, $width) = @_;

    $width ||= $self->{__pbar}->{width_msg} || $self->{term}->{cols};

    if ( $width > (length $self->{_pbar}->{msg}) ) {
        return sprintf("%-${width}s", $self->{_pbar}->{msg});
    } elsif ( $width < (length $self->{_pbar}->{msg}) ) {
        $width -= 3;
        return sprintf("%.${width}...s", $self->{_pbar}->{msg});
    }

    return $self->{_pbar}->{msg}

}

sub _do_all {
    my ($self) = @_;

    my $left = $self->_do_counter;
    my @right = ($self->_do_timeout, $self->_do_pbar, $self->_do_pulsate, $self->_do_proc);

    my $width = $self->{term}->{cols};
    $width -= (length $_) || 0 foreach($left, @right);

    my $msg = $self->_do_msg($width);

    if (defined $left) {
        $self->{progressbar_line} = $self->{colors}->{results}.$left.$self->{colors}->{reset};
    } else {
        $self->{progressbar_line} = "";
    }

    $self->{progressbar_line} .= $_ foreach($msg, @right);

    return $self
}

1;
