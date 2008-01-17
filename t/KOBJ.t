#!/usr/bin/perl -w 

use lib qw(/web/lib/perl);
use strict;

use Test::More;
plan tests => 1;
use Test::LongString;

use Apache2::Const;

use Kynetx::Test qw/:all/;
use Kynetx::Parser qw/:all/;
use Kynetx::KOBJ qw/:all/;

use Log::Log4perl qw(get_logger :levels);
Log::Log4perl->easy_init($INFO);

ok(1,"dummy test");

1;


