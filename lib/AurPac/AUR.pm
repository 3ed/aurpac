package AurPac::AUR;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use Archive::Extract;
use File::Path qw(make_path);
use AurPac::PACMAN;

# TODO zrobiã z tego AurPac::cli; i wrzuciã tu tylko posklejane funkje i output
# TODO pozbyc sie odwolan do binarek z calego kodu
# TODO wyszukaj: TD#1

sub new {
    my ($class, $config) = @_;
    
    my $self = {};

    my $un = ((getpwuid($<))[0]);
    #defaults
    $self->{config} = $config;

    # TD#1 nie pwoinno być w hashu 'config'.. to jest konfiguracja makepkg, a nie aurpaca!
    #      1) Wczytywać wpierw z makepkg.conf
    #      2) ze zmiennych systemowych jak poniżej
    $self->{config}->{buildsrc_dir} = $ENV{BUILDDIR}   || "/var/tmp/aurpac-".$un."/build/";
    $self->{config}->{aursrc_dir}   = $ENV{SRCPKGDEST} || "/var/tmp/aurpac-".$un."/srcpkg/";

    #objects
    $self->{pacman} = AurPac::PACMAN->new(\%{$self->{config}});

    return bless($self, $class);
}

sub net {
    my $self = shift;

    require AurPac::net;
    defined $self->{net}
        or $self->{net} = AurPac::net->new(\%{$self->{config}});

    return $self->{net}
}
sub msg {
    my $self = shift;

    require AurPac::Messages;

    defined $self->{msg}
        or $self->{msg} = AurPac::Messages->new(\%{$self->{config}});

    return $self->{msg}
}
sub pbar {
    my $self = shift;

    require AurPac::ProgressBar;

    defined $self->{pbar}
        or $self->{pbar} = AurPac::ProgressBar->new(\%{$self->{config}});

    return $self->{pbar}
}

sub vercmp {
    my ($self, $a, $b, $n) = @_;

    $n = "nieznana" unless defined $n;

    unless (defined $a) {
        warn "$n: could not read version from aur...";
        return
    }
    unless (defined $b) {
        warn "$n: could not read version from db of installed packages...";
        return
    }

    return $self->{pacman}->vercmp($a, $b)
}
sub updateable {
    my ($self, @args) = @_;

    given($self->vercmp(@args)) {
        return 1 when(1);
        return 0 when(0);
        return 0 when(-1);
    }

    return
}

sub word_wrap { #TODO put into AurPac::Message              !!!!!!! TODO !!!!!!!
    my ($self, $tab, $text) = @_;

    return undef unless defined $text;

    $tab ||= 2;
    $tab = (" " x $tab);

    my $msg;
    my $words = "";
#    my $term_cols = ((GetTerminalSize())[0]);
    my $term_cols = `tput cols`;
    my $first = 1;

    foreach(split(/\s/, $text)) {
        if (((length $words) + (length $_) + 1) > $term_cols) {
            $msg .= sprintf("%s\n", $words);
            $words = $tab . $_;
            next
        }
        $words .= ($first ? $tab : " ") . $_;
        $first = 0;
    }
    $msg .= sprintf("%s", $words);

    return $msg
}

sub _IgnorePkg {
    my $self = shift;
    # TODO -> /etc or ~/.config                            !!!!!!! TODO !!!!!!!
    my $IgnorePkgPath = "/home/kas/aurpac-ng/ap-isup2date-aur.ignorepkg";

    defined $self->{IgnorePkg}
        and return $self->{IgnorePkg};

    open my $FH, "<", $IgnorePkgPath or return;

    while(<$FH>) {
        chomp;
        next if(/(\s+|)#/);
        tr/ //; # dodac sprawdzanie czy są puste linie..
        $self->{IgnorePkg}->{$_} = 1;
    }

    close $FH;

    return $self->{IgnorePkg}
}

sub aur_update {
    my ($self, $verbose) = @_;

    # TODO sprawdzić czy multisearch daje też metapakiety a jeśli tak to jak je wyplówa

    my @updateable;

    $self->msg->print(1, "AUR: Refreshing db...", 1);
    $self->msg->print(2, "Analizing local db... ", 0);

    $self->_IgnorePkg;

    my $local = $self->{pacman}->Qm;

    foreach (keys $self->{IgnorePkg}) {
        defined $local->{$_} and delete $local->{$_}
    }

    my $pbmax = scalar keys $local;

    $self->msg->results(1, sprintf("found: %d package(s)", $pbmax), 1);

    $self->msg->print(2, "Analizing remote AUR db...", 0);

    my $aur_infos = $self->net->aur("multiinfo", [ keys $local ]);
    if ($aur_infos->{type} eq "info") {
        $self->msg->results(3, "error", 1);
        $self->msg->print(4, $aur_infos->{results}, 1);
        die;
    }
    if ($aur_infos->{resultcount} == 0) {
        $self->msg->print(2, "Analizing remote AUR db...", 0);
        $self->msg->results(3, " 0 package(s)", 1);

        $self->msg->print(2, "Need upgrade:", 0);
        $self->msg->results(4, " 0 package(s)", 1);

        return;
    }

    my @newerthanrepo;

    my $c = 0;
    foreach my $ai (@{$aur_infos->{results}}) {
        $c++;
        given(
            $self->vercmp(
                $ai->{Version},
                $local->{$ai->{Name}},
                $ai->{Name}
            )
        ) {
            when(1) {
                push @updateable,
                [ $ai->{Name}, $ai->{Version}, $ai->{URLPath} ];
            }
            when(-1) {
                push @newerthanrepo,
                [ $ai->{Name}, $local->{$ai->{Name}}, $ai->{Version} ];
            }
        }
        delete $local->{$ai->{Name}};
    };

    $self->msg->cl;

    $self->msg->forgein($_)  foreach keys $local;

    $self->msg->print(2, "Analizing remote AUR db...", 0);
    $self->msg->results(1, sprintf(" found: %d package(s)", $c), 1);

    $self->msg->newer(@{$_}, "AUR", "aur") foreach @newerthanrepo;

    $self->msg->print(2, "Need upgrade:", 0);
    $self->msg->results(4, sprintf(" %d package(s)", ($#updateable + 1)), 1);

    $self->prepare_aursrc(@{$_}) foreach @updateable;

    return @updateable
}

sub cpan_update {
    my $self = shift;
    my $db = {};
    my $dbfile = $ENV{HOME}."/aurpac-ng/ap-isup2date-cpanmods.db"; # TODO
    -f $dbfile or die("Plik „" . $dbfile . "” nie istnieje..");

    $self->msg->print(1, "CPAN: Refreshing db...", 1);
    $self->msg->print(2, "Analizing local db... ", 0);

    # Wczytywanie pliku $dbfile i uzupełnianie $db
    open my $FH, "<", $dbfile or die($!);
    while( <$FH> ) {
        # format bazy danych ($aur_name jest opcjonalny):
        my ($cpan_name, $aur_name) = split(/\s/, $_);

        # omijanie pustych linii
        if( defined $cpan_name ) {
            # nadawanie nazw gdy nie podano nazwy pakietu
            if ( not defined $aur_name or $aur_name eq "" ) {
                $aur_name = "perl-" . lc($cpan_name);
            }
            $db->{$aur_name} = $cpan_name;
        }
    }
    close $FH;

    $self->msg->results(1, sprintf("found: %d package(s)", ( $#{[keys $db]} + 1 )), 1);

    $self->msg->print(2, "Analizing remote AUR db...", 0);

    # Multiinfo, hiperszybkie w porówaniu do zwykłego info
    my $aur_multiinfo = $self->net->aur("multiinfo", [sort keys $db]);

    if ( $aur_multiinfo->{type} eq "multiinfo" ) {
        $self->msg->results(1,
            sprintf("found: %d package(s)", $aur_multiinfo->{resultcount}), 1);
    } else {
        $self->msg->results(3, "error", 1);
        $self->msg->print(4, $aur_multiinfo->{results}, 1);
        die;
    }

    my $format = "\r%-10s %-10s %-25s %s\n";
    my @table;
    my $c = 0;
    my $c_full = 0;

    $self->pbar->set(
        msg => "Analizing remote CPAN db...",
        min => 0,
        max => $aur_multiinfo->{resultcount})->show;

    foreach (@{$aur_multiinfo->{results}}) {
        $c++;
        my $cpan_name = $db->{$_->{Name}} or next;

        $self->pbar->next->show;

        my $aur_ver = "";
        my $changed = "";

        my $content = $self->net->cpan_api("dist", $cpan_name)
            or warn("\r[WARN] $cpan_name: Somehow got empty data from webpage…\n");
    
        my $author = $content->{releases}->[0]->{cpanid} or next;
        $author = substr($author, 0, 1) . "/" . substr($author, 0, 2) . "/" . $author;

        my $cpan_info = {
                author => $author,
                name => $content->{releases}->[0]->{dist},
                version => $content->{releases}->[0]->{version}
            };

        $aur_ver = $_->{Version};
        $aur_ver =~ s/-[^-]*$//g;
    
        push @table, [
            $aur_ver,
            $cpan_info->{version},
            $cpan_info->{name},
            $cpan_info->{author}
        ] unless ($cpan_info->{version} eq $aur_ver);
    }

    $self->pbar->hide;
    $self->pbar->end;

    $self->msg->print(2, "Searching inside remote CPAN db...", 0);
    $self->msg->results(1, sprintf(" found: %d package(s)", $c), 1);

    $self->msg->print(2, "Need upgrade:", 0);
    $self->msg->results(4, sprintf(" %d package(s)", ($#table + 1)), 1);

    for(my $c=0; $c <= $#table; $c++) {
        ($c == 0)
            and printf($format, "AUR VER", "CPAN VER", "CPAN NAME", "CPAN AUTHOR\e[0m");
        printf($format, @{$table[$c]});
    }
    return "TODO: hash with packages" #TODO
}


sub prepare_aursrc {
    my ($self, $pkg, $ver, $url) = @_;

    printf("%s... [\e[0;34;1mD\e[0mE] [ \e[0;34;1mprocessing\e[0m ]\r", $pkg);

    if ( my $file = $self->get_aursrc($pkg, $ver, $url) ) {
        printf("\r\e[K\e[0m%s... [\e[0;32;1mD\e[0;34;1mE\e[0m] [ \e[0;34;1mprocessing\e[0m ]", $pkg);
        if ($self->extract($file)) {
            printf("\r\e[K\e[K\e[0m%s... [\e[0;32;1mDE\e[0m] [ \e[32;1mdone\e[0m ]\n", $pkg);
            return 1
        } else {
            printf("\n\e[K\e[0m%s... [\e[0;32;1mD\e[0;31;1mE\e[0m] [ \e[31;1mfail\e[0m ]\n", $pkg);
        }
    } else {
        printf("\r\e[K\e[K\e[0m%s... [\e[0;31;1mD\e[0mE] [ \e[0;31;1mfail\e[0m ]\n", $pkg);

    }

    return
}

sub get_aursrc {
    my ($self, $pkg, $ver, $url) = @_;

    make_path($self->{config}->{aursrc_dir});

    unless (-d $self->{config}->{aursrc_dir}) {
        warn sprintf("%s: %s\n", $self->{config}->{buildsrc_dir}, $!);
        return;
    }

    my $results = $self->net->aursrc($pkg, $ver, $url, $self->{config}->{aursrc_dir});

    unless ($results->{type} eq "aursrc") {
        warn sprintf("\e[31;1mError:\e[0m %s (%s)\n", $results->{results}, $pkg);
        return undef;
    }

    return $results->{results};
}

sub extract {
    my ($self, $file, $dir_to) = @_;

    defined $dir_to
        or $dir_to = $self->{config}->{buildsrc_dir};

    unless (-f $file) {
        warn sprintf("%s: %s\n", $file, $!);
        return;
    };

    make_path($dir_to);

    unless (-d $dir_to) {
        warn sprintf("%s: %s\n", $dir_to, $!);
        return;
    }


    my $ae = Archive::Extract->new( archive => $file );

    unless (
        $ae->extract( to => $dir_to )
    ) {
        warn sprintf("%s: is not archive file\n", $file);
        return;
    }

    return 1
}


sub search {
    my ($self, $verbose, $name) = @_;
    my $json = $self->net->aur("search", $name);

    # TODO kolory
    # TODO printy na sprintfy z $self->print_info($verbose, $self->{results});

    unless ($json->{"type"} eq "search") {
        warn sprintf("\e[31;1mError:\e[0m %s\n", $json->{results});
        return undef;
    }


    foreach (
        sort { $a->{Name} cmp $b->{Name} } @{@$json{"results"}}
    ) {
        if ($verbose == 0) {
            printf("%s\n", $_->{'Name'});
        } elsif ($verbose == 1) {
            printf("\e[0;1m%s \e[0;32;1m%s\e[0m\n", $_->{'Name'}, $_->{'Version'});
        } elsif ($verbose == 3) {
            my $I = $self->installed($_->{Name});
            my $O = $_->{OutOfDate};
            my $U = 0;

            if (defined $self->{local_db}->{$_->{Name}}) {
                $U = $self->updateable($_->{Version},
                    $self->{local_db}->{$_->{Name}}->{version}."-".$self->{local_db}->{$_->{Name}}->{release});
            }


            my $flags = 0; foreach my $true ($I,$U,$O){ $flags = 1 if($true)};

            printf(
               "\e[0;35;1mAUR/\e[0;1m%s \e[0;32;1m%s \e[0;34;1m(Votes: %s)%s\e[0m\n%s\n",
               $_->{'Name'},
               $_->{'Version'},
               $_->{'NumVotes'},
               ( $flags
                   ? " \e[0;34;1m(Flags: "
                       . ( $O ? "\e[0;31;1mO" : "")
                       . ( $I ? "\e[0;32;1mI" : "")
                       . ( $U ? "\e[0;33;1mU" : "")
                       . "\e[0;34;1m)"
                   : "" ),
               $self->word_wrap(2, $_->{'Description'})
            );
        } else {
            my $format = "\e[0;1m%-15s:\e[0m %s\e[0m\n";
            printf($format, "Repository",     "\e[0;35;1m" . "(( AUR ))");
            printf($format, "Name",           "\e[0;1m"    . $_->{Name});
            printf($format, "Version",        ($_->{OutOfDate} ? "\e[31;1m" : "\e[32;1m") . $_->{Version});
            printf($format, "OutOfDate",      ($_->{OutOfDate} ? "\e[31;1mYes" : "\e[32;1mNo"));
            printf($format, "Project Page",   "\e[0;36;1m" . $_->{URL});
            printf($format, "AUR Page",       "\e[0;36;1mhttp://aur.archlinux.org/packages.php?ID=".$_->{ID});
            printf($format, "Package Path",   "\e[0;36;1mhttp://aur.archlinux.org".$_->{URLPath});
            printf($format, "Maintainer",     $_->{Maintainer} || "--None--");
            printf($format, "FirstSubmitted", scalar localtime $_->{FirstSubmitted}); #TODO Czytelna data
            printf($format, "LastModified",   scalar localtime $_->{LastModified}); #TODO Czytelna data
            printf($format, "NumVotes",       $_->{NumVotes});
            printf($format, "CategoryID",     $_->{CategoryID});
            printf($format, "License",        $_->{License});
            printf($format, "Description",    $_->{Description});
            print "\n";
        }
    }

    return 1
}

sub prepare_local_db {
    my ($self) = @_;

    return 1 if defined $self->{local_db};

    opendir my $DH, $self->dbpath."/local/" or return 0;

    while (readdir $DH) {
        if ($_ =~ m/(.*)-([^-]*)-([^-]*)$/) { # może unpop byloby lepsze?
            $self->{local_db}->{$1}->{version} = $2;
            $self->{local_db}->{$1}->{release} = $3;
        }
    };
    closedir $DH;

    return 1
}

sub installed {
    my ($self, $local_pkg) = @_;

    return 1 if defined $self->{local_db}->{$local_pkg};

    return 0;
}

1;
