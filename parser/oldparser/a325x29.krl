{"global":[{"emit":"function remindMeSelector(obj) {\n        alert(obj.domain);\n        if(obj.domain === \"sears.com\") {\n          return \"<H2>This is a test</H2>\";\n        }\n      }\n    "}],"global_start_line":15,"dispatch":[{"domain":"www.google.com","ruleset_id":null}],"dispatch_start_col":3,"meta_start_line":2,"rules":[{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"remindMeSelector","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":null,"name":"first_rule","start_col":3,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"^http://search.yahoo.com","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":26}],"meta_start_col":3,"meta":{"logging":"off","name":"AnnotationTest","meta_start_line":2,"author":"","description":"To test the annotation problem.\n    ","meta_start_col":3},"dispatch_start_line":11,"global_start_col":3,"ruleset_name":"a325x29"}
