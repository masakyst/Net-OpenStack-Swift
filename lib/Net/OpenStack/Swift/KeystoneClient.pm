package Net::OpenStack::Swift::KeystoneClient::Base;
use strict;
use warnings;
use Moo;
use JSON qw(from_json to_json);
use Furl;
use Data::Dumper;

has auth_url     => (is => 'rw', required => 1); 
has user         => (is => 'rw', required => 1); 
has password     => (is => 'rw', required => 1); 
has tenant_name  => (is => 'rw');
has verify_ssl   => (is => 'ro', default => sub {! $ENV{OSCOMPUTE_INSECURE}});

has token => (
    is      => 'ro',
    lazy    => 1,
);

has agent => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $agent = Furl->new(
            #agent    => "Mozilla/5.0",
        );  
        return $agent;
    },  
);

sub get_auth_params { die; }

sub get_tokens {
    my $self = shift;
    #print Dumper(to_json($self->get_auth_params));
    my $res = $self->agent->post(
        $self->auth_url."/tokens",
        ['Content-Type'=>'application/json'], # headers
        to_json($self->get_auth_params),      # form data (HashRef/FileHandle are also okay)
    );
    #print Dumper($res);
    die $res->status_line unless $res->is_success;
    my $body_params = from_json($res->content);
    #print Dumper($body_params);
    return ($body_params->{access}->{serviceCatalog}->[0]->{endpoints}->[0]->{publicURL}, # endpoints 'type' => 'object-store'
            $body_params->{access}->{token}->{id});                           # token id
}


package Net::OpenStack::Swift::KeystoneClient::V2;
use strict;
use warnings;
use Moo;
extends 'Net::OpenStack::Swift::KeystoneClient::Base';

sub get_auth_params {
    my $self = shift;
    my $data = {
        auth => {
            tenantName   => $self->tenant_name,
            passwordCredentials => {
                username => $self->user,
                password => $self->password,
            }
        }
    };
 
}

package Net::OpenStack::Swift::KeystoneClient::V3;
use strict;
use warnings;
use Moo;
extends 'Net::OpenStack::Swift::KeystoneClient::Base';

sub get_auth_params {
    #my $data = {
    #    auth => {
    #        identity => {
    #            methods => ['password'],
    #            password => {
    #                user => {
    #                    name => $self->user,
    #                    domain => {id => "default"},
    #                    password => $self->password,
    #                }
    #            }
    #        }
    #    }
    #};
}


1;
