// composite events
ruleset 10 {
    rule test0 is active {
	select when 
		pageview url #/archives/(\d+)/foo.html# setting (year)
		after pageview url #mid.html#
        	between(pageview url #(\d+).html# setting(b),
                	pageview url #(\d+).html# setting(c))   		
	{
		noop();
	}
    }
}
