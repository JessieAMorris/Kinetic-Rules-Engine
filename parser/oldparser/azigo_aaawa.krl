{"global":[{"source":"http://service.azigo.com/updates/kynetx/datasets/aaaw.json","name":"aaawa","type":"dataset","datatype":"JSON","cachable":1}],"global_start_line":12,"dispatch":[],"dispatch_start_col":null,"meta_start_line":5,"rules":[{"cond":{"args":[{"source":"page","predicate":"env","args":[{"val":"datasets","type":"str"}],"type":"qualified"},{"val":"aaawa","type":"str"}],"type":"ineq","op":"like"},"blocktype":"every","actions":[{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"aaawa_selector","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":[],"name":"aaawa","start_col":2,"emit":"function aaawa_selector(obj){\n  function mk_anchor (o, key) {\n    var url_prefix = \"http://frag.kobj.net/clients/1024/images/\";\n    var link_text = {\n      \"aaawa_text\": \"<div style='padding-top: 13px'>AAA</div>\",\n      \"aaawa\": \"<img style='padding-top: 5px' src='\" + url_prefix + \"aaa_logo_34.png' border='0'>\"\n\n    };\n    return $K('<a href=' + o.link + '/>').attr(\n      {\"class\": 'KOBJ_'+key,\n       \"title\": o.text || \"Click here for discounts!\"\n      }).html(link_text[key]);\n  }\n\n  var host = KOBJ.get_host($K(obj).find(\"span.url, cite\").text());\n  var o = KOBJ.pick(aaawa[host]);\n  if(o) {\n     return mk_anchor(o,'aaawa');\n  } else {\n    false;\n  }\n}\n\nvar url_prefix = \"http://frag.kobj.net/clients/1024/images/\";\nKOBJ.search_annotation.defaults.head_background_image = url_prefix + \"remindme_bar40_l.png\";\nKOBJ.search_annotation.defaults.tail_background_image = url_prefix + \"remindme_bar40_r.png\";\nKOBJ.search_annotation.defaults.name = \"remindme\";\nKOBJ.search_annotation.defaults.height = \"40px\";\nKOBJ.search_annotation.defaults.left_margin = \"46px\";\n","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"www.google.com|search.yahoo.com","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":16}],"meta_start_col":3,"meta":{"logging":"on","meta_start_line":5,"description":"Staging ruleset for Azigo deal with AAA WA\n","meta_start_col":3},"dispatch_start_line":null,"global_start_col":3,"ruleset_name":"azigo_aaawa"}
