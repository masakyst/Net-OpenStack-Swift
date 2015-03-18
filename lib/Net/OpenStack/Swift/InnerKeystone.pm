package Net::OpenStack::Swift::InnerKeystone::Base;
use Mouse;
use JSON;
use Furl;
use namespace::clean -except => 'meta';

has auth_token      => (is => 'rw'); 
has service_catalog => (is => 'rw'); 
has auth_url        => (is => 'rw', required => 1); 
has user            => (is => 'rw', required => 1); 
has password        => (is => 'rw', required => 1); 
has tenant_name     => (is => 'rw');
#has verify_ssl      => (is => 'ro', default => sub {! $ENV{OSCOMPUTE_INSECURE}});

has agent => (
    is      => 'rw',
    lazy    => 1,
    default => sub {
        my $self = shift;
        my $agent = Furl->new;  
        return $agent;
    },  
);

sub get_auth_params { die; }

sub service_catalog_url_for {
    my ($self, %args) = @_;
    my $endpoint;
    # このservice_catalog_url_forはregionでもしぼらないといけない
    foreach my $service_catelog (@{ $self->service_catalog }) {
        if ($args{service_type} eq $service_catelog->{type}) {
            # endpointsの中は配列なので複数ある可能性がありそう。複数あった場合どうなるんだろう
            $endpoint = $service_catelog->{endpoints}->[0]->{$args{endpoint_type}}; 
        } 
    }
    # endpoint見つからないエラー
    return $endpoint;
}


package Net::OpenStack::Swift::InnerKeystone::V2_0;
use Carp;
use JSON;
use Mouse;
use namespace::clean -except => 'meta';

extends 'Net::OpenStack::Swift::InnerKeystone::Base';

sub get_auth_params {
    my $self = shift;
    return {
        auth => {
            tenantName   => $self->tenant_name,
            passwordCredentials => {
                username => $self->user,
                password => $self->password,
            }
        }
    };
}

sub auth {
    my $self = shift;
    my $res = $self->agent->post(
        $self->auth_url."/tokens",
        ['Content-Type'=>'application/json'], # headers
        to_json($self->get_auth_params),      # form data (HashRef/FileHandle are also okay)
    );
    croak "authorization failed: ".$res->status_line unless $res->is_success;
    my $body_params = from_json($res->content);
    $self->auth_token($body_params->{access}->{token}->{id});
    $self->service_catalog($body_params->{access}->{serviceCatalog});
    return $self->auth_token();
}



package Net::OpenStack::Swift::InnerKeystone::V3;
use Carp;
use JSON;
use Mouse;
use namespace::clean -except => 'meta';

extends 'Net::OpenStack::Swift::InnerKeystone::Base';

sub get_auth_params {
    #return {
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
