=encoding UTF-8
=head1 NAZWA

 AurPac::net

=head1 OPIS

 Pobieranie rzeczy..

=head1 FUNKCJE
=cut

package AurPac::net;
use v5.18;
#use feature "lexical_subs";
no if $] >= 5.018, warnings => "experimental::smartmatch";
#no if $] >= 5.018, warnings => "experimental::lexical_subs";

use LWP::UserAgent;
use AurPac::Version;

=head2 new(config);
=cut

sub new {
    my ($class, $config) = @_;

    my $self = {};

    #config
    $self->{config} = $config or die($class . " got empty config..");

    #objects
    $self->{Version} = AurPac::Version->new;
    $self->{ua} = LWP::UserAgent->new(
        agent => $self->{Version}->ua,
        keep_alive => 1,
        env_proxy => 1
    );
    $self->{ua}->timeout($self->{config}->{dl_timeout});

    return bless($self, $class);
}

=head2 aur(type, arg)

 Pobieranie AURowego, json.

 Opcje:
   ( <<type>>    , <<arg>> ) | desc
   ---------------------------|--------------------------------
   ( "search"    , $var )    | search in name and desc
   ( "msearch"   , $var )    | search by montainer name
   ( "info"      , $var )    | show info for one pkg
   ( "multiinfo" , @var )    | show info for one or more pkgs

 Funkcja zwraca hash:
   type    - powinno mieć to samo co dałeś i na pewno nie "error"
   results - treść wyniku lub błędu dla "error"

=cut

sub aur {
    my ($self, $type, $arg) = @_;

    require URI;
    require JSON;

    # URI
    my $arg_type = (($type eq "multiinfo") ? "arg[]" : "arg");

    $self->{aur_uri} = URI->new("http://aur.archlinux.org/rpc.php");
    $self->{aur_uri}->query_form("type" => $type, $arg_type => $arg);

    # LWP retrying
    my $response;
    for (my $i = 0; $i <= ($self->{config}->{dl_retry} || 15); $i++) {
        $response = $self->{ua}->get($self->{aur_uri});
        last if ($response->is_success);
        sleep 1;
    }

    # LWP header service response code handler
    unless ($response->is_success) {
        return {
            type => "error",
            results => $response->status_line
        };
    }

    # decoding json
    my $json = JSON::from_json($response->decoded_content, {utf8  => 1}) 
        or return {type => "error", results => $!};

    return $json;
}

=head2 aursrc(pkg, ver, url, dir)

 Pobieranie źródeł..

 Opcje:
   pkg - nazwa pakietu
   ver - wersja (chyba że chcesz nieświdomie robić aur("info", $pkg))
   url - adres  (to samo co w ver)
   dir - powinno być w $me->new(%config)

 Funkcja zwraca hash:
   type    - aursrc lub error
   results - Ścieżka do pliku lub treść błędu

=cut

sub aursrc {
    my ($self, $pkg, $ver, $url, $dir) = @_;

    defined $dir
        or $dir = $self->{config}->{aursrc_dir};


    if ((defined $ver) and (defined $url)) {
        $url = "http://aur.archlinux.org".$url unless ($url =~ /^http:\/\//);
    } else {
        my $json = $self->aur("info", $pkg);

        # return if error
        return $json if ($json->{type} eq "error");

        # return if pkg not found
        return {
            type => "error",
            results => "$pkg: Not found.."
        } if ($json->{resultcount} == 0);

        $url = "http://aur.archlinux.org".$json->{results}->{URLPath};
        $ver = $json->{results}->{Version};
    }

    my $ext = ".src.tar.gz";
    my $filename = $dir . "/" . $pkg . "-" . $ver . $ext;

    unless ( -f $filename ) {
        my $response;
        for (my $i = 0; $i <= $self->{config}->{dl_retry}; $i++) {
            $response = $self->{ua}->get( $url, ":content_file" => $filename );
            last if ($response->is_success);
            sleep 1;
        }

        return {
            type => "error",
            results => $response->status_line
        } unless $response->is_success;
    }

    return {
        type => "aursrc",
        results => $filename
    }
}

=head2 cpan_api(mode, name)

 Retriving essential information about from cpan api:

 options:
   mode:
     module - module
     dist   - package with modules
     author - author of package with modules
   name - element name

 return back empty or hash

=cut

sub cpan_api {
    my ($self, $mode, $name) = @_;

    ($mode =~ /^(module|dist|author)$/)
        or die("AurPac::net->cpan_api(mode, name): bad mode...");
    defined $name
        or die("AurPac::net->cpan_api(mode, name): name is empty...");

    require JSON;

    my $url = "http://search.cpan.org/api/" . $mode . "/" . $name;

    my $response = $self->{ua}->get($url);

    unless ($response->is_success) {
        warn sprintf("%s: %s\n", $name, $response->status_line);
        return;
    }

    return JSON::from_json($response->decoded_content) or return;
}

=head2 cpan_meta(mode, name)

 Retriving extra information about (like eg. depends) from META.json:

 options:
   dist    - module package name
   version - version (optional, automatic download if empty)
   cpanid  - cpan author (optional, automatic download if empty)

 return back empty or hash

=cut

sub cpan_meta {
    my ($self, $dist, $version, $cpanid) = @_;

    if (not defined $version or not defined $cpanid) {
        my $cpan_api = $self->cpan_api("dist", $dist) or return;
        $cpanid  = $cpan_api->{releases}->[0]->{cpanid};
        $version = $cpan_api->{releases}->[0]->{version};
    };

    require JSON;

    my $url = "http://cpansearch.perl.org/src/" . $cpanid
            . "/" . $dist . "-" . $version . "/META.json";

    my $response = $self->{ua}->get($url);

    unless ($response->is_success) {
        warn sprintf("%s: %s\n", $dist, $response->status_line);
        return;
    }

    return JSON::from_json($response->decoded_content) or return;
}

1;

__END__

=head1 TODO

 - nowa wersja biblioteki (jeszcze nie uzywana)
 - ta część ze ściąganiem, może by ją wsadzić do innej funkcji?
 - użyć wbudowany w LWP pasek postępu..
 - patrz aur_getsrc

=cut
