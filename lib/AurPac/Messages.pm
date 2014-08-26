package AurPac::Messages;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use Term::ReadKey qw(GetTerminalSize);

=head1 NAME

    AurPac::Messages - generate cli output messages

=head1 SYNOPSIS

    use AurPac::Messages
    my $msg = AurPac::Messages->new(\$config);
    $msg->print(1, "Normal message", 1);

=head1 METHODS

=head2 Object constructor

=head4 $msg = AurPac::Messages->new($config)

    $config is not implemented yet, put there your config hash (or reference)..

=head2 Other objects

=cut

sub new {
    my ($class, $config) = @_;
    
    my $self = {
        config => $config,
        term => {
            cols => ((GetTerminalSize())[0])
        }
    };
    #defaults
    $self->{colors}->{arrow}   ||= "\e[0;32;1m";
    $self->{colors}->{arrow2}  ||= "\e[0;34;1m";
    $self->{colors}->{msg}     ||= "\e[0;1m";
    $self->{colors}->{msg2}    ||= "\e[0;1m";
    $self->{colors}->{reset}   ||= "\e[0m";
    $self->{colors}->{results} ||= "\e[0;32;1m";
    $self->{colors}->{results1}||= "\e[0;34;1m";
    $self->{colors}->{results2}||= "\e[0;33;1m";
    $self->{colors}->{results3}||= "\e[0;31;1m";
    $self->{colors}->{warning} ||= "\e[0;33;1m";
    $self->{colors}->{error}   ||= "\e[0;31;1m";

    return bless($self, $class);
}

sub cl {
# Clear Line
    my $self = shift;
    print $self->{colors}->{reset} . "\r\e[K";
    #printf("\r%s", (" " x $self->{term}->{cols}) );
    return 1
}

sub nl {
# New Line
    my $self = shift;
    print $self->{colors}->{reset} . "\n";
    return 1
}

=head4 $msg->print($type, $text, $nl)

    Output setup by $type:
        0 - $text
        1 - ==> $text
        2 -   -> $text
        3 - Warning: $text
        4 - Error: $text
    $nl is a boolean. Do you want a new line char at the end of this line?

=cut

sub print {
    my ($self, $type, $txt, $nl) = @_;

    $self->cl;

    given($type) {
        print $self->{colors}->{arrow}   . "==> "       when(1);
        print $self->{colors}->{arrow2}  . "  -> "      when(2);
        print $self->{colors}->{warning} . "Warning: "  when(3);
        print $self->{colors}->{error}   . "Error: "    when(4);
    }

    defined $txt
        and print $self->{colors}->{msg} . $txt;

    ($nl)
        and $self->nl;

    return 1
}

=head4 $msg->results($type, $text, $nl)

    For use after another method without nl. As results of some action.. eg:
        $msg->print(1, "Processing DataBase: ", 0);
        $msg->results(1, $val . " packages matched..", 1);

    $type is a color:
        0 - the same
        1 - green/perfect
        2 - yellow/warning
        3 - red/error
    $nl is boolean. Do you want a new line?

=cut

sub results {
    my ($self, $type, $txt, $nl) = @_;

    given($type) {
        print $self->{colors}->{results1} when(1);
        print $self->{colors}->{results2} when(2);
        print $self->{colors}->{results3} when(3);
        default {print $self->{colors}->{results} };
    }

    defined $txt
        and print $txt;

    ($nl)
        and $self->nl;

    return 1
}

=head4 $msg->newer($package_name, $local_ver, $repo_ver, $come_from, $repo_name)

    Print warning message for package which is newer than in repo

    Notes:
    * come_from (eg. repo, aur) and repo_name (eg. core, extra) are optional.
    * If repo_name is not defined then come_from will be used as repo_name.

=cut

sub newer {
    my ($self, $name, $lver, $rver, $from, $repo) = @_;

    defined $from or $from = "repo";
    defined $repo or $repo = $from;
    
    $self->print(3, sprintf("newer than %s: ", $from), 0);
    $self->results(1, $name . " ", 0);
    $self->results(0, $lver . " ", 0);
    $self->results(3, sprintf("(%s: %s)", $repo, $rver), 1);

    return 1
}

=head4 $msg->forgein($package_name)

    Print warning about package that can't be found anywhere..

=cut

sub forgein {
    my ($self, $name) = @_;

    $self->print(3, "deleted or part of multipackage: ", 0);
    $self->results(1, $name, 1);

    return 1
}
1;

__END__

=head1 SEE ALSO

    AurPac(3)

=head1 AUTHOR

    Krzysztof AS (3ED) <krzysztof1987@gmail.com>
