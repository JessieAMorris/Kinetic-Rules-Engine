#!/usr/bin/perl -w
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
use lib qw(/web/lib/perl);
use strict;
use warnings;
use charnames ':full';

use Test::More;
use Test::LongString;
use Test::Deep;

use Apache::Session::Memcached;
use DateTime;
use APR::URI;
use APR::Pool ();
use Cache::Memcached;


# most Kyentx modules require this
use Log::Log4perl qw(get_logger :levels);
Log::Log4perl->easy_init($INFO);
#Log::Log4perl->easy_init($DEBUG);

use Kynetx::Test qw/:all/;
use Kynetx::Modules::This2That qw/:all/;
use Kynetx::Modules;
use Kynetx::Environments qw/:all/;
use Kynetx::Session qw/:all/;
use Kynetx::Configure qw/:all/;



use Kynetx::FakeReq qw/:all/;


use Data::Dumper;
$Data::Dumper::Indent = 1;

my $logger = get_logger();

my $preds = Kynetx::Modules::This2That::get_predicates();
my @pnames = keys (%{ $preds } );



my $r = Kynetx::Test::configure();

my $rid = 'cs_test';

# test choose_action and args

my $my_req_info = Kynetx::Test::gen_req_info($rid);

my $rule_name = 'foo';

my $rule_env = Kynetx::Test::gen_rule_env();

my $session = Kynetx::Test::gen_session($r, $rid);

my $test_count = 0;
my ($source,$result,$args,$function,$description);


# check that predicates at least run without error
my @dummy_arg = (0);
foreach my $pn (@pnames) {
    ok(&{$preds->{$pn}}($my_req_info, $rule_env,\@dummy_arg) ? 1 : 1, "$pn runs");
    $test_count++;
}


# XML conversion
my $XML = <<_XML_;
<sample_dataset>
        <seed name="Strawberries" type="fruit">
                <harvest_time>4 Hours</harvest_time>
                <cost type="coins">10</cost>
                <xp>1</xp>
                
        </seed>
        <seed name="Pink Roses" type="flower">
                <harvest_time>2 Days</harvest_time>
                <cost type="coins">120</cost>
                <xp>2</xp>
        </seed>
        <seed name="Tomatoes" type="fruit">
                <harvest_time>8 Hours</harvest_time>
                <cost type="coins">100</cost>
                <xp>1</xp>
        </seed>
        <seed name="Soybeans" type="vegetable">
                <harvest_time>1 Days</harvest_time>
                <cost type="coins">15</cost>
                <xp>2</xp>
        </seed>
        <tree name="Lemon Tree">
           <harvest_time>3 Days</harvest_time>
           <cost type="coins">475</cost>
        </tree>
    <tree name="Acai Tree">
       <harvest_time>2 Days</harvest_time>
       <cost type="dollars">27</cost>
    </tree>
</sample_dataset>
_XML_

my $JSON ='{"@encoding":"UTF-8","@version":"1.0","sample_dataset":{"tree":[{"cost":{"$t":"475","@type":"coins"},"@name":"Lemon Tree","harvest_time":{"$t":"3 Days"}},{"cost":{"$t":"27","@type":"dollars"},"@name":"Acai Tree","harvest_time":{"$t":"2 Days"}}],"seed":[{"cost":{"$t":"10","@type":"coins"},"xp":{"$t":"1"},"@name":"Strawberries","harvest_time":{"$t":"4 Hours"},"@type":"fruit"},{"cost":{"$t":"120","@type":"coins"},"xp":{"$t":"2"},"@name":"Pink Roses","harvest_time":{"$t":"2 Days"},"@type":"flower"},{"cost":{"$t":"100","@type":"coins"},"xp":{"$t":"1"},"@name":"Tomatoes","harvest_time":{"$t":"8 Hours"},"@type":"fruit"},{"cost":{"$t":"15","@type":"coins"},"xp":{"$t":"2"},"@name":"Soybeans","harvest_time":{"$t":"1 Days"},"@type":"vegetable"}]}}';


$description = "Convert xml string to json";
$source = 'this2that';
$function = 'xml2json';
$args = [$XML];

$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
is($result,$JSON,$description);
$test_count++;

# attr prefix
my $prefix = '_:_';
$description = "Change attr prefix";
$args = [$XML,{'attribute_prefix' => $prefix}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,re(qr/$prefix/), $description);

# content key
$prefix = '_t_';
$description = "Change content key";
$args = [$XML,{'content_key' => $prefix}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,re(qr/$prefix/), $description);

# private elements
my @pe = ['harvest_time','xp'];
my $ajson = '{"@encoding":"UTF-8","@version":"1.0","sample_dataset":{"tree":[{"cost":{"$t":"475","@type":"coins"},"@name":"Lemon Tree"},{"cost":{"$t":"27","@type":"dollars"},"@name":"Acai Tree"}],"seed":[{"cost":{"$t":"10","@type":"coins"},"@name":"Strawberries","@type":"fruit"},{"cost":{"$t":"120","@type":"coins"},"@name":"Pink Roses","@type":"flower"},{"cost":{"$t":"100","@type":"coins"},"@name":"Tomatoes","@type":"fruit"},{"cost":{"$t":"15","@type":"coins"},"@name":"Soybeans","@type":"vegetable"}]}}';
$description = "delete private elements";
$args = [$XML,{'private_elements' => @pe}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$ajson, $description);

# empty elements
my @ee = ['cost'];
$ajson = '{"@encoding":"UTF-8","@version":"1.0","sample_dataset":{"tree":[{"cost":{},"@name":"Lemon Tree","harvest_time":{"$t":"3 Days"}},{"cost":{},"@name":"Acai Tree","harvest_time":{"$t":"2 Days"}}],"seed":[{"cost":{},"xp":{"$t":"1"},"@name":"Strawberries","harvest_time":{"$t":"4 Hours"},"@type":"fruit"},{"cost":{},"xp":{"$t":"2"},"@name":"Pink Roses","harvest_time":{"$t":"2 Days"},"@type":"flower"},{"cost":{},"xp":{"$t":"1"},"@name":"Tomatoes","harvest_time":{"$t":"8 Hours"},"@type":"fruit"},{"cost":{},"xp":{"$t":"2"},"@name":"Soybeans","harvest_time":{"$t":"1 Days"},"@type":"vegetable"}]}}';
$description = "Remove attributes and text of elements";
$args = [$XML,{'empty_elements' => @ee}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$ajson, $description);

# Private attrs
my @pa = ['name','encoding','version'];
$ajson = '{"sample_dataset":{"tree":[{"cost":{"$t":"475","@type":"coins"},"harvest_time":{"$t":"3 Days"}},{"cost":{"$t":"27","@type":"dollars"},"harvest_time":{"$t":"2 Days"}}],"seed":[{"cost":{"$t":"10","@type":"coins"},"xp":{"$t":"1"},"harvest_time":{"$t":"4 Hours"},"@type":"fruit"},{"cost":{"$t":"120","@type":"coins"},"xp":{"$t":"2"},"harvest_time":{"$t":"2 Days"},"@type":"flower"},{"cost":{"$t":"100","@type":"coins"},"xp":{"$t":"1"},"harvest_time":{"$t":"8 Hours"},"@type":"fruit"},{"cost":{"$t":"15","@type":"coins"},"xp":{"$t":"2"},"harvest_time":{"$t":"1 Days"},"@type":"vegetable"}]}}';
$description = "Remove attributes";
$args = [$XML,{'private_attributes' => @pa}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$ajson, $description);

# Force array
$ajson = '{"@encoding":"UTF-8","@version":"1.0","sample_dataset":{"tree":[{"cost":[{"$t":"475","@type":"coins"}],"@name":"Lemon Tree","harvest_time":[{"$t":"3 Days"}]},{"cost":[{"$t":"27","@type":"dollars"}],"@name":"Acai Tree","harvest_time":[{"$t":"2 Days"}]}],"seed":[{"cost":[{"$t":"10","@type":"coins"}],"xp":[{"$t":"1"}],"@name":"Strawberries","harvest_time":[{"$t":"4 Hours"}],"@type":"fruit"},{"cost":[{"$t":"120","@type":"coins"}],"xp":[{"$t":"2"}],"@name":"Pink Roses","harvest_time":[{"$t":"2 Days"}],"@type":"flower"},{"cost":[{"$t":"100","@type":"coins"}],"xp":[{"$t":"1"}],"@name":"Tomatoes","harvest_time":[{"$t":"8 Hours"}],"@type":"fruit"},{"cost":[{"$t":"15","@type":"coins"}],"xp":[{"$t":"2"}],"@name":"Soybeans","harvest_time":[{"$t":"1 Days"}],"@type":"vegetable"}]}}';
$description = "Force array";
$args = [$XML,{'force_array' => 1}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$ajson, $description);

# Decode json
my $dJSON = Kynetx::Json::jsonToAst_w($JSON);
$description = "Decode JSON";
$args = [$XML,{'decode' => 1}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$dJSON, $description);

# Put it all together now
$dJSON = '{"sample_dataset":{"tree":[{"cost":{},"@name":"Lemon Tree","harvest_time":{"#PCDATA":"3 Days"}},{"cost":{},"@name":"Acai Tree","harvest_time":{"#PCDATA":"2 Days"}}]}}';
$description = "Multiple options";
$args = [$XML,{
	'private_attributes' => ['encoding','version'],
	'private_elements' => ['seed'],
	'empty_elements' => ['cost'],
	'content_key' => "#PCDATA",
	
}];
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$dJSON, $description);


# base64 methods
$description = "Encode to base64";
$function = "string2base64";
my $plaintext = "SuperDuper: ascii";
my $expected = 'U3VwZXJEdXBlcjogYXNjaWk=';
$args = [$plaintext];

$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$expected, $description);

$description = "Decode from base64";
$function = "base642string";
my $base64 = 'U3VwZXJEdXBlcjogYXNjaWk=';
$expected = "SuperDuper: ascii";
$args = [$base64];
 
$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$expected, $description);

$description = "URL safe encode to base64";
$function = "url2base64";
$plaintext = "3+4/7 = 1";
$expected = 'Mys0LzcgPSAx';
$args = [$plaintext];

$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$expected, $description);

$description = "URL safe decode from base64";
$function = "base642url";
$base64 = 'Mys0LzcgPSAx';
$expected = '3+4/7 = 1';
$args = [$base64];

$result = Kynetx::Expressions::den_to_exp(
            Kynetx::Modules::eval_module($my_req_info,
                       $rule_env,
                       $session,
                       $rule_name,
                       $source,
                       $function,
                       $args
                      ));
$test_count++;
cmp_deeply($result,$expected, $description);


done_testing($test_count);
1;


