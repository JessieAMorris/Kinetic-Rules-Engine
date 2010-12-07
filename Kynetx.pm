package Kynetx;
# file: Kynetx.pm
#
# Copyright 2007-2009, Kynetx Inc.  All rights reserved.
#
# This Software is an unpublished, proprietary work of Kynetx Inc.
# Your access to it does not grant you any rights, including, but not
# limited to, the right to install, execute, copy, transcribe, reverse
# engineer, or transmit it by any means.  Use of this Software is
# governed by the terms of a Software License Agreement transmitted
# separately.
#
# Any reproduction, redistribution, or reverse engineering of the
# Software not in accordance with the License Agreement is expressly
# prohibited by law, and may result in severe civil and criminal
# penalties. Violators will be prosecuted to the maximum extent
# possible.
#
# Without limiting the foregoing, copying or reproduction of the
# Software to any other server or location for further reproduction or
# redistribution is expressly prohibited, unless such reproduction or
# redistribution is expressly permitted by the License Agreement
# accompanying this Software.
#
# The Software is warranted, if at all, only according to the terms of
# the License Agreement. Except as warranted in the License Agreement,
# Kynetx Inc. hereby disclaims all warranties and conditions
# with regard to the software, including all warranties and conditions
# of merchantability, whether express, implied or statutory, fitness
# for a particular purpose, title and non-infringement.
#

use strict;
use warnings;


use XML::XPath;
use LWP::Simple;
use DateTime;
use Log::Log4perl qw(get_logger :levels);
use Cache::Memcached;
use JSON::XS;
use Data::Dumper;

use Kynetx::Events;
use Kynetx::Rules qw(:all);
use Kynetx::Util qw(:all);
use Kynetx::Session qw(:all);
use Kynetx::Memcached qw(:all);
use Kynetx::Console qw(:all);
use Kynetx::Version qw(:all);
use Kynetx::Configure qw(:all);
use Kynetx::Directives;


use constant DEFAULT_TEMPLATE_DIR => Kynetx::Configure::get_config('DEFAULT_TEMPLATE_DIR');

# Make this global so we can use memcache all over
our $memd;

my $s = Apache2::ServerUtil->server;

sub handler {
    my $r = shift;

    # configure logging for production, development, etc.
    Kynetx::Util::config_logging($r);

    my $logger = get_logger();

    $r->content_type('text/javascript');


    $logger->debug("\n\n>>>>---------------- begin ruleset execution-------------<<<<");
    $logger->debug("Initializing memcached");
    Kynetx::Memcached->init();

    my $method;
    my $rid;
    my $eid = '';

    ($method,$rid,$eid) = $r->path_info =~ m!/([a-z+_]+)/([A-Za-z0-9_;]*)/?(\d+)?!;
    $logger->debug("Performing $method method on rulesets $rid and EID $eid");
    Log::Log4perl::MDC->put('site', $rid);
    Log::Log4perl::MDC->put('rule', '[global]');  # no rule for now...

    # store these for later logging
    $r->subprocess_env(METHOD => $method);
    $r->subprocess_env(RIDS => $rid);

    # at some point we need a better dispatch function
    if($method eq 'eval') {
	process_rules($r, $method, $rid, $eid);
    } elsif($method eq 'event') {
	Kynetx::Events::process_event($r, $method, $rid, $eid);
    } elsif($method eq 'flush' ) {
	flush_ruleset_cache($r, $method, $rid);
    } elsif($method eq 'console') {
	show_context($r, $method, $rid);
    } elsif($method eq 'describe' ) {
	describe_ruleset($r, $method, $rid);
    } elsif($method eq 'version' ) {
	#my $session = process_session($r);
	show_build_num($r, $method, $rid);
    } elsif($method eq 'locktest') {
        lock_handle($r, $method, $rid, $eid);

    } elsif($method eq 'twitter_callback' ) {
	Kynetx::Modules::Twitter::process_oauth_callback($r, $method, $rid);
	$r->status(Apache2::Const::REDIRECT);
	return Apache2::Const::REDIRECT;

    } elsif($method eq 'kpds_callback' ) {
      Kynetx::Predicates::KPDS::process_oauth_callback($r, $method, $rid);
      $r->status(Apache2::Const::REDIRECT);
      return Apache2::Const::REDIRECT;

    } elsif($method eq 'google_callback' ) {
      Kynetx::Predicates::Google::process_oauth_callback($r, $method, $rid);
      $r->status(Apache2::Const::REDIRECT);
      return Apache2::Const::REDIRECT;
    } elsif($method eq 'fb_callback' ) {
      Kynetx::Predicates::Facebook::process_oauth_callback($r, $method, $rid);
      $r->status(Apache2::Const::REDIRECT);
      return Apache2::Const::REDIRECT;

    } elsif($method eq 'foo' ) {
	my $uniq = int(rand 999999999);
	$r->content_type('text/html');
	print "$uniq";
    } elsif($method eq 'mth') {
    	test_harness($r, $method, $rid, $eid);
    }


    return Apache2::Const::OK;
}

1;

sub lock_handle {
    my ($r, $method, $rid, $delay) = @_;
    my $tmp;
    my $msg = "Test Lock Request";
    my $logger = get_logger();
    my $var = "DonTerasse";
    my $var2 = "time";
    my $srid = "sandbox";
    $delay = $delay || 1;
    my $cookie = $r->headers_in->{'Cookie'};
    $cookie =~ s/^.*[;]?SESSION_ID=(\w*)[;]?.*$/$1/ if(defined $cookie);

    $r->content_type('text/html');
    print "<title>$msg</title><h1>$rid</h1>";

    $r->subprocess_env(START_TIME => Time::HiRes::time);
    my $req_info = Kynetx::Request::build_request_env($r, $method, $rid);
    my $prefix = time;
    # get a session
    my $session = process_session($r);
    my $session_lock = "lock-".Kynetx::Session::session_id($session);
    print "<p><strong>Using $cookie and ",Kynetx::Session::session_id($session),"</strong></p>";
    print "<p>$prefix</p>";



    Kynetx::Session::session_store($srid,$session,$var2,$prefix);
    Kynetx::Session::session_store($srid,$session,$var,"$prefix $rid");


    my $js = "";
    my $status = "";

    if ($req_info->{'_lock'}->lock($session_lock)) {
        $logger->debug("Session lock acquired for $session_lock");
        $status = "true";
    } else {
        $logger->warn("Session lock request timed out for ",sub {Dumper($rid)});
        $status = "false";
    }
    my $counter = Kynetx::Session::session_get($srid,$session,"counter");
    $counter = $counter || 0;
    my $got_lock = time;
    print "<p>$got_lock Lock request ($status)</p>";
    my $sess_val = "$rid $got_lock bink!";
    Kynetx::Session::session_store($srid,$session,$var,$sess_val);
    $logger->debug("Waiting----------------------------------------");
    my $opts;
    for(my $i = 0;$i<$delay;$i++) {
        sleep(5);
        my $val = Kynetx::Session::session_get($srid,$session,$var);
        $opts->{$i . "_"} = $val;

    }
    $tmp = Kynetx::Session::session_get($srid,$session,$var2);
    Kynetx::Directives::send_directive($req_info,$tmp,$opts);
    Kynetx::Session::session_store($srid,$session,$var,"$rid Endy $tmp");
    Kynetx::Session::session_store($srid,$session,"counter",++$counter);

    my $enda = Kynetx::Session::session_get($srid,$session,$var);
    my $endb = Kynetx::Session::session_get($srid,$session,$var2);
    Kynetx::Response::respond($r, $req_info, $session, $js, "Ruleset");
    print "<table><tr><td>$enda</td><td>$endb</td></tr></table>";
    Kynetx::Session::session_cleanup($session,$req_info);
    my $leftovers = Kynetx::Memcached::check_cache($session_lock);
    print "<p>Counter (",$counter,")</p>";
}


sub flush_ruleset_cache {
    my ($r, $method, $rid) = @_;

    my $logger = get_logger();

    my $req_info = Kynetx::Request::build_request_env($r, $method, $rid);
    # no locking

    # default to production for svn repo
    # defaults to production when no version specified

    my $version = Kynetx::Predicates::Page::get_pageinfo($req_info, 'param', ['kynetx_app_version']) || 'prod';

    $logger->debug("[flush] flushing rules for $rid ($version version)");
    my $memd = get_memd();
    $memd->delete(Kynetx::Repository::make_ruleset_key($rid, $version));

    $r->content_type('text/html');
    my $msg = "Rules flushed for site $rid";
    print "<title>$msg</title><h1>$msg</h1>";

}

sub describe_ruleset {
    my ($r, $method, $rid) = @_;

    my $logger = get_logger();

    my $req = Apache2::Request->new($r);
    my $flavor = $req->param('flavor') || 'html';

    $logger->debug("Getting ruleset $rid");


    my $req_info = Kynetx::Request::build_request_env($r, $method, $rid);
    # no locking

    my $ruleset = Kynetx::Repository::get_rules_from_repository($rid, $req_info);

    my $numrules = @{ $ruleset->{'rules'} } + 0;

    $logger->debug("Found $numrules rules..." );

    my $data = {
	'ruleset_id' => $ruleset->{'ruleset_name'},
	'ruleset_version' => $req_info->{'rule_version'},
	'number_of_rules' => $numrules,
	'name' => $ruleset->{'meta'}->{'name'} || '',
	'author' => $ruleset->{'meta'}->{'author'} || '',
	'description' => $ruleset->{'meta'}->{'description'} || '',
	'logging' => $ruleset->{'meta'}->{'logging'} || '',
    };


    my($active)  = 0;
    my($inactive) = 0;
    my @active_rules;
    my @inactive_rules;
    foreach my $rule ( @{ $ruleset->{'rules'} } ) {

	my $rule_info = {'rule_name' => $rule->{'name'},
			 'selected_using' => Kynetx::Actions::get_precondition_test($rule)
	};

	if($rule->{'state'} eq 'active') {
	    $active++;
	    push(@active_rules, $rule_info);
	} elsif($rule->{'state'} eq 'inactive') {
	    $inactive++;
	    push(@inactive_rules, $rule_info);
	}



    }

    $data->{'number_of_active_rules'} = $active;
    $data->{'active_rules'} = \@active_rules;
    $data->{'number_of_inactive_rules'} = $inactive;
    $data->{'inactive_rules'} = \@inactive_rules;

    my $json = new JSON::XS;


    if($flavor eq 'json') {
	$r->content_type('text/plain');
	print $json->encode($data) ;
    } else {
	# print the page
	my $template = DEFAULT_TEMPLATE_DIR . "/describe.tmpl";
	my $test_template = HTML::Template->new(filename => $template);

	my $html_data = $json->pretty->encode($data);
	$test_template->param(RULESET_ID => $data->{'ruleset_id'});
	$test_template->param(DATA => $html_data);


	$r->content_type('text/html');
	print $test_template->output;
    }
}
