package Kynetx::Modules::HTTP;

# file: Kynetx/Modules/HTTP.pm
# file: Kynetx/Predicates/Referers.pm
#
# This file is part of the Kinetic Rules Engine (KRE)
# Copyright (C) 2007-2011 Kynetx, Inc. 
#
# KRE is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2 of
# the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be
# useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
# PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 59 Temple Place, Suite 330, Boston,
# MA 02111-1307 USA
#
use strict;
#use warnings;

use Log::Log4perl qw(get_logger :levels);

use URI::Escape;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

use Kynetx::Rids qw/:all/;
use Kynetx::Environments qw/:all/;
use Kynetx::Parser qw/mk_expr_node/;
use Kynetx::Util qw(correct_bool);

use Data::Dumper;
$Data::Dumper::Indent = 1;

our $VERSION = 1.00;
our @ISA     = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (
	all => [
		qw(
		raise_response_event
		make_response_object
		mk_http_request
		  )
	]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

my $predicates = {};
my $verbs = {};

my $default_actions = {
	'post' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_post,
		'after'  => []
	},
	'put' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_put,
		'after'  => []
	},
	'get' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_get,
		'after'  => []
	},
	'head' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_head,
		'after'  => []
	},
	'delete' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_delete,
		'after'  => []
	},
	'patch' => {
		'js' =>
		  'NO_JS',    # this action does not emit JS, used in build_one_action
		'before' => \&do_patch,
		'after'  => []
	},
};

sub get_resources {
	return {};
}

sub get_actions {
	return $default_actions;
}

sub get_predicates {
	return $predicates;
}

sub do_get {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	my $logger = get_logger();
	$logger->debug("As Action");
	return do_http( 'GET', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'get'} = 1;

sub do_post {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	return do_http( 'POST', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'post'} = 1;

sub do_head {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	return do_http( 'HEAD', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'head'} = 1;

sub do_put {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	return do_http( 'PUT', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'put'} = 1;

sub do_delete {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	return do_http( 'DELETE', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'delete'} = 1;

sub do_patch {
	my ( $req_info, $rule_env, $session, $config, $mods, $args, $vars ) = @_;
	return do_http( 'PATCH', $req_info, $rule_env, $session, $config, $mods,
		$args, $vars );
}
$verbs->{'patch'} = 1;

sub make_response_object {
	my ($response, $ro_name, $config) = @_;
	my $logger = get_logger();
	my $resp = {
		$ro_name => {
			'label' => $config->{'autoraise'} || '',
			'content'        => $response->decoded_content(),
			'status_code'    => $response->code(),
			'status_line'    => $response->status_line(),
			'content_type'   => $response->header('Content-Type') || '',
			'content_length' => $response->header('Content-Length') || 0,
		}
	};

	if ( defined $config->{'response_headers'} ) {
		$logger->debug("Return response_headers");
		foreach my $h ( @{ $config->{'response_headers'} } ) {
			if (uc($h) eq 'HEADER_FIELD_NAMES') {
				my @names;
				for my $n ($response->header_field_names()) {
					push(@names, $n);
				}
				$resp->{$ro_name}->{ lc($h) } = \@names;
			} else {
				$resp->{$ro_name}->{ lc($h) } = $response->header( uc($h) );
			}			
		}
	}
	$logger->trace( "KRL response ", sub { Dumper $resp } );
	return $resp
}

sub raise_response_event {
  my ( $method, $req_info, $rule_env, $session, $config, $resp, $ro_name ) = @_;
  my $logger = get_logger();
  my $js = '';
  if ( defined $config->{'autoraise'} ) {
    $logger->debug(
		   "http library autoraising event with label $config->{'autoraise'}");

    # make modifiers in right form for raise expr
    my $ms = [];
    foreach my $k ( keys %{ $resp->{$ro_name} } ) {
      push(
	   @{$ms},
	   {
	    'name' => $k,
	    'value' =>
	    Kynetx::Expressions::mk_den_str( $resp->{$ro_name}->{$k} ),
	   }
	  );
    }

    # create an expression to pass to eval_raise_statement
    my $expr = {
		'type'      => 'raise',
		'domain'    => 'http',
		'ruleset'   => $config->{'rid'},
		'event'     => mk_expr_node( 'str', lc($method) ),
		'modifiers' => $ms,
	       };
    $js .=
      Kynetx::Postlude::eval_raise_statement( $expr, $session, $req_info,
					      $rule_env, $config->{'rule_name'} );
  }
  return $js;
}

sub do_http {
	my ( $method, $req_info, $rule_env, $session, $config, $mods, $args, $vars )
	  = @_;
	my $logger = get_logger();
	$logger->trace("config: ", sub {Dumper($config)});
	$logger->trace("mods: ", sub {Dumper($mods)});


	my $response = mk_http_request(
		$method, $config->{'credentials'},
		$args->[0], $config->{'params'} || $config->{'body'},
		$config->{'headers'},
	);

	$logger->trace("Raw response: ", sub {Dumper($response)});
	my $v = $vars->[0] || '__dummy';

	my $resp = make_response_object($response,$v,$config);

	my $r_status;
	if ($resp) {
		$r_status = $resp->{$v}->{'status_line'};
	}
	$logger->debug( "Response status: ", sub { Dumper $r_status } );

	# side effect rule env with the response
	# should this be a denoted value?
	$rule_env = add_to_env( $resp, $rule_env ) unless $v eq '__dummy';
	my $js = raise_response_event( $method, $req_info, $rule_env, $session, $config, $resp, $v );
}

sub mk_http_request {
	my ( $method, $credentials, $uri, $params, $headers ) = @_;

	my $logger = get_logger();

	my $ua = kynetx_ua($credentials);

	$logger->debug("Method is $method & URI is $uri");

	my $req;
	my $response;


	$method = uc($method);
	if ( $method eq 'POST' || $method eq 'PUT' || $method eq 'PATCH') {
		
		$req = new HTTP::Request $method, $uri;

		#    $response = $ua->post($uri);

		my $content;
		if ( defined $headers->{'content-type'} ) {
			$content = $params;
			$req->header( 'content-type' => $headers->{'content-type'} );
		} elsif (defined $headers->{'Content-Type'}) {
			$content = $params;
			$req->header( 'content-type' => $headers->{'Content-Type'} );			
		} else {
			$content = join(
				'&',
				map( "$_=" . uri_escape_utf8( correct_bool($params->{$_}) ), keys %{$params} )
			);
			$req->header(
				'content-type' => "application/x-www-form-urlencoded; charset=UTF-8" );

		}
		$logger->debug("Unencoded content: ", sub { Dumper($content) } );
		if (ref $content ne "") {
			my $temp;
			eval {
				$temp = Kynetx::Json::astToJson($content);
			};
			if ($@) {
				$content = "Not string, not json"
			} else {
				$content = $temp;
			}
		}

		$logger->debug( "Encoded content: ", sub { Dumper($content) } );
		$req->content($content);
		$req->header( 'content-length' => length($content) );

	}
	elsif ( $method eq 'GET' || $method eq 'HEAD' || $method eq 'DELETE') {
		my $full_uri = Kynetx::Util::mk_url( $uri, $params );
		$req = new HTTP::Request $method, $full_uri;
	}
	else {
		$logger->warn("Bad method ($method) called in do_http");
		return '';
	}
	
	foreach my $k ( keys %{$headers} ) {
		$req->header( $k => $headers->{$k} );
	}

	$logger->trace( "Request ", Dumper $req);

	$response = $ua->request($req);

	return $response;
}

sub kynetx_ua {
	my $credentials = shift;
	my $ua          = LWP::UserAgent->new();
	$ua->agent( Kynetx::Configure::get_config('HTTP_USER_AGENT')
		  || "Kynetx/1.0" );
	$ua->timeout( Kynetx::Configure::get_config('HTTP_TIMEOUT') || 5 )
	  ;    # default limit to 5 sec
	if ( defined $credentials ) {
		$ua->credentials(
			$credentials->{'netloc'},   $credentials->{'realm'},
			$credentials->{'username'}, $credentials->{'password'}
		);
	}
	return $ua;
}

sub run_function {
	my ( $req_info, $function, $args ) = @_;
	my ( $credentials, $uri, $params, $headers, $rheaders );
	my $logger = get_logger();
	my $resp = '';
	
	# Old style request
	$uri         = $args->[0];
	$params      = $args->[1];
	$headers     = $args->[2];
	$rheaders    = $args->[3];
	$credentials = undef;  #  Doesn't support credentials
	
	# http:<method>(<uri>,<options hash>);
	if ( defined $args->[1] && ref $args->[1] eq "HASH" ) {
		$logger->trace(
			"Second arg to http:get hash, Check for named arguments");
		$params      = $args->[1]->{'params'}           || $params;
		$headers     = $args->[1]->{'headers'}          || $headers;
		$credentials = $args->[1]->{'credentials'}      || $credentials;
		$rheaders    = $args->[1]->{'response_headers'} || $rheaders;
		if (defined $args->[1]->{'body'}) {
			$params = $args->[1]->{'body'};
		}
	}
	

	if ( $verbs->{$function}) {
		my $method = $function;
		my $response =
		  mk_http_request( $method, $credentials, $uri, $params, $headers );

		$resp = {
			'content'        => $response->decoded_content()        || '',
			'status_code'    => $response->code()                   || '',
			'status_line'    => $response->status_line()            || '',
			'content_type'   => $response->header('Content-Type')   || '',
			'content_length' => $response->header('Content-Length') || '',
		};

		if ( defined $rheaders ) {
			foreach my $h ( @{$rheaders} ) {
				$resp->{ lc($h) } = $response->header( uc($h) );
			}
		}

	}
	else {
		$logger->warn("Unknown function '$function' called in HTTP library");
	}

	return $resp;
}

1;
