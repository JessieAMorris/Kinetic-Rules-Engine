{"global":[],"global_start_line":null,"dispatch":[{"domain":"smccvb.com","ruleset_id":null},{"domain":"lurerestaurant.com","ruleset_id":null}],"dispatch_start_col":5,"meta_start_line":2,"rules":[{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Lure","type":"str"},{"val":"msg","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":[{"rhs":"<div id=\"note_2\">           <p class=\"note\">        California seafood bistro located in the heart of downtown San Mateo. Enjoy fresh seafood and seasonal market produce in dishes that respect and challenge traditional preparations from the world's great coastal cuisines.</p>           <a class=\"tour\" href=\"http://www.mezzalunabythesea.com/\">Continue the Tour</a>        </div>       \n ","lhs":"msg","type":"here_doc"}],"name":"lurerestaurant","start_col":5,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"http://lurerestaurant.com/","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":10},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Welcome to the San Mateo County Convention and Visitors Bureau!","type":"str"},{"val":"msg","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":[{"rhs":"<div id=\"note_1\">               <p class=\"note\">               What are you looking for? Please select an option below and hang on while we take you on a tour of some of the best places in the county for that category.</p>               <a class=\"tour\" href=\"http://www.lurerestaurant.com/\">Dining</a>           </div>        \n ","lhs":"msg","type":"here_doc"}],"name":"smccvb","start_col":5,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"http://smccvb.com/","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":22}],"meta_start_col":5,"meta":{"logging":"on","name":"devex question trash","meta_start_line":2,"meta_start_col":5},"dispatch_start_line":6,"global_start_col":null,"ruleset_name":"a60x25"}
