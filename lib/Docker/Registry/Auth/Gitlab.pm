package Docker::Registry::Auth::Gitlab;
use Moose;
use namespace::autoclean;

# ABSTRACT: Authentication module for gitlab registry

with 'Docker::Registry::Auth';

use Docker::Registry::Types qw(DockerRegistryURI);
use HTTP::Tiny;
use JSON::MaybeXS qw(decode_json);

has token => (
    is       => 'ro',
    isa      => 'Str',
    lazy     => 1,
    builder => 'get_token',
);

has username => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has password => (
    is       => 'ro',
    isa      => 'Str',
    required => 1,
);

has jwt => (
    is      => 'ro',
    isa     => DockerRegistryURI,
    coerce  => 1,
    default => 'https://gitlab.com/jwt/auth',
);

has repo => (
    is        => 'ro',
    isa       => 'Str',
    predicate => 'has_repo',
);

sub _build_scope {
    my $self = shift;

    if ($self->has_repo) {
        return sprintf("repository:%s:pull,push", $self->repo);
    }
    else {
        return 'registry:catalog:*';
    }
}

sub _build_token_uri {
    my $self = shift;

    my $uri = $self->jwt->clone;

    $uri->query_form(
        service       => 'container_registry',
        scope         => $self->_build_scope,
        client_id     => 'docker',
        offline_token => 'true',
    );

    $uri->userinfo(join(':', $self->username, $self->password));
    return $uri;
}

sub get_token {
    my $self = shift;

    my $uri = $self->_build_token_uri;

    my $ua = HTTP::Tiny->new();
    my $res = $ua->get($uri);

    if ($res->{success}) {
        return decode_json($res->{content})->{token};
    }

    die "Unable to get token from gitlab!";
}

sub authorize {
    my ($self, $request) = @_;

    $request->header('Authorization', 'Bearer ' . $self->token);
    $request->header('Accept',
        'application/vnd.docker.distribution.manifest.v2+json');

    return $request;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 DESCRIPTION

Authenticate against gitlab registry

=head1 SYNOPSIS

    use Docker::Registry::Auth::Gitlab;
    use HTTP::Tiny;

    my $auth = Docker::Registry::Auth::Gitlab->new(
        username => 'foo',
        password => 'bar',
    );

    my $req = $auth->authorize(HTTP::Request->new('GET', 'https://foo.bar.nl'));
    my $res = HTTP::Tiny->new()->get($req);

=head1 ATTRIBUTES

=head2 username

Your username at gitlab.

=head2 password

The access token you get from
L<gitlab|https://gitlab.com/profile/personal_access_tokens> with
'read_registry' access.

=head2 repo

The repository you request access to.

=head2 jwt

The endpoint to request the JWT token from, defaults to
'https://gitlab.com/jwt/auth'. You can use a 'Str' or an URI object.

=head2 token

The token received from gitlab.

=head1 METHODS

=head2 authorize

Implements the method as required by L<Docker::Registry::Auth>. Add the
"Authorization" header to the request with the "Bearer" token.

=head2 SEE ALSO

L<Docker::Registry::Auth>, L<Docker::Registery::Types> and L<Docker::Registry::Gitlab>.