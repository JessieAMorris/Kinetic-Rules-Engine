{"global":[],"global_start_line":null,"dispatch":[{"domain":"search.yahoo.com","ruleset_id":null}],"dispatch_start_col":5,"meta_start_line":null,"rules":[{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"replace_html","args":[{"val":"#logo_web","type":"str"},{"val":"test","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":[{"rhs":"<center><img src=\"http://a.l.yimg.com/a/i/us/sch/gr3/iphone_logo_20080707.png\" alt=\"Yahoo! Search\" id=\"logo_web\"/><br/><p style=\"font-size: 0.8em;\">Free WiFi brought to you by:</p><a href=\"http://www.beansandbrews.com/\"><img src=\"http://img198.imageshack.us/img198/2485/75525359.jpg\" alt=\"Beans and Brew Free WiFi\" style=\"border: 0pt none ;\"/></a></center></div> \n ","lhs":"test","type":"here_doc"}],"name":"iphone_free_wifi","start_col":5,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"search.yahoo.com/i","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":5},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"replace_html","args":[{"val":"#ft","type":"str"},{"val":"test","type":"var"}],"modifiers":null,"vars":null},"label":null},{"action":{"source":null,"name":"notify","args":[{"val":"Stay Later!","type":"str"},{"val":"Beans and Brew is now open until Midnight.","type":"str"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":[{"rhs":"<center><p style=\"font-size:.8em;\">Free WiFi brought to you by:</p><a href=\"http://www.beansandbrews.com/\"><img style=\"border:0;\" alt=\"Beans and Brew Free WiFi\" src=\"http://img198.imageshack.us/img198/2485/75525359.jpg\"/></a></center>      <div id=\"ft\">  <hr/>  <p class=\"copyright\">  <span>Â© 2009 Yahoo!</span>  <a href=\"http://privacy.yahoo.com/\">Privacy</a>  /  <a href=\"http://info.yahoo.com/legal/us/yahoo/utos/utos-173.html\">Legal</a>  -  <a href=\"http://search.yahoo.com/info/submit.html\">Submit Your Site</a>  </p>  </div> \n ","lhs":"test","type":"here_doc"}],"name":"yahoo_free_wifi","start_col":5,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"search.yahoo.com|www.search.yahoo.com","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":15}],"meta_start_col":null,"meta":{},"dispatch_start_line":2,"global_start_col":null,"ruleset_name":"a38x6"}
