{"global":[],"global_start_line":null,"dispatch":[{"domain":"google.com","ruleset_id":null},{"domain":"yahoo.com","ruleset_id":null},{"domain":"bing.com","ruleset_id":null},{"domain":"kynetximpactspring2010.eventbrite.com","ruleset_id":null}],"dispatch_start_col":5,"meta_start_line":2,"rules":[{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"my_select","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":null,"name":"search_annotate","start_col":5,"emit":"function my_select(obj) {      var ftext = $K(obj).text();      if (ftext.match(/kynetx.com/)) {        return \"<img class='devexrocks' src='http://kynetx.michaelgrace.org/kynetx_app/devex.png' />\";      } else {        false;      }    }          ","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":".","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":16},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"<h1>Congratulations!</h1>","type":"str"},{"val":"<h3>Thanks for being a fan of Kynetx!</h3><p>Your discount code for $51 off has been entered. You may continue your order.</p>","type":"str"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":null,"name":"spring_impact_discount_autofill","start_col":5,"emit":"if($K(\"input[name='cost_8837003']\").val() == \"150.00\") {      $K(\"#discountDiv input[type='text']\").val(\"Earlybirdspring2010\");      applyDiscount('None');    }          ","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"http://kynetximpactspring2010.eventbrite.com/","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":23}],"meta_start_col":5,"meta":{"logging":"on","name":"Kynetx Fan","meta_start_line":2,"author":"MikeGrace","description":"Keeping you updated and connected to Kynetx with news alerts, games, contests, and more.      Currently annotates search results for questions asked on our developers exchange site.     \n","meta_start_col":5},"dispatch_start_line":10,"global_start_col":null,"ruleset_name":"a60x44"}
