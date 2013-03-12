package Kynetx::Request;

# file: Kynetx/Request.pm
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

use Data::Dumper;
use Log::Log4perl qw(get_logger :levels);
use IPC::Lock::Memcached;

use Kynetx::Rids;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION = 1.00;
our @ISA     = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (
  all => [
    qw(
      build_request_env
      log_request_env
      merge_request_env
      set_capabilities
      )
  ]
);
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

sub build_request_env {
  my ( $r, $method, $rids, $eventtype, $eid, $options ) = @_;

  my $logger = get_logger();

  # grab request params
  my $req = Apache2::Request->new($r);

  #$logger->debug("Raw request ", sub { Dumper $req->body() });

  my $domain = $req->param('_domain') || $method || 'discovery';
  $eventtype =
       $req->param('_type')
    || $req->param('_name')
    || $eventtype
    || 'hello';

  if ( $domain eq "discovery" && $eventtype eq "hello" ) {
    $logger->debug("No domain:type given; defaulting to discovery:hello");
  }

  # we rely on this being undef if nothing passed in
  $rids = $req->param('_rids') || $rids;
  my $explicit_rids = defined $req->param('_rids');
  
  $logger->debug("BRE Rids: ", sub {Dumper($rids)});

  # endpoint identifier
  my $epi = $req->param('_epi') || 'any';

  # endpoint location
  my $epl = $req->param('_epl') || 'none';

  # manage optional params
  # The ID token comes in as a header in Blue API
  my $id_token = $options->{'id_token'} || $r->headers_in->{'Kobj-Session'};
  my $api      = $options->{'api'}      || 'ruleset';

  # build initial envv
  my $ug = new Data::UUID;

  my $caller =
       $req->param('url')
    || $req->param('caller')
    || $r->headers_in->{'Referer'}
    || '';

  my $cookie = $r->headers_in->{'Cookie'};
  $cookie =~ s/^.*[;]?SESSION_ID=(\w*)[;]?.*$/$1/ if ( defined $cookie );

  my $request_info = {

    host => $r->connection->get_remote_host || $req->param('host') || '',
    caller => $caller,    # historical
    page   => $caller,
    url    => $caller,
    now    => time,
    method => $domain,

    # this is also determines the endpint capability type
    domain    => $domain,
    eventtype => $eventtype,
    eid       => $eid,

    id_token => $id_token,

    explicit_rids => $explicit_rids,

    epl => $epl,
    epi => $epi,

    _api => $api,

    hostname => $r->hostname(),
    ip       => $r->connection->remote_ip() || '0.0.0.0',
    ua       => $r->headers_in->{'User-Agent'} || '',

    #	pool => $r->pool,
    uri => $r->uri(),

    # set the default major and minor version for this endpoint
    # these may get overridden by parameters below
    majv => 0,
    minv => 0,

    txn_id => $ug->create_str(),
    g_id   => $cookie,

    # directives
    directives => [],
  };

  my @req_params = $req->param;
  foreach my $n (@req_params) {
    my $enc = Kynetx::Util::str_in( $req->param($n) );
    if ( ref $req->param($n) eq "" ) {
      $logger->debug( "Param $n -> ", $req->param($n), " ", $enc );
    }
    my $not_attr = {
      '_rids'   => 1,
      'referer' => 1
    };
    if ( $not_attr->{$n} ) {
      $request_info->{$n} = $enc;
    }
    else {
      add_event_attr( $request_info, $n, $enc );
    }
  }

  # handle explicit $rids
  if ( defined $rids ) {
    my $rid_array = [];
    foreach my $rid ( split( /;/, $rids ) ) {

      my $rid_info = Kynetx::Rids::mk_rid_info( $request_info, $rid );

      push( @{$rid_array}, $rid_info );
    }
    $rids = $rid_array;
  }

  $request_info->{'rids'} = $rids;
  $request_info->{'site'} = $rids;    #historical
       # this will get overridden with a single RID later
  $request_info->{'rid'} = $rids->[0];

  set_capabilities($request_info);

  $logger->debug("Returning request information");

  return $request_info;
}

# mutates $req_info with a new event_attribute
sub add_event_attr {
  my ( $req_info, $attr_name, $attr_val ) = @_;
  $req_info->{'event_attrs'}->{$attr_name} = $attr_val;
  push( @{ $req_info->{'event_attrs'}->{'attr_names'} }, $attr_name );
}

sub get_attr_names {
  my ($req_info) = @_;
  return $req_info->{'event_attrs'}->{'attr_names'};
}

sub get_attrs {
  my ($req_info) = @_;
  return $req_info->{'event_attrs'};
}

sub get_attr {
  my ( $req_info, $name ) = @_;
  return $req_info->{'event_attrs'}->{$name};
}

### final
sub set_final_flag {
  my ($self) = @_;
  my $logger = get_logger();
  $logger->debug("set final");
  $self->{ Kynetx::Rids::get_rid( $self->{rid} ) }->{'final_flag'} = 1;
}

sub clr_final_flag {
  my ($self) = @_;
  my $logger = get_logger();
  $logger->debug("clear final");

  undef $self->{ Kynetx::Rids::get_rid( $self->{rid} ) }->{'final_flag'};
}

sub get_final_flag {
  my ($self) = @_;
  my $logger = get_logger();
  $logger->debug("get final");
  
  return $self->{ Kynetx::Rids::get_rid( $self->{rid} ) }->{'final_flag'};
}

# merge multiple request environments, last wins
sub merge_req_env {
  my $first = shift;

  # don't overwrite the schedule or bad things happen...
  foreach my $req (@_) {
    foreach my $k ( keys %{$req} ) {
      $first->{$k} = $req->{$k} unless $k eq 'schedule';
    }
  }
  return $first;
}

sub log_request_env {
  my ( $logger, $request_info ) = @_;
  if ( $logger->is_debug() ) {
    foreach my $entry ( keys %{$request_info} ) {
      my $value = $request_info->{$entry};
      if ( $entry eq 'rids'
        || $entry eq 'site'
        || $entry eq 'rid' )
      {
        if ( ref $value eq 'ARRAY' ) {
          $value = Kynetx::Rids::print_rids($value);
        }
        elsif ( ref $value eq 'HASH' ) {
          $value = Kynetx::Rids::print_rid_info($value);
        }
      }
      elsif ( $entry eq 'event_attrs' ) {
        $value = "{";
        while ( my ( $k, $v ) = each %{ $request_info->{$entry} } ) {
          $value .= "$k:$v, ";
        }
        $value .= "}";

      }
      elsif ( ref $value eq 'ARRAY' ) {
        my @tmp = map { substr( $_, 0, 50 ) } @$value;
        $value = '[' . join( ',', @tmp ) . ']';
      }
      else {
        if ($value) {
          $value = substr( $value, 0, 50 );
        }
        else {
          $value = '';
        }

      }

      # print out first 50 chars of the request string
      $entry = 'undef' unless defined $entry;
      $value = 'undef' unless defined $value;
      $logger->debug("$entry:$value");

    }

    # 	foreach my $h (keys %{ $r->headers_in }) {
    # 	    $logger->debug($h . ": " . $r->headers_in->{$h});
    # 	}
  }

}

sub set_capabilities {
  my $req_info = shift;
  my $capspec  = shift;

  my $logger = get_logger();

  $capspec = Kynetx::Configure::get_config('capabilities') unless $capspec;

  #  $logger->debug("Cap spec ", sub { Dumper $capspec });

  if (
    $capspec->{ $req_info->{'domain'} }->{'capabilities'}
    ->{'understands_javascript'}
    || $req_info->{'domain'} eq 'eval'
    ||    # old style evaluation
    (
      $req_info->{'domain'} eq 'web'
      && !
      defined $capspec->{'web'}->{'capabilities'}->{'understands_javascript'}
    )
    || $req_info->{'domain'} eq 'oauth_callback'
    )
  {
    $req_info->{'understands_javascript'} = 1;
  }

}

1;
