{"global":[],"global_start_line":null,"dispatch":[{"domain":"google.com","ruleset_id":null},{"domain":"bing.com","ruleset_id":null},{"domain":"yahoo.com","ruleset_id":null}],"dispatch_start_col":5,"meta_start_line":2,"rules":[{"cond":{"args":[{"val":"searchTerm","type":"var"},{"val":"","type":"str"}],"type":"ineq","op":"neq"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Search Data","type":"str"},{"val":"msg","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":[{"rhs":{"source":"page","predicate":"url","args":[{"val":"query","type":"str"}],"type":"qualified"},"lhs":"query","type":"expr"},{"rhs":"Query string: #{query}<br/>\n        Search term: #{searchTerm}\n      \n ","lhs":"msg","type":"here_doc"}],"name":"newrule","start_col":5,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"args":[{"domain":null,"pattern":"yahoo\\.com.*[?&]p=([^&]*)","type":"prim_event","vars":["searchTerm"],"op":"pageview"},{"args":[{"domain":null,"pattern":"google\\.com.*[?&]q=([^&]*)","type":"prim_event","vars":["searchTerm"],"op":"pageview"},{"domain":null,"pattern":"bing\\.com.*[?&]q=([^&]*)","type":"prim_event","vars":["searchTerm"],"op":"pageview"}],"type":"complex_event","op":"or"}],"type":"complex_event","op":"or"},"foreach":[]},"start_line":16}],"meta_start_col":5,"meta":{"logging":"off","name":"Genius","meta_start_line":2,"author":"Ranganath Satyan","description":"IDEO Genius Concept, demonstration of search annotation  \r\n\n","meta_start_col":5},"dispatch_start_line":11,"global_start_col":null,"ruleset_name":"a722x1"}
