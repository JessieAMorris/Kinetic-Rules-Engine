package Kynetx::MongoDB;
# file: Kynetx/MongoDB.pm
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
no warnings 'all';


use lib qw(
  /web/lib/perl
);

use Log::Log4perl qw(get_logger :levels);
use LWP::UserAgent;
use Data::Dumper;
use MongoDB qw(:all);
use MongoDB::GridFS;
use Tie::IxHash;
use Clone qw(clone);
use Benchmark ':hireswallclock';
use Data::Diver qw(
	Dive
);
use Devel::Size qw(
  size
  total_size
);
use Digest::MD5 qw(md5_base64);

use Kynetx::Configure;
use Kynetx::Json;
use Kynetx::Memcached;




use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (all => [
qw(
init
get_mongo
mongo
get_value
put_value
push_value
touch_value
update_value
get_collection
delete_value
make_keystring
get_cache
set_cache
get_hash_element
put_hash_element
delete_hash_element
validate
$CACHETIME
get_matches
) ]);
our @EXPORT_OK   =(@{ $EXPORT_TAGS{'all'} }) ;

our $MONGO;
our $MONGO_SERVER = "127.0.0.1";
our $MONGO_PORT = "27017";
our $MONGO_DB = "kynetx";
our $CACHETIME = 180;
our $DBREF;
our $COLLECTION_REF;
our $MONGO_MAX_SIZE = 838860;

use constant SAFE => 0;
use constant RETRIES => 5;

sub init {
    my $logger = get_logger();
#	if ($MONGO) {
#		return;
#	}
    $MONGO_SERVER = Kynetx::Configure::get_config('MONGO_HOST') || $MONGO_SERVER;
    $MONGO_PORT = Kynetx::Configure::get_config('MONGO_PORT') || $MONGO_PORT;
    $MONGO_DB = Kynetx::Configure::get_config('MONGO_DB') || $MONGO_DB;
    $CACHETIME = Kynetx::Configure::get_config('MONGO_CACHETIME') || $CACHETIME;
    $MONGO_MAX_SIZE = Kynetx::Configure::get_config('MONGO_MAX_SIZE') || $MONGO_MAX_SIZE;

    my @hosts = split(",",$MONGO_SERVER);
	$logger->debug("Initializing MongoDB connection");
	foreach my $host (@hosts) {
		eval {
			$MONGO = MongoDB::Connection->new(host => $host,find_master =>1,query_timeout =>5000);
		};
		if ($@) {
			$logger->debug($@);
		} else {
			my $master = $MONGO->{'_master'}->{'host'};
			$logger->trace("Master is $master");
			return;
		}
		
	}

}


sub get_mongo {
	my ($retry) = @_;
    my $logger = get_logger();
    init unless $MONGO;
    my $db;
    eval {$db = $MONGO->get_database($MONGO_DB)}; 
    if ($@) {
    	$retry = 1 unless ($retry);
    	if ($retry < RETRIES) {
    		$logger->debug("Get Mongo error: ",$@);
    		return get_mongo($retry++);    		
    	} elsif ($retry == RETRIES) {
    		$logger->warn("Get Mongo error: ",$@);
    		init;
    		return get_mongo($retry++); 
    	} else {
    		$logger->error("No connection to MongoDB")
    	}    	
    }
    return $db;
}

sub get_collection {
    my ($name) = @_;
    my $logger = get_logger();
    my $db = get_mongo();
    my $c;
    eval {
    	$c = $db->get_collection($name)
    };
    if ($@) {
    	$logger->warn("Get Collection error: ",$@);
    }
    return $c;
}

sub get_array_element {
	my ($collection, $key,$index) = @_;
	my $logger = get_logger();
    my $c = get_collection($collection);
    my $element = $c->find_one({'key' => $key},{'value'=>{'$slice'=>[$index,1]}});
    return $element;
}

sub get_hash_element {
  my ($collection, $vKey,$hKey) = @_;
  my $logger = get_logger();
  my $key = clone $vKey;
  my $c = get_collection($collection);
  if (defined $hKey && ref $hKey eq "ARRAY") {
    if (scalar @$hKey > 0) {
      $key->{'hashkey'} = {'$all' => $hKey};
    }
  }  
  $logger->trace("Element key: ", sub {Dumper($key)});  
  my $cursor = $c->find($key);
  if  ($cursor->has_next) {
    my @array_of_elements = ();
    my $last_updated = 0;
    while (my $object = $cursor->next) {
      if (defined $object->{'serialize'}) {
	# old style hash
	my $ast = Kynetx::Json::jsonToAst($object->{'value'});
	$logger->debug("Found old-style ", ref $ast, " to deserialize");
	$object->{'value'} = $ast;
	return $object;
      } elsif (! defined $object->{'hashkey'}) {
	# Somehow we pulled a non-hash ref
	$logger->warn("Hash Element requested, but found something else");
	return $object;
      }
      my $v = $object->{'value'};
      my $kv = $object->{'hashkey'};
      my $ts = $object->{'created'};
      if ($ts > $last_updated) {
	$last_updated = $ts;
      }
      push(@array_of_elements, {
				'ancestors' => $kv,
				'value' => $v
			       });
    }
    # reassemble (vivify) the hash from the elements
    my $frankenstein = Kynetx::Util::elements_to_hash(\@array_of_elements);
    my $value = Dive($frankenstein,@$hKey);
    my $composed_hash = clone ($vKey);
    $composed_hash->{'value'} = $value;
    $composed_hash->{'created'} = $last_updated;
    return $composed_hash;					
  } else {
    return undef;
  }
}

sub get_matches {
  my ($collection,$var) = @_;
  my $logger = get_logger();
  my $keystring = make_keystring($collection,$var);
  my $c = get_collection($collection);
  my $cursor = $c->find($var);
  my $obj_array = ();
  while (my $object = $cursor->next) {
    push(@{$obj_array},$object)
  } 
  return $obj_array; 
}

sub get_value {
    my ($collection,$var) = @_;
    my $logger = get_logger();
    my $keystring = make_keystring($collection,$var);
    my $cached = get_cache($collection,$var);
    if (defined $cached) {
        $logger->trace("Found $collection variable in cache (",sub {Dumper($cached)},",");
        $logger->debug("Found $collection variable in cache");
        return $cached;
    }  else {
        $logger->trace("$keystring not in cache");
        $logger->debug("$collection variable NOT cached");
    }
    my $c = get_collection($collection);
    if ($c) {
        my $cursor = $c->find($var);
        if  ($cursor->has_next) {
        	$logger->trace("Elements to retrieve: ", $cursor->count);
       		if ($cursor->count == 1) {
	        	my $result = $cursor->next();
	        	if (defined $result and $result->{'serialize'}) {
	            	my $ast = Kynetx::Json::jsonToAst($result->{"value"});
                	$logger->trace("Found a old style", ref $ast," to deserialize");
                	$result->{"value"} = $ast;	        		
	        	} elsif (defined $result and $result->{'hashkey'}) {
	        		my $hash = Kynetx::Util::elements_to_hash([{
	        			'ancestors' => $result->{'hashkey'},
	        			'value' => $result->{'value'}
	        		}]);
	        		my $composed_hash = clone ($var);
	        		$composed_hash->{'value'} = $hash;
	        		$composed_hash->{'created'} = $result->{'created'};
	        		return $composed_hash;
	        	}
	            $logger->trace("Save $keystring to memcache");
	            set_cache($collection,$var,$result);
	            return $result;
	        } else {
	        	my $composed_hash = clone ($var);
	        	my @array_of_elements = ();
	        	my $last_updated = 0;
	        	while (my $object = $cursor->next) {
	        		my $v = $object->{'value'};
	        		my $kv = $object->{'hashkey'};
	        		my $ts = $object->{'created'};
	        		if ($ts > $last_updated) {
	        			$last_updated = $ts;
	        		}
	        		push(@array_of_elements,{
						'ancestors' => $kv,
						'value' => $v
	        		});
	        	}
	        	my $hash = Kynetx::Util::elements_to_hash(\@array_of_elements);
	        	$logger->trace("Resurrected: ", sub {Dumper($hash)});
	        	$composed_hash->{'value'} = $hash;
	        	$composed_hash->{'created'} = $last_updated;
	        	return $composed_hash;
	        }
        	
        } else {
        	return undef;
        }
        

    } else {
        $logger->warn("Could not access collection: $collection");
        return undef;
    }
}

sub get_list {
  my ($collection,$var) = @_;
  my $logger = get_logger();
  my $keystring = make_keystring($collection,$var);
  my $cached = get_cache($collection,$var);
  if (defined $cached) {
      $logger->trace("Found $collection variable in cache (",sub {Dumper($cached)},",");
      return $cached;
  }  else {
      $logger->trace("$keystring not in cache");
  }
  my $c = get_collection($collection);
  my @rlist;
  if ($c) {
    my $cursor = $c->find($var);
    while (my $object = $cursor->next) {
        push(@rlist,$object);
    }
    return \@rlist;
  }
  return undef;
}

sub atomic_pop_value {
	my ($collection,$var,$direction) = @_;
	my $logger = get_logger();
	$direction ||= -1;
    my $c = get_collection($collection);
    my $cursor = $c->find($var,{"value" => {'$slice' => [0,1]}});
    $logger->trace("# In mongo: ", $cursor->count);	
    my $result;
    if ($cursor->has_next) {
		my $object = $cursor->next;   
		$logger->trace("Cursor: ", sub {Dumper($object)});
		$result = $object->{'value'}->[0];	
    } else {
    	$logger->debug("Cursor empty ");
    }
	$c->update($var,{'$pop' => {"value" => -1}});
	clear_cache($collection,$var);
	if (defined $result) {
		return $result;
	} else {
		return undef;
	}
}

sub atomic_push_value {
	my ($collection,$var,$value) = @_;
	my $logger = get_logger();
    my $c = get_collection($collection);
    my $result = $c->update($var,{'$push' => {"value" => $value}},{"safe" => SAFE,'upsert' => 1});
}

##
#   Default is to POP variable from end of stack
##
sub pop_value {
    my ($collection,$var,$direction) = @_;
    my $logger = get_logger();
    my $first = -1;
    my $last = 1;
    my $op_name = $direction ?  "Shift" : "Pop" ;
    if ($op_name eq "Pop") {
        $direction = $last;
    } else {
        $direction = $first;
    }
    $logger->trace("$op_name from ", sub {Dumper($var)});
    my $keystring = make_keystring($collection,$var);
    my $c = get_collection($collection);
    my $res;
    if ($c) {
    	my $val = get_value($collection,$var);
    	if (ref $val ne "HASH") {
    		return $val;
    	}
        my $trail = $val->{"value"};
        $logger->trace("Stack: ",sub {Dumper($trail)});
        if (ref $trail eq "ARRAY") {
            if ($direction == 1) {
                $res = pop @{$trail};
            } else {
                $res = shift @{$trail};
            }
        } else {
            delete_value($collection,$var);
            return $trail;
        }
        if ($res) {
            my $status = $c->update($var,{'$pop' => {"value" => $direction}},{"safe" => SAFE});
            clear_cache($collection,$var);
            return $res;
        } else {
            return undef;
        }
    } else {
        $logger->info("Could not access collection: $collection");
        return undef;
    }
}



sub touch_value {
    my ($collection,$var,$ts) = @_;
    my $logger = get_logger();
    my $timestamp;
    if (defined $ts) {
        $timestamp = $ts->epoch;
    } else {
        $timestamp = DateTime->now->epoch;
    }
    my $result = get_value($collection,$var);
    my $status;
    if (defined $result->{"value"}) {
        my $oid = $result->{"_id"};
        my $c = get_collection($collection);
        $status = $c->update($var,{'$set' => {"created" => $timestamp}});
        if ($status) {
            clear_cache($collection,$var);
        }
    } else {
        my $val = {%$var};
        $val->{"value"} =0,
        $status = update_value($collection,$var,$val,1,0);
    }
    $logger->warn("Failed to update timestamp in $collection for: ", sub {Dumper($var)}) unless ($status);
    return get_value($collection,$var);
}

sub counter {
	my ($name) = @_;
	my $collection = 'dictionary'; # static collection
	my $query = {
		"_id" => $name
	};
	my $update = {
		'$inc' => {"next" => 1}
	};
	my $new = 'true';
	my $upsert = 'true';
	my $fnmod = {
		'query' => $query,
		'update' => $update,
		'new' => $new,
		'upsert' => $upsert,
	};
	my $result = Kynetx::MongoDB::find_and_modify($collection,$fnmod);
	return $result->{"next"};
	
}

sub push_value {
    my ($collection,$var,$val,$as_trail) = @_;
    my $logger = get_logger();
    $logger->trace("Push ", sub {Dumper($val)}," onto ", sub {Dumper($var)});
    my $c = get_collection($collection);
    my $status;
    eval {
        $status = $c->update($var,{'$push' =>
            {"value" => $val->{"value"}}},{"upsert"=>1,"safe" => 1});
    };
    if ($@) {
        $logger->debug("Existing var not an array");
        my $result = get_value($collection,$var);
        my $timestamp = $result->{"created"};
        $timestamp = DateTime->now->epoch unless ($timestamp);
        my $value = $result->{"value"};
        my $narry;
        if ($as_trail) {
            $logger->debug("Push var as trail");
            my $tuple = [$value, $timestamp];
            $narry = [$tuple];
        } else {
            $narry = [$value];
        }
        push(@$narry,$val->{"value"});
        my $tmp = clone($val);
        $tmp->{"value"} = $narry;
        update_value($collection,$var,$tmp,0,0,1);
        clear_cache($collection,$status);
    } elsif ($status) {
        clear_cache($collection,$var);
        return $status;
    }
}

sub type_data {
    my ($collection,$var) = @_;
    my $var_list;
    my $c = get_collection($collection);
  	my $cursor = $c->find($var);
  	if  ($cursor->has_next) {
    	while (my $object = $cursor->next) {
    		my $key = $object->{'key'};
    		next if ($var_list->{$key});
    		next if ($key=~ m/:event_list$|:sm_current$/);
    		if (defined $object->{'hashkey'}) {
    			$var_list->{$key} = 'hash';
    		} else {
    			$var_list->{$key} = Kynetx::Expressions::infer_type($object->{'value'})
    		}
    		
    	}
  	}
  	return $var_list;
	
}


# find_and_modify uses the generic run_command function of the mongo library
# limit the parameters passed in to avoid passing in random commands
# (Such commands *should* have been filtered long before)
sub find_and_modify {
	my ($collection,$query,$verbose) = @_;
	my @options = ("query","sort","remove","update","new","fields","upsert");
	my $logger = get_logger();
	my $db = get_mongo();
	my $command = {
		"findAndModify" => $collection
	};
	$logger->trace("Query: ", ref $query, sub {Dumper($query)});
	if (ref $query eq 'HASH') {
		foreach my $key (@options) {
			#$logger->trace("Key: $key");
			if (defined $query->{$key}) {
				$command->{$key} = $query->{$key};
				#$logger->trace("Val: ", sub {Dumper($query->{$key})});
			}
		}
	}
	$logger->trace("Composed command: ", sub {Dumper($command)});
	my $status = $db->run_command($command);
	
	# Something may have changed in the database so flush data from memcache in case
	# $query should have the key so we can flush the cache
	if (defined $command->{'query'}) {
		clear_cache($collection,$command->{'query'});		
	}
	if (defined $status && ref $status eq 'HASH' && $status->{'ok'}) {
		if ($verbose) {
			return $status;
		} else {
			return $status->{'value'};
		}
		
	} else {
		$logger->debug("Query failed: ", sub {Dumper($status)});
		return undef;
	}
	
		
}

# find and modify only operates on a max of one document, so it won't work
# for hashed variables
sub get_singleton {
	my ($collection, $var) = @_;
	my $logger = get_logger();
    my $keystring = make_keystring($collection,$var);
    my $cached = get_cache($collection,$var);
    if (defined $cached) {
        $logger->trace("Found $collection variable in cache (",sub {Dumper($cached)},",");
        return $cached;
    }  else {
        $logger->trace("$keystring not in cache");
    }
	my $ts = DateTime->now->epoch;
	my $update = {
		'$inc' => {'accesses' => 1},
		'$set' => {'last_active' => $ts}
	};
	
	my $fnmod = {
		'query' => $var,
		'update' => $update,
	};
	$logger->trace("Find and modify:" , sub {Dumper($fnmod)});
	my $result = find_and_modify($collection,$fnmod,1);          
    $logger->trace("Status: ", sub {Dumper($result)});
	if (defined $result->{"value"}) {
		set_cache($collection,$var,$result->{"value"});
		return $result->{"value"};		
	} else {
		return undef;
	}
	
}

sub validate {
	my ($val) = @_;
	my $logger = get_logger();
	my $size = Devel::Size::total_size($val);
	if ($size > $MONGO_MAX_SIZE) {
		$logger->debug("Value is larger than $MONGO_MAX_SIZE bytes");
		return 0;
	} else {
		return 1;
	}
	
	
}

sub update_value {
    my ($collection,$var,$val,$upsert,$multi,$safe) = @_;
    my $logger = get_logger();
    $safe = $safe || SAFE;
    my $serialize = 0;
    my $timestamp = DateTime->now->epoch;
    if (ref $val->{"value"} eq "HASH") {
        return put_hash_element($collection,$var,[],$val);
    }
    $val->{"serialize"} = $serialize;
    $val->{"created"}   = $timestamp;
    $upsert = ($upsert) ? 1 : 0;
    $multi = ($multi) ? 1 : 0;
    my $c = get_collection($collection);
    my $status = $c->update($var,$val,{"upsert" => $upsert,"multiple" => $multi, "safe" => $safe});
    if ($status) {
        clear_cache($collection,$var);
        return $status;
    } else {
        $logger->warn("Failed to insert in $collection: ", sub {Dumper($val)});
        return undef;
    }

}

# Delete all references to $var so we can do a bulk insert
sub put_hash {
	my ($collection,$var,$val,$upsert,$multi,$safe) = @_;
	my $logger = get_logger();
	delete_value($collection,$var);
    my $timestamp = DateTime->now->epoch;
	my @batch_elements=();
	my $array_of_hash_elements = Kynetx::Util::hash_to_elements($val->{'value'});
	foreach my $element (@$array_of_hash_elements) {
		my $object = clone ($var);
		my $hash_key = $element->{'ancestors'};
		my $value = $element->{'value'};
		$object->{'hashkey'} = $hash_key;
		$object->{'value'} = $value;
		$object->{'created'} = $timestamp;
		push(@batch_elements,$object);		
	}
	my $c = get_collection($collection);
	my @ids = $c->batch_insert(\@batch_elements);
	$logger->trace("Inserted ",scalar @ids," hash elements");
	return scalar @ids == scalar @$array_of_hash_elements;
}

sub put_array {
	
}

sub put_blob {
	my ($fh,$meta) = @_;
	my $db = get_mongo();
	my $grid = $db->get_gridfs();
	my $id =  $grid->insert($fh,$meta);
	if (defined $id) {
		return $id->value;
	} else {
		return undef;
	}		
}

sub get_blob {
	my ($id) = @_;
	my $db = get_mongo();
	my $grid = $db->get_gridfs();
	my $file = $grid->get($id);
	return $file;
}

sub put_hash_element {
	my ($collection,$vKey,$hKey,$val) = @_;
	my $logger = get_logger();
	my $timestamp = DateTime->now->epoch;
    my $c = get_collection($collection);
	if (ref $hKey eq 'ARRAY') {
		delete_hash_element($collection,$vKey,$hKey);		
		my @adds = ();
		my $a_of_hash_elements = Kynetx::Util::hash_to_elements($val->{'value'},$hKey);
		if (ref $a_of_hash_elements ne "ARRAY") {
			push(@adds, $a_of_hash_elements);
		} else {
			@adds = @$a_of_hash_elements;
		}
		my @batch_elements = ();
		my $timestamp = DateTime->now->epoch;
		foreach my $element (@adds) {
			my $object = clone $vKey;
			$object->{'hashkey'} = $element->{'ancestors'};
			$object->{'value'} = $element->{'value'};
			$object->{'created'} = $timestamp;
			push(@batch_elements,$object);
		}
		my @ids = $c->batch_insert(\@batch_elements);
		$logger->trace("Inserted ",scalar @ids," hash element(s)");
		return scalar @ids;
	}
}

sub delete_hash_element {
	my ($collection,$vKey,$hKey) = @_;
	my $logger = get_logger();
	# Protect me from doing something stupid	
	if (ref $vKey eq "HASH") {
		if (
			((defined $vKey->{'key'}) 
				&& ($vKey->{'key'} ne ""))
			|| 	((defined $vKey->{'ken'}) 
				&& ($vKey->{'ken'} ne ""))
		  || ((defined $vKey->{'rid'}) 
				&& ($vKey->{'rid'} ne ""))
			) {
			my $del = clone ($vKey);
		    my $c = get_collection($collection);
			if (ref $hKey eq 'ARRAY' && scalar @$hKey > 0) {
				$del->{'hashkey'} = {'$all' => $hKey};
			}
			my $success = $c->remove($del,{'safe' => 1});
			$logger->trace("Delete results ",sub {Dumper($success)});
			if (defined $success) {
				if ($success->{'ok'}) {
					my $count = $success->{'n'};
					$logger->trace("Deleted $count hash element(s) from ", $del->{'key'});
				} else {
					$logger->trace("Mongodb error trying to delete ", sub {Dumper($del)},
						" error msg: ", $success->{'err'});
				}
			} else {
				$logger->warn("Mongodb error trying to delete ", sub {Dumper($del)});
			}
		} else {
			$logger->debug("Key not valid: ", sub {Dumper($vKey)});
		}
	} else {
		$logger->debug("Key not a hash");
	}
}

sub mongo_error {
    my $database = get_mongo();
    return $database->last_error();
}

sub delete_value {
    my ($collection,$var) = @_;
    my $logger = get_logger();
    $logger->trace("Deleting from $collection: ", sub {Dumper($var)});
    my $c = get_collection($collection);
    my $success = $c->remove($var,{"safe" => 1});
    clear_cache($collection,$var);
    if (!$success ) {
        $logger->debug("Delete error: ", mongo_error());
    }
    return $success;
}


sub get_cache {
    my ($collection,$var) = @_;
    my $logger = get_logger();
    my $keystring = make_keystring($collection,$var);
    $logger->trace("Cache keystring (get) $keystring: ", sub {Dumper($var)});
    my $result = Kynetx::Memcached::check_cache($keystring);
    if (defined $result) {
        $logger->trace("Cache found: ", sub {Dumper($result)});
        return $result;
    } else {
        $logger->trace("not found");
        return undef;
    }
}

sub set_cache {
    my ($collection,$var,$value) = @_;
    my $logger = get_logger();
    my $parent = (caller(1))[3];
    my $keystring = make_keystring($collection,$var);
    $logger->trace("Cache keystring (set) $keystring: ", sub {Dumper($var)});
    Kynetx::Memcached::mset_cache($keystring,$value,$CACHETIME);
}

sub clear_cache {
    my ($collection,$var) = @_;
    my $keystring = make_keystring($collection,$var);
    Kynetx::Memcached::flush_cache($keystring);
}

sub make_keystring {
    my ($collection,$var) = @_;
    my $keystring = $collection;
    foreach my $key (sort (keys %$var)) {
    	if ($var->{$key}) {
    		$keystring .= $var->{$key};
    	}        
    }
    return md5_base64($keystring);
}

########################### Caching functions for KPDS/KEN based maps
sub get_cache_for_map {
	my ($key,$collection,$var) = @_;
	my $logger = get_logger();
	my $lookup_key = "_map_" . $key;
	my $mcache_prefix = Kynetx::Memcached::check_cache($lookup_key);
	$logger->trace("$lookup_key: ", sub {Dumper($mcache_prefix)});
	if (defined $mcache_prefix) {
		$var->{"cachemap"} = $mcache_prefix;
		return Kynetx::MongoDB::get_cache($collection,$var);
	}
	return undef;
}

sub set_cache_for_map {
	my ($key,$collection,$var,$value) = @_;
	my $logger = get_logger();
	my $lookup_key = "_map_" . $key;
	my $mcache_prefix =  time();
	Kynetx::Memcached::mset_cache($lookup_key,$mcache_prefix,$CACHETIME);
	$logger->trace("Set master $lookup_key: ($mcache_prefix)");
	$var->{"cachemap"} = $mcache_prefix;
	Kynetx::MongoDB::set_cache($collection,$var,$value);
}

sub clear_cache_for_map {
	my ($key) = @_;
	my $logger=get_logger();
	my $lookup_key = "_map_" . $key;
	$logger->trace("Lookup key for cache map: ", $lookup_key);
	Kynetx::Memcached::flush_cache($lookup_key);
}

sub map_key {
	my ($key,$hkey) = @_;
	my $logger = get_logger();
	my $struct = {
		'a' => $key
	};
	my $index = 0;
	foreach my $element (@{$hkey}) {
		my $k = 'b' . $index++;
		$struct->{$k} = $element;
	}
	$logger->trace("Map Key: ", sub {Dumper($struct)});
	return $struct;
}


1;

