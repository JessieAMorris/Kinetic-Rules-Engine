package Kynetx::Operators;
# file: Kynetx/Operators.pm
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
use Data::Dumper;
#use Storable qw(dclone);
use Clone qw(clone);
use List::MoreUtils;

use Kynetx::Expressions;
use Kynetx::JSONPath ;
use Kynetx::PrettyPrinter;
use Kynetx::Util qw/split_re/;
use Kynetx::Sets qw(:all);

use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (all => [
qw(
eval_pick
eval_length
eval_operator
) ]);
our @EXPORT_OK   =(@{ $EXPORT_TAGS{'all'} }) ;

my $kobj_root = Kynetx::Configure::get_config('KOBJ_ROOT') || '/web/lib/perl';
my $oper_dir = $kobj_root . "/Kynetx/Operators";
my @modules = <$oper_dir/*.pm>;
my %extensions;

my $funcs = {};

map {
    my ($class,$oname);
    m/.*\/(\w+).pm$/;
    $oname = lc($1);
    s/$kobj_root\///;
    s/\//::/g;
    s/\.pm$//;
    eval "use $_;";
    my $extension = $_ . "::" .$oname;
    $funcs->{$oname} = \&$extension;
    $extensions{$oname} = $extension;
} @modules;


sub eval_pick {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

#    $logger->debug("expr: ", sub { Dumper($expr)});
#    $logger->trace("[pick] rule_env: ", sub { Dumper($rule_env) });

    my $int = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    # if you don't clone this, it modified the rule env

    my $obj = Kynetx::Expressions::den_to_exp(clone($int));

#   $logger->debug("[pick] obj: ", sub { Dumper($obj) });

    return $obj unless defined $obj;


    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("[pick] rands: ", sub { Dumper($rands) });

    my $pattern = '';
    if($rands->[0]->{'type'} eq 'str') {
	$pattern = $rands->[0]->{'val'}
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[pick] pattern argument to pick not a string",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );

#	$logger->warn("WARNING: pattern argument to pick not a string");
    }
#    $logger->trace("pattern: ", $pattern);

    my $force_array = Kynetx::Expressions::true_value($rands->[1]);
#    my $force_array = $rands->[1]->{'val'};
#    $logger->debug("2nd arg: ", $force_array);


    my $jp = Kynetx::JSONPath->new();
    my $v = $jp->run($obj, $pattern);

    $logger->debug("[pick] obj after processing pick: ", sub { Dumper($v) });
    if ($force_array) {
        return Kynetx::Expressions::typed_value($v);
    }


#    $logger->debug("[pick] Rule env after: ", sub { Dumper($rule_env) });


    $v = $v->[0] if(defined $v && ref $v eq 'ARRAY' && int(@{ $v }) == 1);

    $logger->debug("pick using $pattern"); # returning ", Dumper($v));

    return Kynetx::Expressions::typed_value($v);
}
$funcs->{'pick'} = \&eval_pick;

#-----------------------------------------------------------------------------------
# array operators
#-----------------------------------------------------------------------------------

sub eval_length {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if ($obj->{'type'} eq 'array') {
	$v = @{ $obj->{'val'} } + 0;
    } elsif ($obj->{'type'} eq 'str') {
	$v = length($obj->{'val'});
    } else {
      $logger->debug("length used in non-array or non-string context");
    }

    return Kynetx::Expressions::typed_value($v);
}
$funcs->{'length'} = \&eval_length;

sub eval_head {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });

    my $v = 0;
    if ($obj->{'type'} eq 'array') {
	$v =$obj->{'val'}->[0];
    } else {
      $logger->debug("head used in non-array context");
    }

    return Kynetx::Expressions::typed_value($v);
}
$funcs->{'head'} = \&eval_head;

sub eval_tail {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if ($obj->{'type'} eq 'array') {
      my @a = @{$obj->{'val'}};
      shift @a;
      $v = \@a;
    } else {
      $logger->debug("tail used in non-array context");
    }

    return Kynetx::Expressions::typed_value($v);
}
$funcs->{'tail'} = \&eval_tail;


sub eval_sort {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });

    my $v = 0;
    if ($obj->{'type'} eq 'array') {


      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session) if (int(@{$expr->{'args'}}) > 0);

      if (defined $dval && lc(Kynetx::Expressions::den_to_exp($dval)) eq 'reverse') {
		my @a = sort {$b cmp $a} @{$eval};
		$v = \@a;
      } elsif (defined $dval && lc(Kynetx::Expressions::den_to_exp($dval)) eq 'numeric') {
      	my @a = sort {$a <=> $b} @{$eval};
		$v = \@a;
      } elsif (defined $dval && lc(Kynetx::Expressions::den_to_exp($dval)) eq 'ciremun') {
      	my @a = sort {$b <=> $a} @{$eval};
		$v = \@a;
      } elsif (defined $dval && Kynetx::Expressions::type_of($dval) eq 'closure') {
		my @a = sort {
		  	my $app = {'type' => 'app',
			     'function_expr' => $expr->{'args'}->[0],
			     'args' => [Kynetx::Expressions::typed_value($a),
					Kynetx::Expressions::typed_value($b)]};
	

		  	my $r = Kynetx::Expressions::den_to_exp(
		    	Kynetx::Expressions::eval_application($app,
							  $rule_env,
							  $rule_name,
							  $req_info,
							  $session));
	
#		  	$logger->debug("Sort function returned ",Dumper $r);
			if (JSON::XS::is_bool $r) {
			  $r = $r ? 1 : 0;
			}
	
		  	return $r;
			} @{$eval};

		$v = \@a;

#		$logger->debug("Array after sort ",Dumper $v);

      } else {
		my @a = sort {$a cmp $b} @{$eval};
        $logger->debug("Array after sorting ",Dumper @a);
		$v = \@a;
      }

    } else {
      $logger->debug("sort used in non-array context");
    }

    return Kynetx::Expressions::typed_value($v);

}
$funcs->{'sort'} = \&eval_sort;

sub eval_filter {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if (($obj->{'type'} eq 'array' ||
	 $obj->{'type'} eq 'hash') 
     && int(@{$expr->{'args'}}) > 0
       ) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	if ($obj->{'type'} eq 'array') {

	  my @a = grep 
	    {my $app = {'type' => 'app',
		       'function_expr' => $expr->{'args'}->[0],
		       'args' => [Kynetx::Expressions::exp_to_den($_)]};

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	   } @{$eval};

	  $v = \@a;
	  

# the preceding grep replaced this
# 	  my $a = [];
# 	  foreach my $av (@{$eval}) {


# 	    my $den_av = Kynetx::Expressions::exp_to_den($av);

# #	  $logger->debug("The value: ", sub { Dumper( $av ) });
# #	  $logger->debug("The denoted value: ", sub { Dumper( $den_av ) });

# 	    my $app = {'type' => 'app',
# 		       'function_expr' => $expr->{'args'}->[0],
# 		       'args' => [$den_av]};

# 	    my $r = Kynetx::Expressions::den_to_exp(
#   		      Kynetx::Expressions::eval_application($app,
# 							    $rule_env,
# 							    $rule_name,
# 							    $req_info,
# 							    $session));

# 	    push(@{$a}, $av) if $r;
#	  }
#        $v = $a;


	} else {

	  my @ks = keys %{$eval};
	  my @vs = values %{$eval};

	  my @a = List::MoreUtils::pairwise
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($a),
				   Kynetx::Expressions::exp_to_den($b)
				  ]
		       };

	     my $r = Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
             $r ? ($a, $b) : ();
	     
	    } @ks, @vs
	   ;

	  my %h = @a;
#	  $logger->debug("Filter of map returns: ", sub {Dumper \%h});
	  $v = \%h;
	}



      } else {
	$logger->debug("filter used with non-function argument");
      }
    } else {
      $logger->debug("filter used in non-array or non-map context or without argument");
    }

    return Kynetx::Expressions::typed_value($v);

}
$funcs->{'filter'} = \&eval_filter;

sub eval_collect {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {


	my $a = {};
	foreach my $av (@{$eval}) {


	  my $den_av = Kynetx::Expressions::exp_to_den($av);

#	  $logger->debug("The value: ", sub { Dumper( $av ) });
#	  $logger->debug("The denoted value: ", sub { Dumper( $den_av ) });

	  my $app = {'type' => 'app',
		     'function_expr' => $expr->{'args'}->[0],
		     'args' => [$den_av]};

	  my $r = Kynetx::Expressions::den_to_exp(
	    Kynetx::Expressions::eval_application($app,
						  $rule_env,
						  $rule_name,
						  $req_info,
						  $session));

	  $a->{$r} = [] unless $a->{$r};
	  push(@{$a->{$r}}, $av);

	}

	$v = $a;


      } else {
	$logger->debug("collect used with non-function argument");
      }
    } else {
      $logger->debug("collect used in non-array context or without argument");
    }

    return Kynetx::Expressions::typed_value($v);

}
$funcs->{'collect'} = \&eval_collect;

sub eval_map {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if (($obj->{'type'} eq 'array' ||
	 $obj->{'type'} eq 'hash') 
     && int(@{$expr->{'args'}}) > 0
       ) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	if ($obj->{'type'} eq 'array') {
	  my @a = map 
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($_)]};

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	   } @{$eval};

	  $v = \@a;


# we used to do this instead of using map
# 	my $a = [];
# 	foreach my $av (@{$eval}) {

# #	  $logger->debug("Mapping onto ", sub {Dumper $av});


# 	  my $den_av = Kynetx::Expressions::exp_to_den($av);

# #	  $logger->debug("Denoted as ", sub {Dumper $den_av});

# 	  my $app = {'type' => 'app',
# 		     'function_expr' => $expr->{'args'}->[0],
# 		     'args' => [$den_av]};

# 	  my $r = Kynetx::Expressions::den_to_exp(
# 	    Kynetx::Expressions::eval_application($app,
# 						  $rule_env,
# 						  $rule_name,
# 						  $req_info,
# 						  $session));

# #	  $logger->debug("Result is ", sub {Dumper $r});

# 	  push(@{$a}, $r);

# 	}

# 	$v = $a;

#	$logger->debug("Array after sort ",Dumper $v);
	} else {

	  my @ks = keys %{$eval};
	  my @vs = values %{$eval};

	  my @a = List::MoreUtils::pairwise
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($a),
				   Kynetx::Expressions::exp_to_den($b)
				  ]
		       };

	     my $r = Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
             ($a, $r);
	     
	    } @ks, @vs
	   ;

	  my %h = @a;
#	  $logger->debug("Filter of map returns: ", sub {Dumper \%h});
	  $v = \%h;
	}


      } else {
	$logger->debug("map used with non-function argument");
      }
    } else {
      $logger->debug("map used in non-array or non-map context or without argument");
    }

    return Kynetx::Expressions::typed_value($v);

}
$funcs->{'map'} = \&eval_map;

sub eval_pairwise {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {


	  my @a = List::MoreUtils::pairwise
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($a),
				   Kynetx::Expressions::exp_to_den($b)
				  ]
		       };

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	    } @{$eval->[0]}, @{$eval->[1]};

	  $v = \@a

	} else {
	  $logger->debug("pairwise used with non-function argument");
	}

    } else {
      $logger->debug("pairwise used in non-array context");
    }

#    $logger->debug("Pairwise array ", sub {Dumper $v});


    return Kynetx::Expressions::typed_value($v);

  }
$funcs->{'pairwise'} = \&eval_pairwise;



sub eval_reduce {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $obj_val = Kynetx::Expressions::den_to_exp($obj);

      my $dval;
      if (defined $expr->{'args'}->[1]) {
	$dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[1], $rule_env, $rule_name,$req_info, $session);
	unshift(@{$obj_val}, $dval);
      } else {
	$dval = Kynetx::Expressions::exp_to_den(0);
      }
                 

      my $op_fn = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);
      unless (Kynetx::Expressions::type_of($op_fn) eq 'closure') {
	$logger->debug("reduce used with non-function argument");
	return $dval;
      }
       

      my $obj_length = scalar @{$obj_val};

      my $result;
      if ($obj_length == 0) {
	$result = $dval;
      } else {
	$result = Kynetx::Expressions::exp_to_den(shift @{$obj_val});
	foreach my $av (@{$obj_val}) {

	  $logger->debug("Result so far ", sub {Dumper $result});
	  $logger->debug("Next value ", sub {Dumper Kynetx::Expressions::exp_to_den($av)});

	  my $app = {'type' => 'app',
		     'function_expr' => $op_fn,
		     'args' => [$result, 
				Kynetx::Expressions::exp_to_den($av),
			       ]};

	  $result = 
	    Kynetx::Expressions::eval_application($app,
						  $rule_env,
						  $rule_name,
						  $req_info,
						  $session);
	}
	
	
      }

      $v = Kynetx::Expressions::den_to_exp($result);

      $logger->debug("Reduced array ", sub {Dumper $v});

    } else {
      $logger->debug("reduce used in non-array context or without argument");
    }

    return Kynetx::Expressions::typed_value($v);

}
$funcs->{'reduce'} = \&eval_reduce;



sub eval_reverse {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array') {

      my $obj_val = Kynetx::Expressions::den_to_exp($obj);
      my @rev_obj_val = reverse @{$obj_val};
      $v = \@rev_obj_val;

    } else {
      $logger->debug("reverse used in non-array context");
    }

#    $logger->debug("Reversed array ", sub {Dumper $v});


    return Kynetx::Expressions::typed_value($v);

  }
$funcs->{'reverse'} = \&eval_reverse;

sub eval_any {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	$v = List::MoreUtils::any
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($_)
				  ]
		       };

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	    } @{$eval};



      } else {

	$logger->debug("any used with non-function argument");
      }


    } else {
      $logger->debug("any used in non-array context");
    }

#    $logger->debug("Any array ", sub {Dumper $v});


    if ($v) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }

  }
$funcs->{'any'} = \&eval_any;


sub eval_none {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	$v = List::MoreUtils::none
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($_)
				  ]
		       };

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	    } @{$eval};



      } else {

	$logger->debug("none used with non-function argument");
      }


    } else {
      $logger->debug("none used in non-array context");
    }

#    $logger->debug("None array ", sub {Dumper $v});


    if ($v) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }

  }
$funcs->{'none'} = \&eval_none;

sub eval_all {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	$v = List::MoreUtils::all
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($_)
				  ]
		       };

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	    } @{$eval};



      } else {

	$logger->debug("all used with non-function argument");
      }


    } else {
      $logger->debug("all used in non-array context");
    }

#    $logger->debug("All array ", sub {Dumper $v});


    if ($v) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }

  }
$funcs->{'all'} = \&eval_all;

sub eval_notall {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

    my $obj =
      Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v;
    if ($obj->{'type'} eq 'array' && int(@{$expr->{'args'}}) > 0) {

      my $eval = Kynetx::Expressions::den_to_exp($obj);

      my $dval = Kynetx::Expressions::eval_expr($expr->{'args'}->[0], $rule_env, $rule_name,$req_info, $session);

      if (Kynetx::Expressions::type_of($dval) eq 'closure') {

	$v = List::MoreUtils::notall
	    {my $app = {'type' => 'app',
			'function_expr' => $expr->{'args'}->[0],
			'args' => [Kynetx::Expressions::exp_to_den($_)
				  ]
		       };

	     Kynetx::Expressions::den_to_exp(
  		      Kynetx::Expressions::eval_application($app,
							    $rule_env,
							    $rule_name,
							    $req_info,
							    $session));
	    } @{$eval};



      } else {

	$logger->debug("notall used with non-function argument");
      }


    } else {
      $logger->debug("notall used in non-array context");
    }


    if ($v) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }

  }
$funcs->{'notall'} = \&eval_notall;


sub eval_join {
  my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
  my $logger = get_logger();
  my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("obj: ", sub { Dumper($obj) });
  return $obj unless defined $obj;

  my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->debug("obj: ", sub { Dumper($rands) });

  my $v = $obj->{'val'};
  my $join_val = Kynetx::Expressions::den_to_exp($rands->[0]);
  my $result;

  if($obj->{'type'} eq 'array' &&
     $rands->[0]->{'type'} eq 'str') {

    $result = join($join_val, @{$v});

  } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[join] not a string:  $join_val",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 )
  }

  return Kynetx::Expressions::typed_value($result);
}
$funcs->{'join'} = \&eval_join;

sub eval_append {
  my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
  my $logger = get_logger();
  my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

  my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->debug("obj: ", sub { Dumper($rands) });



  my $array1 = Kynetx::Expressions::den_to_exp($obj);
  my $array2 = Kynetx::Expressions::den_to_exp($rands->[0]);

  unless (ref $array1 eq 'ARRAY') {
    $array1 = [$array1];
  }

  unless (ref $array2 eq 'ARRAY') {
    $array2 = [$array2];
  }

  my @result = @{$array1};
  push(@result, @{$array2});

  $logger->trace("Append result: ", sub {Dumper @result});

  return Kynetx::Expressions::typed_value(\@result);
}
$funcs->{'append'} = \&eval_append;

sub eval_index {
  my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
  my $logger = get_logger();
  my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

  my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    $logger->debug("rands: ", sub { Dumper($rands) });

  my $arg_type = Kynetx::Expressions::type_of($rands->[0]);
  unless ( $arg_type eq 'str' 
        || $arg_type eq 'num' 
        || $arg_type eq 'regexp' 
        || $arg_type eq 'bool' 
         ) {
    
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[index] argument not an simple type",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );
      return Kynetx::Expressions::typed_value(-1);
  }

  my $result;

  if($obj->{'type'} eq 'array') {

#    $logger->debug("Looking for ", sub{ Dumper Kynetx::Expressions::den_to_exp($rands->[0]) });

    # get capture vars first
    $result = List::MoreUtils::first_index {val_eq($_, Kynetx::Expressions::den_to_exp($rands->[0]))}  @{$obj->{'val'}};

  } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[index] object not an array",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 )
  }



  $logger->debug("Index result: ", $result);

  return Kynetx::Expressions::typed_value($result);
}
$funcs->{'index'} = \&eval_index;


sub val_eq {
  my($first, $second) = @_;

  my $logger = get_logger();
  $logger->trace("First ", sub {Dumper $first});
  $logger->trace("Second ", sub {Dumper $second});
  if (JSON::XS::is_bool $first && 
      JSON::XS::is_bool $second) {
    return ! ($first xor $second)  # both false or both true
  } elsif (JSON::XS::is_bool $first ||  
           JSON::XS::is_bool $second)  { # one is bool and other is not
    return 0
  } else {
    return $first eq $second;
  }
}

#-----------------------------------------------------------------------------------
# string operators
#-----------------------------------------------------------------------------------

sub eval_replace {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();

#    $logger->debug("Expression: ", sub { Dumper($rule_env) });
#    $logger->debug("Expression: ", sub { Dumper($expr) });
    
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->debug("rands: ", sub { Dumper($rands) });

    my $v = $obj->{'val'};

    if(($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') &&
       $rands->[0]->{'type'} eq 'regexp' &&
       $rands->[1]->{'type'} eq 'str') {

	my $pattern = '';
	my $modifiers;
	($pattern, $modifiers) = split_re($rands->[0]->{'val'});

	$modifiers = $modifiers || '';

	my $embedable_modifiers = $modifiers;
	$embedable_modifiers =~ s/g//;

	my $re = qr/(?$embedable_modifiers)$pattern/;

	$logger->debug("Replacing string with $pattern & modifiers $modifiers: $re");

	# get capture vars first
	my @items = ( $v =~ $pattern );

	if($modifiers =~ m#g#) {
	  $v =~ s/$re/$rands->[1]->{'val'}/g;
 	} else {
	  $v =~ s/$re/$rands->[1]->{'val'}/;
 	}

	# now put capture vars in (this avoids evaling the replacement)
	for( reverse 0 .. $#items ){
	    my $n = $_ + 1;
	    #  Many More Rules can go here, ie: \g matchers  and \{ }
	    $v =~ s/\\$n/${items[$_]}/g ;
	    $v =~ s/\$$n/${items[$_]}/g ;
	}
      } else {
	Kynetx::Errors::raise_error($req_info, 'warn',
				    "[replace] not a regexp: $rands->[0]->{'val'}",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
	    unless $rands->[0]->{'type'} eq 'regexp';
      }


    return { 'type' => Kynetx::Expressions::infer_type($v),
	      'val' => $v
    }
}
$funcs->{'replace'} = \&eval_replace;

sub eval_match {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->debug("obj: ", sub { Dumper($rands) });

    my $v = $obj->{'val'};

    if(($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') &&
       $rands->[0]->{'type'} eq 'regexp') {

	my $pattern = '';
	my $modifiers;
	($pattern, $modifiers) = split_re($rands->[0]->{'val'});

	$modifiers = $modifiers || '';

	my $embedable_modifiers = $modifiers;
	$embedable_modifiers =~ s/g//;

	my $re = qr/(?$embedable_modifiers)$pattern/;

	$logger->debug("Matching string with $pattern & modifiers $modifiers: $re");

	# get capture vars first
	my @items = ( $v =~ $pattern );

	if($modifiers =~ m#g#) {
	  $v = ($v =~ m/$re/g);
 	} else {
	  $v = ($v =~ m/$re/);
 	}
#	$logger->debug("Match at ", pos($v));

      } else {
	Kynetx::Errors::raise_error($req_info, 'warn',
				    "[replace] not a regexp: $rands->[0]->{'val'}",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
	  unless $rands->[0]->{'type'} eq 'regexp';
      }


    if ($v) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }
}
$funcs->{'match'} = \&eval_match;

sub eval_extract {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    #$logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $is_match = 0;
    my @items = ();

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    #$logger->debug("obj: ", sub { Dumper($rands) });

    my $v = $obj->{'val'};

    if(($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') &&
       $rands->[0]->{'type'} eq 'regexp') {

    my $pattern = '';
    my $modifiers;
    ($pattern, $modifiers) = split_re($rands->[0]->{'val'});
    $modifiers = $modifiers || '';

    my $embedable_modifiers = $modifiers;
    $embedable_modifiers =~ s/g//;

    my $re = qr/(?$embedable_modifiers)$pattern/;

    $logger->debug("Matching string (with capture) with $pattern & modifiers $modifiers: $re");

#    my @caps = ( $v =~ $pattern );
#    $logger->debug("Binding matches: ", sub {Dumper(@caps)});
#    my $num = scalar(@caps);

    $_ = $v;

    $logger->trace("Mods: $modifiers, Emb: $embedable_modifiers");
    if($modifiers =~ m#g#) {
      @items = /$re/g;
    } else {
      @items = /$re/;
    }
#    $logger->debug("Global matches: ", sub {Dumper(@test)});
#
#    for (my $i = 1;$i<=$num;$i++) {
#        if (defined $-[$i]) {
#            my $match =  substr($v, $-[$i], $+[$i] - $-[$i]);
#            push(@items,$match);
#        } else {
#            last;
#        }
#    }
      } else {
	Kynetx::Errors::raise_error($req_info, 'warn',
				    "[extract] not a regexp: $rands->[0]->{'val'}",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
	    unless $rands->[0]->{'type'} eq 'regexp';
      }
#    $logger->debug("Items: ", sub {Dumper(@items)});

      return Kynetx::Expressions::typed_value(\@items);
}
$funcs->{'extract'} = \&eval_extract;

sub eval_uc {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    #$logger->trace("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;


    if($obj->{'type'} eq 'str') {
        my $v = $obj->{'val'};
        $v = uc($v);
#        $logger->debug("toUpper: ", $v);
        return Kynetx::Expressions::typed_value($v);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[uc] argument not a string",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'uc'} = \&eval_uc;

sub eval_lc {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    $logger->trace("obj: ", sub { Dumper($obj) });


    if($obj->{'type'} eq 'str') {
        my $v = $obj->{'val'};
        $v = lc($v);
#        $logger->debug("toLower: ", $v);
        return Kynetx::Expressions::typed_value($v);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[lc] argument not a string",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'lc'} = \&eval_lc;

sub eval_capitalize {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    #$logger->trace("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;


    if($obj->{'type'} eq 'str') {
        my $v = $obj->{'val'};
        $v = ucfirst($v);
#        $logger->debug("toUpper: ", $v);
        return Kynetx::Expressions::typed_value($v);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[capitalize] argument not a string",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'capitalize'} = \&eval_capitalize;

sub eval_trim {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    #$logger->trace("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    if($obj->{'type'} eq 'str') {
        my $v = $obj->{'val'};
	$v =~ s/^\s+//;
	$v =~ s/\s+$//;
#        $logger->debug("toUpper: ", $v);
        return Kynetx::Expressions::typed_value($v);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[trim] argument not a string",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'trim'} = \&eval_trim;

sub eval_split {
  my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
  my $logger = get_logger();
  my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#   $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

  my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->debug("obj: ", sub { Dumper($rands) });

  my $v = $obj->{'val'};

  # we ignore the modifiers
  my ($pattern, $modifiers) = split_re($rands->[0]->{'val'});

  my @items;
  if(($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') &&
     $rands->[0]->{'type'} eq 'regexp') {

    $logger->debug("Spliting string with $pattern");

    # get capture vars first
    @items = split($pattern,$v);

  } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[split] argument not a regexp",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
	  unless $rands->[0]->{'type'} eq 'regexp';
  }

  return Kynetx::Expressions::typed_value(\@items);
}
$funcs->{'split'} = \&eval_split;

sub eval_sprintf {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    $logger->trace("obj: ", sub { Dumper($obj) });

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->trace("obj: ", sub { Dumper($rands) });

    if($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') {
        my $v = $obj->{'val'};
	my $format = Kynetx::Expressions::den_to_exp($rands->[0]);
	$logger->debug("Formatting $v with $format");
        $v = sprintf($format,$v);
        return Kynetx::Expressions::typed_value($v);
    } else {
      my $msg = defined $obj ? "object undefined" 
                             : "object not a string or number";
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[sprintf] $msg",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'sprintf'} = \&eval_sprintf;

sub eval_range {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    $logger->trace("obj: ", sub { Dumper($obj) });

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->trace("obj: ", sub { Dumper($rands) });

    if(($obj->{'type'} eq 'str' || $obj->{'type'} eq 'num') &&
       $obj->{'type'} eq $rands->[0]->{'type'}
       ){
        my $from = $obj->{'val'};
	my $to = Kynetx::Expressions::den_to_exp($rands->[0]);
	$logger->debug("Creating array from $from to $to");
        my @v = ($from..$to);

#	$logger->debug("Generated array: ", sub {Dumper \@v});
        return Kynetx::Expressions::typed_value(\@v);
    } else {
      my $msg = defined $obj ? "object undefined" 
                             : "object not a string or number";
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[range] $msg",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'range'} = \&eval_range;

sub eval_substr {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    # $logger->trace("obj: ", sub { Dumper($obj) });

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
#    $logger->trace("obj: ", sub { Dumper($rands) });

    if($obj->{'type'} eq 'str') {
        my $v = $obj->{'val'};
	my $offset = Kynetx::Expressions::den_to_exp($rands->[0]);
	$logger->debug("Finding substring of  $v");

	if (defined $rands->[1])  {
	  my $length = Kynetx::Expressions::den_to_exp($rands->[1]);
	  $v = substr($v, $offset, $length);
	} else {
  	  $v = substr($v, $offset);
	}

        return Kynetx::Expressions::typed_value($v);
    } else {
      my $msg = defined $obj ? "object undefined" 
                             : "object not a string";
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[substr] $msg",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   )
    }
}
$funcs->{'substr'} = \&eval_substr;




#-----------------------------------------------------------------------------------
# Casting
#-----------------------------------------------------------------------------------

sub eval_as {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $orig_type = $expr->{'obj'}->{'type'};
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

    return $obj unless defined $obj;


    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);

    $logger->debug("obj: ", sub { Dumper($obj) }, " as ", $rands->[0]->{'val'} );

    my $v = 0;
    if ($obj->{'type'} eq 'str') {
      if ($rands->[0]->{'val'} eq 'num' || $rands->[0]->{'val'} eq 'regexp' ) {
	   $obj->{'type'} = $rands->[0]->{'val'};
      } elsif (uc($rands->[0]->{'val'}) eq 'JSON') {
          my $str = $obj->{'val'};
          return Kynetx::Expressions::typed_value(Kynetx::Json::jsonToAst_w($str));
      }
    } elsif ($obj->{'type'} eq 'num') {
      if ($rands->[0]->{'val'} eq 'str' ) {
	$obj->{'type'} = $rands->[0]->{'val'};
      }
    } elsif ($obj->{'type'} eq 'regexp') {
      if ($rands->[0]->{'val'} eq 'str') {
	$obj->{'type'} = $rands->[0]->{'val'};
      }
    } elsif ($orig_type eq 'persistent') {
      if ($rands->[0]->{'val'} eq 'array') {
        my $thing = $obj->{'val'};
        my $target=_prune_persitent_trail($thing);
        $obj->{'type'} = $rands->[0]->{'val'};
        $obj->{'val'} = $target;
      }
    # FIXME: The structure of this elsif doesn't match all the rest above.
    # We should be determining what the obj IS, then deciding what to do...
    } elsif ($rands->[0]->{'val'} eq 'str' || $rands->[0]->{'val'} eq 'json'){
        my $tmp = Kynetx::Expressions::den_to_exp($obj);
        $logger->trace("EXP: ", sub {Dumper($tmp)});
        #my $json = JSON::XS::->new->convert_blessed(1)->utf8(1)->encode($tmp);
        my $json = JSON::XS::->new->convert_blessed(1)->allow_nonref->encode($tmp);
        $logger->trace("JSON: ", $json);
        $obj->{'type'} = "str";
        $obj->{'val'} = $json;
        return $obj;
    }

    return $obj;
}
$funcs->{'as'} = \&eval_as;

sub eval_toRegexp {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);

#    $logger->debug("obj: ", sub { Dumper($obj) });
    return $obj unless defined $obj;

    my $v = 0;
    if ($obj->{'type'} eq 'str') {
      $obj->{'type'} = 'regexp';
    }

    return $obj;
}
$funcs->{'toRegexp'} = \&eval_toRegexp;

sub eval_encode {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    my $tmp = Kynetx::Expressions::den_to_exp($obj);
    $logger->trace("EXP: ", sub {Dumper($tmp)});
    #my $json = JSON::XS::->new->convert_blessed(1)->utf8(1)->encode($tmp);
    my $json = JSON::XS::->new->convert_blessed(1)->allow_nonref->encode($tmp);
    $logger->trace("JSON: ", $json);
    $obj->{'type'} = "str";
    $obj->{'val'} = $json;
    return $obj;

}
$funcs->{'encode'} = \&eval_encode;

sub eval_decode {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    $logger->debug("Encode type: ", $obj->{'type'});
    if ($obj->{'type'} eq 'str') {
        my $str = $obj->{'val'};
        return Kynetx::Expressions::typed_value(Kynetx::Json::jsonToAst_w($str));
    } else {
        return $obj;
    }

}
$funcs->{'decode'} = \&eval_decode;

#----------------------------------------------------------------------------------
# Set operations
#----------------------------------------------------------------------------------
sub _to_sets {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    return $obj unless defined $obj;


    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    my $a = $obj->{'val'};
    my $b = $rands->[0]->{'val'};
    if (ref $a eq '') {
        my @temp = ();
        push (@temp,$a);
        $a = \@temp;
    }
    if (ref $b eq '') {
        my @temp = ();
        push (@temp,$b);
        $b = \@temp;
    }
    if (ref $a eq 'ARRAY' and ref $b eq 'ARRAY') {
        return ($a,$b);
    } else {
        return undef;
    }
}

sub set_intersection {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::intersection($a,$b);
    return Kynetx::Expressions::typed_value($set);
}
$funcs->{'intersection'} = \&set_intersection;

sub set_union {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::union($a,$b);
    return Kynetx::Expressions::typed_value($set);
}
$funcs->{'union'} = \&set_union;

sub set_difference {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::difference($a,$b);
    return Kynetx::Expressions::typed_value($set);

}
$funcs->{'difference'} = \&set_difference;

sub set_has {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::has($a,$b);
    if ($set) {
      return Kynetx::Expressions::mk_expr_node('bool','true');
    } else {
      return Kynetx::Expressions::mk_expr_node('bool','false');
    }

}
$funcs->{'has'} = \&set_has;
$funcs->{'subset'} = \&set_has;

sub set_once {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::once($a);
    return Kynetx::Expressions::typed_value($set);
}
$funcs->{'once'} = \&set_once;

sub set_duplicates {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::duplicates($a);
    return Kynetx::Expressions::typed_value($set);
}
$funcs->{'duplicates'} = \&set_duplicates;

sub set_unique {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my ($a,$b) = Kynetx::Sets::from_operator($expr, $rule_env, $rule_name, $req_info, $session);
    my $set = Kynetx::Sets::unique($a);
    return Kynetx::Expressions::typed_value($set);
}
$funcs->{'unique'} = \&set_unique;

#----------------------------------------------------------------------------------
# Hash operations
#----------------------------------------------------------------------------------

sub _empty_hash {
	my ($path,$value) = @_;
	my $logger = get_logger();
	my $temp;
	my $element = pop(@$path);
	if ($element) {
		my $thing = _empty_hash($path,$value);
		$temp->{$element} = $thing;
		return $temp;
	} else {
		return $value
	}
}

sub _merge_hash {
	my ($hash_ref,$path,$value) = @_;
	my $logger = get_logger();
	my $element = shift @$path;
	my $has_more = scalar @$path;
	$hash_ref = {} unless (defined $hash_ref);
	if ($has_more) {
		my $temp = $hash_ref->{$element};
		if (ref $temp eq 'HASH') {
			_merge_hash($temp,$path,$value);
		} else {
			$hash_ref->{$element} = _empty_hash($path,$value);
		}
				
	} else {
		$hash_ref->{$element} = $value;
	}		
	
	
}

sub hash_put {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    return $obj unless defined $obj;

    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    my $type = $obj->{'type'};
    if ($type eq 'hash') {
        my $hash = clone ($obj->{'val'});
        my $path = Kynetx::Expressions::den_to_exp($rands->[0]);
        if (ref $path eq 'ARRAY') {
        	$logger->debug("Is array");
        	my $value = Kynetx::Expressions::den_to_exp($rands->[1]);
        	_merge_hash($hash,$path,$value);
        	return Kynetx::Expressions::typed_value($hash);        	
        } else {
	        foreach my $elem (@$rands) {
	            # only hash elements can be added to hashes
	            if ($elem->{'type'} eq 'hash') {
	                my $val = $elem->{'val'};
	                foreach my $rkey (keys %$val) {
	                    $hash->{$rkey} = $val->{$rkey};
	                }
	            } else {

		      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[put] only hashes may be added using put() operator",
				    {'rule_name' => $rule_name,
				     'genus' => 'operator',
				     'species' => 'type mismatch'
				    }
				   );

		      return $obj;
	            }
	        }        	
        }
        $logger->trace("New hash: ", sub {Dumper($hash)});
        return Kynetx::Expressions::typed_value($hash);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[put] operator not supported for objects of type: $type",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );

        return $obj;
    }
}
$funcs->{'put'} = \&hash_put;

sub hash_delete {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    return $obj unless defined $obj;
    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    my $type = $obj->{'type'};
    if ($type eq 'hash') {
        my $hash = clone ($obj->{'val'});
        my $path = Kynetx::Expressions::den_to_exp($rands->[0]);
        my $temp = $hash;
        my $path_str = join("",@$path);
        my $str = "";
        foreach my $path_element (@$path) {
        	$str .= $path_element;
        	if ($str eq $path_str) {
        		#$temp->{$path_element} = undef;
        		delete $temp->{$path_element};
        	} else {
        		$temp = $temp->{$path_element};
        		return $obj unless (defined $temp);
        	}
        	
        }
		return Kynetx::Expressions::typed_value($hash);
    } else {
      Kynetx::Errors::raise_error($req_info, 'warn',
				  "[delete] operator not supported for objects of type: $type",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );

        return $obj;
    }
}
$funcs->{'delete'} = \&hash_delete;

sub hash_keys {
	my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    my $type = $obj->{'type'};
	if ($type eq 'hash') {
		if (defined $rands->[0] && $rands->[0] ) {
			my $path = Kynetx::Expressions::den_to_exp($rands->[0]);
			if (ref $path eq '') {
				my $sub_hash = $obj->{'val'}->{$path};
				if (defined $sub_hash && ref $sub_hash eq "HASH") {
					my @keys = keys %{$sub_hash};
					return Kynetx::Parser::mk_expr_node('array',\@keys);
				}				
			} elsif (ref $path eq "ARRAY") {
				my $temp = clone ($obj->{'val'});
				my $path_str = join("",@$path);
				my $match = "";
				foreach my $element (@$path) {
					$match .= $element;
					$temp = $temp->{$element};					
					if (defined $temp && ref $temp eq "HASH") {
						if ( $path_str eq $match) {
							my @keys = keys %{$temp};
							return Kynetx::Parser::mk_expr_node('array',\@keys);
						} 
					}
				}				
			} else {
			  Kynetx::Errors::raise_error($req_info, 'warn',
				  "[keys] invalid operator argument",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );

			}
		} else {
			my @keys = keys %{$obj->{'val'}};
			return Kynetx::Parser::mk_expr_node('array',\@keys);
		}
	}
	return Kynetx::Parser::mk_expr_node('null','__undef__');
}
$funcs->{'keys'} = \&hash_keys;

sub hash_values {
	my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
    my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
    my $type = $obj->{'type'};
	if ($type eq 'hash') {
		if (defined $rands->[0] && $rands->[0] ) {
			my $path = Kynetx::Expressions::den_to_exp($rands->[0]);
			if (ref $path eq '') {
				my $sub_hash = $obj->{'val'}->{$path};
				if (defined $sub_hash && ref $sub_hash eq "HASH") {
					my @values = values %{$sub_hash};
					return Kynetx::Parser::mk_expr_node('array',\@values);
				}				
			} elsif (ref $path eq "ARRAY") {
				my $temp = clone ($obj->{'val'});
				my $path_str = join("",@$path);
				my $match = "";
				foreach my $element (@$path) {
					$match .= $element;
					$temp = $temp->{$element};					
					if (defined $temp && ref $temp eq "HASH") {
						if ( $path_str eq $match) {
							my @values = values %{$temp};
							return Kynetx::Parser::mk_expr_node('array',\@values);
						} 
					}
				}				
			} else {
			  Kynetx::Errors::raise_error($req_info, 'warn',
				  "[values] invalid operator argument",
				  {'rule_name' => $rule_name,
				   'genus' => 'operator',
				   'species' => 'type mismatch'
				  }
				 );

			}
		} else {
			my @values = values %{$obj->{'val'}};
			return Kynetx::Parser::mk_expr_node('array',\@values);
		}
	}
	return Kynetx::Parser::mk_expr_node('null','__undef__');
}
$funcs->{'values'} = \&hash_values;

#-----------------------------------------------------------------------------------
# Typing methods
#-----------------------------------------------------------------------------------

sub eval_null {
	my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
	my $logger = get_logger();
	my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
	my $isNull = 0;
	# Not optimizing test cases for easy debugging
	if (defined $obj) {
		if ($obj->{'type'} eq 'null') {
			$isNull = 1;
		} elsif (! defined $obj->{'val'}) {
			$isNull = 1;
		}
	} else {
		$isNull = 1;
	}
	
	if ($isNull) {
		return Kynetx::Parser::mk_expr_node('bool','true');
	} else {
		return Kynetx::Parser::mk_expr_node('bool','false');
	}
	
}
$funcs->{'isnull'} = \&eval_null;

sub eval_type {
	my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
	my $logger = get_logger();
	$logger->trace("Eval type of: ", sub {Dumper($expr)});
	my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
	my $t;
	if (defined $obj) {
		# Force possible(?) primitive to typed value
		my $tv = Kynetx::Expressions::typed_value($obj);
		$t =  $tv->{'type'};
	} else {
		$t = 'null';
	}
	return Kynetx::Parser::mk_expr_node("str",$t);
}
$funcs->{'typeof'} = \&eval_type;


sub eval_log {
  my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
  my $logger = get_logger();
  my $obj = Kynetx::Expressions::eval_expr($expr->{'obj'}, $rule_env, $rule_name,$req_info, $session);
  my $rands = Kynetx::Expressions::eval_rands($expr->{'args'}, $rule_env, $rule_name,$req_info, $session);
  my $msg = '';
  if (defined $rands->[0]  ) {
    $msg = Kynetx::Expressions::den_to_exp($rands->[0])
  } 
  my $val = Kynetx::Expressions::den_to_exp($obj);
  $logger->debug( $msg, ref $obj eq 'HASH' || 
		        ref $obj eq 'ARRAY' ? JSON::XS::->new->convert_blessed(1)->pretty(1)->encode($val) : $val );
  return $obj;
}
$funcs->{'klog'} = \&eval_log;



#-----------------------------------------------------------------------------------
# make it all happen
#-----------------------------------------------------------------------------------

sub eval_operator {
    my ($expr, $rule_env, $rule_name, $req_info, $session) = @_;
    my $logger = get_logger();
    $logger->debug("eval_operator evaluation with op -> ", $expr->{'name'});
    my $f = $funcs->{$expr->{'name'}};
    my $obj = &$f($expr, $rule_env, $rule_name, $req_info, $session);
    $logger->trace("Operator evaled to : ", sub {Dumper($obj)});
    return $obj;
}

sub _prune_persitent_trail {
    my ($source) = @_;
    if (ref $source eq 'ARRAY') {
        my @marry;
        foreach my $element (@$source) {
            push(@marry,$element->[0]);
        }
        return \@marry;
    }

}

sub list_extensions {
    my $logger = get_logger();
    return \%extensions;
}


1;
