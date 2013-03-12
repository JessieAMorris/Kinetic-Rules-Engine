package Kynetx::Modules::Twitter;
# file: Kynetx/Modules/Twitter.pm
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

use Apache2::Const;

use Net::Twitter::Lite;
#use Net::Twitter::OAuth;
use Data::Dumper;




use Kynetx::Session qw(:all);
use Kynetx::Persistence qw(:all);
use Kynetx::Memcached qw(:all);
use Kynetx::Configure qw(:all);
use Kynetx::Environments qw(:all);
use Kynetx::Rids qw(:all);
use Kynetx::Util qw(:all);
use Kynetx::Keys;

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (all => [
qw(
authorized
authorize
eval_twitter
) ]);
our @EXPORT_OK   =(@{ $EXPORT_TAGS{'all'} }) ;

use constant TWITTER_BASE_URL => 'http://twitter.com/';
use constant EXPIRE => '300'; # 300 seconds


my %predicates = (

);

sub get_predicates {
    return \%predicates;
}

my $actions = {
   'authorize' => {
       js => <<EOF,
function(uniq, cb, config) {
  \$K.kGrowl.defaults.header = "Authorize Twitter Access";
  if(typeof config === 'object') {
    \$K.extend(\$K.kGrowl.defaults,config);
  }
  \$K.kGrowl(KOBJ_twitter_notice);
  cb();
}
EOF
       before => \&authorize
   },
  'update' => {'js' => '',
	       'before' => \&update_action,
	       'after' => []
	     },

};

sub get_actions {
    return $actions;
}


my $funcs = {};

sub authorized {
 my ($req_info,$rule_env,$session,$rule_name,$function,$args)  = @_;
 my $logger = get_logger();

 my $rid = get_rid($req_info->{'rid'});

 $logger->debug("Authorizing twitter access for rule $rule_name in $rid");

 my $result = 1;


# $logger->debug("Consumer tokens: ", Dumper $consumer_tokens);

 my $access_tokens = get_access_tokens($req_info, $rule_env, $rid, $session);


 if (defined $access_tokens &&
     defined $access_tokens->{'access_token'} &&
     defined $access_tokens->{'access_token_secret'}) {
   # pass the access tokens to Net::Twitter

#  $logger->debug("Validating authorization using access_token = " . $access_tokens->{'access_token'} .
#		  " &  access_secret = " . $access_tokens->{'access_token_secret'} );


   my $nt = twitter($req_info, $rule_env, $session);

   # attempt to get the user's last tweet
   my $status = eval { $nt->verify_credentials() };
   if ($@ ) {
     $logger->trace("not authorized: ", sub {Dumper($status)});
     $result = 0;
   } else {
     $logger->trace("authorized: ", sub {Dumper($status)});
     $result = 1;
   }

 } else {
   $result = 0;
 }

 return $result;

}
$funcs->{'authorized'} = \&authorized;

sub user_id {
  my ($req_info,$rule_env,$session,$rule_name,$function,$args)  = @_;
  my $logger = get_logger();

  my $rid = get_rid($req_info->{'rid'});
  my $access_tokens =  get_access_tokens($req_info, $rule_env, $rid, $session);

  return $access_tokens->{'user_id'};

}
$funcs->{'user_id'} = \&user_id;

sub authorize {
 my ($req_info,$rule_env,$session,$config,$mods)  = @_;

 my $logger= get_logger();

 my $rid = get_rid($req_info->{'rid'});
 my $ruleset_name = $req_info->{"$rid:ruleset_name"};
 my $name = $req_info->{"$rid:name"};
 my $author = $req_info->{"$rid:author"};
 my $description = $req_info->{"$rid:description"};


 my $nt = twitter($req_info, $rule_env, $session);

 my $base_cb_url = 'http://' .
                   Kynetx::Configure::get_config('OAUTH_CALLBACK_HOST').
                   ':'.Kynetx::Configure::get_config('OAUTH_CALLBACK_PORT') .
                   "/ruleset/twitter_callback/$rid?";

 my $version = $req_info->{'rule_version'} || Kynetx::Rids::version_default();

 my $caller =
 my $callback_url = mk_url($base_cb_url,
			   {'caller',$req_info->{'caller'},
			    "$rid:kinetic_app_version", $version});

 $logger->debug("requesting authorization URL with callback_url = $callback_url");
 my $auth_url = $nt->get_authorization_url(callback => $callback_url);

 Kynetx::Persistence::save_persistent_var("ent",$rid, $session, 'twitter:token_secret', $nt->request_token_secret);


 $logger->debug("Got $auth_url ... sending user an authorization invitation");

 my $msg =  <<EOF;
<div id="KOBJ_twitter_auth">
<p>The application $name ($rid) from $author is requesting that you authorize Twitter to share your Twitter information with it.  </p>
<blockquote><b>Description:</b>$description</blockquote>
<p>
The application will not have access to your login credentials at Twitter.  If you click "Take me to Twitter" below, you will taken to Twitter and asked to authorize this application.  You can cancel at that point or now by clicking "No Thanks" below.  Note: if you cancel, this application may not work properly. After you have authorized this application, you will be redirected back to this page.
</p>
<div style="color: #000; background-color: #FFF; -moz-border-radius: 5px; -webkit-border-radius: 5px; padding: 10px;margin:10px;text-align:center;font-size:18px;"cursor": "pointer"">
<a href="$auth_url">Take me to Twitter</a></div>

<div style="color: #FFF; background-color: #F33; -moz-border-radius: 5px; -webkit-border-radius: 5px; padding: 10px;margin:10px;text-align:center;font-size:18px;"cursor": "pointer"" onclick="javascript:KOBJ.close_notification('#KOBJ_twitter_auth')">No Thanks!</div>
</div>
EOF

 my $js =  Kynetx::JavaScript::gen_js_var('KOBJ_twitter_notice',
		   Kynetx::JavaScript::mk_js_str($msg));

 return $js

}


sub process_oauth_callback {
  my($r, $method, $rid) = @_;

  my $logger = get_logger();

  # we have to contruct a whole request env and session
  my $req_info = Kynetx::Request::build_request_env($r, $method, $rid);
  my $session = process_session($r);
  my $req = Apache2::Request->new($r);
  my $request_token = $req->param('oauth_token');
  my $verifier      = $req->param('oauth_verifier');
  my $caller        = $req->param('caller');

  $logger->debug("User returned from Twitter with oauth_token => $request_token &  oauth_verifier => $verifier & caller => $caller");

  my $nt = twitter($req_info);

  $logger->debug("Successfully created Twitter object");

  $nt->request_token($request_token);
  $nt->request_token_secret(Kynetx::Persistence::get_persistent_var("ent",$rid, $session, 'twitter:token_secret'));


  # exchange the request token for access tokens
  my($access_token, $access_token_secret, $user_id, $screen_name) = $nt->request_access_token(verifier => $verifier);

  $logger->debug("Exchanged request tokens for access tokens. access_token => $access_token & secret => $access_token_secret & user_id = $user_id & screen_name = $screen_name");

  store_access_tokens($rid, $session,
        $access_token,
        $access_token_secret,
	$user_id,
        $screen_name
    );

  session_cleanup($session);

  $logger->debug("redirecting newly authorized tweeter to $caller");
  $r->headers_out->set(Location => $caller);
}



my $func_name = {
		 'blocking' => {
		    "name" => "blocking" ,
		    "parameters" => [qw/page/],
		    "required" => [qw/none/],
		   },
		 'blocking_ids' => {
				    "name" => "blocking_ids" ,
				    "parameters" => [qw/none/],
				    "required" => [qw/none/],
				   },

		 'favorites' => {
				 "name" => "favorites" ,
				 "parameters" => [qw/id page/],
				 "required" => [qw/none/],
				},

		 'followers' => {
				 "name" => "followers" ,
				 "parameters" => [qw/id user_id screen_name cursor/],
				 "required" => [qw/none/],
				},

		 'followers_ids' => {
				     "name" => "followers_ids" ,
				     "parameters" => [qw/id user_id screen_name cursor/],
				     "required" => [qw/id/],
				    },

		 'friends' => {
			       "name" => "friends" ,
			       "parameters" => [qw/id user_id screen_name cursor/],
			       "required" => [qw/none/],
			      },

		 'friends_ids' => {
				   "name" => "friends_ids" ,
				   "parameters" => [qw/id user_id screen_name cursor/],
				   "required" => [qw/id/],
				  },

		 'friends_timeline' => {
					"name" => "friends_timeline" ,
					"parameters" => [qw/since_id max_id count page/],
					"required" => [qw/none/],
				       },

		 'friendship_exists' => {
					 "name" => "friendship_exists" ,
					 "parameters" => [qw/user_a user_b/],
					 "required" => [qw/user_a user_b/],
					},

		 'home_timeline' => {
				     "name" => "home_timeline" ,
				     "parameters" => [qw/since_id max_id count page/],
				     "required" => [qw/none/],
				    },

		 'mentions' => {
				"name" => "mentions" ,
				"parameters" => [qw/since_id max_id count page/],
				"required" => [qw/none/],
			       },

		 'public_timeline' => {
				       "name" => "public_timeline" ,
				       "parameters" => [qw/none/],
				       "required" => [qw/none/],
				      },

		 'rate_limit_status' => {
					 "name" => "rate_limit_status" ,
					 "parameters" => [qw/none/],
					 "required" => [qw/none/],
					},

		 'retweeted_by_me' => {
				       "name" => "retweeted_by_me" ,
				       "parameters" => [qw/since_id max_id count page/],
				       "required" => [qw/none/],
				      },

		 'retweeted_of_me' => {
				       "name" => "retweeted_of_me" ,
				       "parameters" => [qw/since_id max_id count page/],
				       "required" => [qw/none/],
				      },

		 'retweeted_to_me' => {
				       "name" => "retweeted_to_me" ,
				       "parameters" => [qw/since_id max_id count page/],
				       "required" => [qw/none/],
				      },

		 'retweets' => {
				"name" => "retweets" ,
				"parameters" => [qw/id count/],
				"required" => [qw/id/],
			       },

		 'saved_searches' => {
				      "name" => "saved_searches" ,
				      "parameters" => [qw/none/],
				      "required" => [qw/none/],
				     },

		 'sent_direct_messages' => {
					    "name" => "sent_direct_messages" ,
					    "parameters" => [qw/since_id max_id page/],
					    "required" => [qw/none/],
					   },

		 'show_friendship' => {
				       "name" => "show_friendship" ,
				       "parameters" => [qw/source_id source_screen_name target_id target_id_name/],
				       "required" => [qw/id/],
				      },

		 'show_saved_search' => {
					 "name" => "show_saved_search" ,
					 "parameters" => [qw/id/],
					 "required" => [qw/id/],
					},

		 'show_status' => {
				   "name" => "show_status" ,
				   "parameters" => [qw/id/],
				   "required" => [qw/id/],
				  },

		 'show_user' => {
				 "name" => "show_user" ,
				 "parameters" => [qw/id/],
				 "required" => [qw/id/],
				},

		 'trends_available' => {
					"name" => "trends_available" ,
					"parameters" => [qw/lat long/],
					"required" => [qw/none/],
				       },

		 'trends_location' => {
				       "name" => "trends_location" ,
				       "parameters" => [qw/woeid/],
				       "required" => [qw/woeid/],
				      },

		 'user_timeline' => {
				     "name" => "user_timeline" ,
				     "parameters" => [qw/id user_id screen_name since_id max_id count page/],
				     "required" => [qw/none/],
				    },

		 'users_search' => {
				    "name" => "users_search" ,
				    "parameters" => [qw/q per_page page/],
				    "required" => [qw/q/],
				   },

		 'search' => {
			      "name" => "search" ,
			      "parameters" => [qw/q callback lang rpp page since_id geocode show_user/],
			      "required" => [qw/q/],
			     },

		 'trends' => {
			      "name" => "trends" ,
			      "parameters" => [qw/none/],
			      "required" => [qw/none/],
			     },

		 'trends_current' => {
				      "name" => "trends_current" ,
				      "parameters" => [qw/exclude/],
				      "required" => [qw/none/],
				     },

		 'trends_daily' => {
				    "name" => "trends_daily" ,
				    "parameters" => [qw/date exclude/],
				    "required" => [qw/none/],
				   },

		 'trends_weekly' => {
				     "name" => "trends_weekly" ,
				     "parameters" => [qw/date exclude/],
				     "required" => [qw/none/],
				    },
};

sub update_action {
  my ($req_info,$rule_env,$session,$config,$mods,$args,$vars)  = @_;
  my $logger = get_logger();
  $logger->debug("Twitter update action ");

  my $nt = twitter($req_info, $rule_env, $session);

  # construct the command and then get it
  my $tweets = eval {
    $nt->update($args->[0]);
  };

  if ( $@ ) {
    # something bad happened; show the user the error
    if ($@ =~ /\b401\b/) {
      $logger->warn("Unauthorized access: $@");
    } elsif ($@ =~ /\b502\b/) {
      $logger->warn("Fail Whale: $@");
    } else {
      $logger->warn("$@");
    }
    $tweets = $@;
  }

  my $v = $vars->[0] || '__dummy';
  $rule_env = add_to_env({$v => $tweets}, $rule_env) unless $v eq '__dummy';


  return '';
}

sub eval_twitter {
  my ($req_info,$rule_env,$session,$rule_name,$function,$args)  = @_;
  my $logger = get_logger();
  $logger->debug("eval_twitter evaluation with function -> ", $function);
  my $f = $funcs->{$function};
  if (defined $f) {
    return $f->($req_info,$rule_env,$session,$rule_name,$function,$args);
  } else {

    my $nt = twitter($req_info, $rule_env, $session);

    my $name = $func_name->{$function}->{'name'};

    my $tweets = eval {
      my $arg = '';
      if (ref $args eq 'ARRAY' && defined $args->[0]) {
	$arg = '$args->[0]';
      }
      my $command = "\$nt->$name(".$arg.");";
      $logger->debug("[eval_twitter] executing: $command");
      eval $command;
    };

    if ( $@ ) {
      # something bad happened; show the user the error
      if ($@ =~ /\b401\b/) {
	$logger->warn("Unauthorized access: $@");
      } elsif ($@ =~ /\b502\b/) {
	$logger->warn("Fail Whale: $@");
      } else {
	$logger->warn("$@");
      }
      $tweets = $@;
    }
    #$logger->debug("[eval_twitter] returning ", Dumper $tweets);


    return $tweets;

  }
}

sub twitter {
  my($req_info, $rule_env, $session) = @_;

  my $logger = get_logger();

  my $rid = get_rid($req_info->{'rid'});

  my $consumer_tokens=get_consumer_tokens($req_info, $rule_env);
#  $logger->debug("Consumer tokens: ", Dumper $consumer_tokens);
  my $nt = Net::Twitter::Lite->new(traits => [qw/API::REST OAuth/], %{ $consumer_tokens},legacy_lists_api => 0) ;

  my $access_tokens =  get_access_tokens($req_info, $rule_env, $rid, $session);
  if (defined $access_tokens &&
      defined $access_tokens->{'access_token'} &&
      defined $access_tokens->{'access_token_secret'}) {

#    $logger->debug("Using access_token = " . $access_tokens->{'access_token'} .
#		   " &  access_secret = " . $access_tokens->{'access_token_secret'} );


    $nt->access_token($access_tokens->{'access_token'});
    $nt->access_token_secret($access_tokens->{'access_token_secret'});
  }

  return $nt;

}

sub get_consumer_tokens {
  my($req_info, $rule_env) = @_;
  my $consumer_tokens;
  my $logger = get_logger();
  my $rid_info = $req_info->{'rid'};
  unless ($consumer_tokens = Kynetx::Keys::get_key($req_info, $rule_env, 'twitter')) {
    my $ruleset = Kynetx::Repository::get_rules_from_repository($rid_info, $req_info);
    $consumer_tokens = $ruleset->{'meta'}->{'keys'}->{'twitter'};

    Kynetx::Keys::insert_key($req_info, $rule_env, 'twitter', $consumer_tokens)
  }

#  $logger->debug("Consumer tokens: ", Dumper $consumer_tokens);

  return $consumer_tokens;
}

sub store_access_tokens {
  my ($rid, $session, $access_token, $access_token_secret, $user_id, $screen_name) = @_;

  my $r = Kynetx::Persistence::save_persistent_var("ent",$rid, $session, 'twitter:access_tokens', {
        access_token        => $access_token,
        access_token_secret => $access_token_secret,
	user_id => $user_id,
        screen_name => $screen_name
    });

  return $r;
}

sub get_access_tokens {
  my ($req_info, $rule_env, $rid, $session)  = @_;

  my $consumer_tokens=get_consumer_tokens($req_info, $rule_env);

  my $access_tokens;
  if ($consumer_tokens->{'oauth_token'}) {
    $access_tokens = {
        access_token        => $consumer_tokens->{'oauth_token'},
        access_token_secret => $consumer_tokens->{'oauth_token_secret'},
	user_id => $consumer_tokens->{'user_id'} || '',
        screen_name => $consumer_tokens->{'screen_name'} || ''
    }
  } else {
    $access_tokens = Kynetx::Persistence::get_persistent_var("ent",$rid, $session, 'twitter:access_tokens');
  }

  return $access_tokens;

}

1;
