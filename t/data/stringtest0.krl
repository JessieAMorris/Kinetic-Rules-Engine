// String similarity
ruleset 10 {
    rule test0 is active {
        select using "/test/" setting()
        pre {
	}     

	if page:var("zip") like "83*" then
	   alert("You're coming from Idaho!");

    }
}