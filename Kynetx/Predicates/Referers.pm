package Kynetx::Predicates::Referers;
# file: Kynetx/Predicates/Referers.pm

use strict;
use warnings;

use Log::Log4perl qw(get_logger :levels);


use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

our $VERSION     = 1.00;
our @ISA         = qw(Exporter);

# put exported names inside the "qw"
our %EXPORT_TAGS = (all => [ 
qw(
get_referer
) ]);
our @EXPORT_OK   =(@{ $EXPORT_TAGS{'all'} }) ;

# before you ask, no the name of the module isn't misspelled.
#  See http://en.wikipedia.org/wiki/HTTP_referer


my %search_engines = (
    'alexa.com' => 1,
    'alltheweb.com' => 1,
    'altavista.com' => 1,
    'aolsearch.aol.co.uk' => 1,
    'aolsearch.aol.com' => 1,
    'au.search.yahoo.com' => 1,
    'ca.search.yahoo.com' => 1,
    'de.search.yahoo.com' => 1,
    'dogpile.com' => 1,
    'excite.co.jp' => 1,
    'fr.search.yahoo.com' => 1,
    'google.ae' => 1,
    'google.at' => 1,
    'google.be' => 1,
    'google.ca' => 1,
    'google.ch' => 1,
    'google.cl' => 1,
    'google.co.cr' => 1,
    'google.co.il' => 1,
    'google.co.in' => 1,
    'google.co.jp' => 1,
    'google.co.kr' => 1,
    'google.co.nz' => 1,
    'google.co.th' => 1,
    'google.co.uk' => 1,
    'google.co.ve' => 1,
    'google.com' => 1,
    'google.com.ar' => 1,
    'google.com.au' => 1,
    'google.com.br' => 1,
    'google.com.co' => 1,
    'google.com.do' => 1,
    'google.com.hk' => 1,
    'google.com.mt' => 1,
    'google.com.mx' => 1,
    'google.com.my' => 1,
    'google.com.pa' => 1,
    'google.com.pe' => 1,
    'google.com.ph' => 1,
    'google.com.pk' => 1,
    'google.com.sa' => 1,
    'google.com.sg' => 1,
    'google.com.tr' => 1,
    'google.com.tw' => 1,
    'google.com.uy' => 1,
    'google.com.vn' => 1,
    'google.de' => 1,
    'google.dk' => 1,
    'google.es' => 1,
    'google.fi' => 1,
    'google.fr' => 1,
    'google.ie' => 1,
    'google.it' => 1,
    'google.lt' => 1,
    'google.lu' => 1,
    'google.lv' => 1,
    'google.mu' => 1,
    'google.nl' => 1,
    'google.no' => 1,
    'google.pl' => 1,
    'google.pt' => 1,
    'google.ro' => 1,
    'google.ru' => 1,
    'google.se' => 1,
    'google.sk' => 1,
    'hotbot.com' => 1,
    'infoseek.co.jp' => 1,
    'mamma.com' => 1,
    'ms101.mysearch.com' => 1,
    'search.aol.com' => 1,
    'search.com' => 1,
    'search.earthlink.net' => 1,
    'search.icq.com' => 1,
    'search.msn.co.uk' => 1,
    'search.msn.com' => 1,
    'search.msn.de' => 1,
    'search.msn.dk' => 1,
    'search.msn.fr' => 1,
    'search.naver.com' => 1,
    'search.netscape.com' => 1,
    'search.ninemsn.com.au' => 1,
    'search.yahoo.com' => 1,
    'tw.search.yahoo.com' => 1,
    'uk.search.yahoo.com' => 1,
    );



my %predicates = (

    # referer predicates
    'search_engine_referer' => sub {
	my ($req_info, $rule_env, $args) = @_;

	my $domain = get_referer_data($req_info,'domain');
	$domain =~ s#^www\.(.*)$#$1# if($domain =~ m#^www\.#);

	return $search_engines{$domain};
    },

    'referer_domain' => sub {
	my ($req_info, $rule_env, $args) = @_;


	my $domain = get_referer_data($req_info,'domain');

	my $logger = get_logger();
	$logger->debug("[predicate] referer_domin: looking for ",
		       $args->[0], " got ", $domain);

	return $domain eq $args->[0];
    },

    'remote_referer' => sub {
	my ($req_info, $rule_env, $args) = @_;

	my $domain = get_referer_data($req_info,'domain');
	return defined($domain);
    },

    );


# need predicates already defined for this
$predicates{'local_referer'} = sub {
    return ! $predicates{'remote_referer'}(@_)

};



sub get_predicates {
    return \%predicates;
}





# condition subfunctions
# first argument is a record of data about the request

sub get_referer_data {

    my ($req_info,  $field) = @_;


    my @field_names = qw(
         protocol
         domain
         port
         path
         );
    
    if(not defined $req_info->{'referer_data'}->{$field}) {

	my $url = $req_info->{'referer'};
	if(! defined ($url)) {
	    # if referer isn't set, then this is a local referer
	    $req_info->{'referer_data'}->{'local_referer'} = 1;
	    return undef;
	}

	my $parsed_url = APR::URI->parse($req_info->{'pool'}, $url);

#	$url =~ m|(\w+)://([^/:]+)(:\d+)?/([^?]*)(\?.*)?|; 
	$req_info->{'referer_data'}->{'protocol'} = $parsed_url->scheme;
	$req_info->{'referer_data'}->{'domain'} = $parsed_url->hostname;
	$req_info->{'referer_data'}->{'path'} = $parsed_url->path;

	if ($parsed_url->port) { 
	    $req_info->{'referer_data'}->{'port'} = $parsed_url->port;
	} else { 
	    $req_info->{'referer_data'}->{'port'} = 80;
	}

	$req_info->{'referer_data'}->{'query'} = $parsed_url->query;

	my $logger = get_logger();

	if($logger->is_debug()) {
	    foreach my $k (keys %{ $req_info->{'referer_data'} }) {
	    $logger->debug("Referer piece ($k): " . 
			   $req_info->{'referer_data'}->{$k}, "\n"
		) if $req_info->{'referer_data'}->{$k};
	    }
	}
	

    }

    return $req_info->{'referer_data'}->{$field};

}



sub get_referer {

    my ($req_info,  $function) = @_;

    case: for ($function) {
	/search_terms/ && do {
	    my $query = get_referer_data($req_info,'query');

	    my %p;
	    foreach my $arg (split('&', $query)) {
		my ($k,$v) = split('=',$arg,2);
		$p{$k} = $v;
		$p{$k} =~ s/\%([A-Fa-f0-9]{2})/pack('C', hex($1))/seg;
	    }

	    return $p{'q'} || $p{'p'} || $p{'query'} || "";
	    
	};
	
    } 


   



}

1;
