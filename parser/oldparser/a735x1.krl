{"global":[{"source":"http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20html%20where%20url%3D%22http%3A%2F%2Fwww.kamakazzi.info%2Fusaa%2Fdiscounts.html%22%20and%20xpath%3D%22%2F%2Fa%22%20%0A&format=json","name":"webdata","type":"dataset","datatype":"JSON","cachable":0},{"source":"http://query.yahooapis.com/v1/public/yql?q=select%20*%20from%20html%20where%20url%3D%22http%3A%2F%2Fkamakazzi.info%2Fusaa%2Fdiscounts.html%22%20and%20xpath%3D'%2F%2Fdiv%5B%40class%3D%22products%22%5D'&format=json","name":"products","type":"dataset","datatype":"JSON","cachable":0},{"emit":"$K(\"head\").append(\"<style type='text/css'> a img {border: none;} div.noticebox {background-color:#D9E3FC; border:double; border-color:blue;\tposition:absolute;\theight:85px;\twidth:160px;\tmargin-left:3px;\tmargin-top:-130px;\tpadding-left: 2px;\tdisplay:none;\tz-index:101;\ttext-align:left;}\tp\t{margin: 0;\tpadding: 0;} .usaaDiv a {white-space: normal;}\tdiv.usaaDiv:hover\t.noticebox{display:block;}\t</style>\"); "}],"global_start_line":20,"dispatch":[{"domain":"google.com","ruleset_id":null},{"domain":"yahoo.com","ruleset_id":null},{"domain":"bing.com","ruleset_id":null},{"domain":"homedepot.com","ruleset_id":null},{"domain":"barnesandnoble.com","ruleset_id":null},{"domain":"oldnavy.com","ruleset_id":null},{"domain":"apple.com","ruleset_id":null},{"domain":"newegg.com","ruleset_id":null}],"dispatch_start_col":5,"meta_start_line":2,"rules":[{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"my_select","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":null,"name":"annotesearch","start_col":5,"emit":"$K(\"head\").append(\" <script type='text/JavaScript'>\")\n\n\tfunction rollon()\n\t{\n\t    if(window.event && navigator.appName == 'Microsoft Internet Explorer')\n\t    {\n\t        var usaaDiv = window.event.srcElement.parentNode.parentNode;\n\t        for (var i = 0; i < usaaDiv.childNodes.length; i++)\n\t        {\n\t            if (usaaDiv.childNodes[i].className == 'noticebox')\n\t            {\n\t                var noticebox = usaaDiv.childNodes[i];\n\t                break;\n\t            }\n\t        }\n\t        noticebox.style.display = 'block';\n\t        noticebox.style.marginLeft = '-50px';\n\t    }\n\t}\n\tfunction rolloff()\n\t{\n\t    if(window.event && navigator.appName == 'Microsoft Internet Explorer')\n\t    {\n\t        var usaaDiv = window.event.fromElement.parentNode.parentNode;\n\t        if (usaaDiv.className == 'usaaDiv')\n\t        {\n\t            if (!(usaaDiv.contains(window.event.toElement)))\n\t            {\n\t                for (var i = 0;i < usaaDiv.childNodes.length; i++)\n\t                {\n\t                    if (usaaDiv.childNodes[i].className == 'noticebox')\n\t                    {\n\t                        var noticebox = usaaDiv.childNodes[i];\n\t                        break;\n\t                    }\n\t                }\n\t                noticebox.style.display = 'none';\n\t            }\n\t        }\n\t    }\n\t}\n\tfunction hideNotice()\n\t{\n\t    if (window.event && navigator.appName == 'Microsoft Internet Explorer')\n\t    {\n\t        var noticebox = window.event.fromElement;\n\t        if (noticebox.className != 'noticebox')\n\t        {\n\t            return;\n\t        }\n\t        if (!(noticebox.contains(window.event.toElement)))\n\t        {\n\t            noticebox.style.display = 'none';\n\t        }\n\t    }\n\t}\n\t</script>\");\n\t\n\tfunction my_select(obj)    \n\t{\n\t     var ftext = $K(obj).text();\n\t     var htext = $K(obj).html();\n\t     var domain = x.match(/\\.[^\\.]+\\.\\w+/);\n\t     if (ftext.match(domain))\n\t     {\n\t      return \"<div class='usaaDiv' > <p><img class='usaaimg' src='http://superiorcollisionrepair.com/wp/wp-content/uploads/2009/09/usaa_logo.png' height='40' width='110' onMouseOver='rollon()' onMouseOut='rolloff()' /></p> <div class='noticebox' onMouseOut='hideNotice()'><a href= 'http://www.usaa.com/membershop'> Save money at \" + domain[0].replace(\".\", \"\") + \" with USAA</a></div> </div>\";\n\t            \n\t     }\n\t     else\n\t     {\n\t        false;\n\t     }\n\t} ","state":"inactive","callbacks":null,"pagetype":{"event_expr":{"pattern":".*","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[{"expr":{"obj":{"val":"webdata","type":"var"},"args":[{"val":"$.query.results.a..href","type":"str"}],"name":"pick","type":"operator"},"var":["x"]}]},"start_line":28},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"my_select","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":[{"rhs":{"obj":{"val":"webdata","type":"var"},"args":[{"val":"$.query.results.a..href","type":"str"}],"name":"pick","type":"operator"},"lhs":"vendorDomains","type":"expr"}],"name":"js_tooltip","start_col":5,"emit":"$K(\"head\").append(\"<style type='text/css'> a img\t{border: none;}\tdiv.noticebox{background-color:#D9E3FC; border:double; border-color:blue; position:absolute; height:85px; width:160px; margin-left:3px; margin-top:-130px; padding-left: 2px; display:none; z-index:101; text-align:left;}\tp{margin: 0; padding: 0;} .usaaDiv a{white-space: normal;}\tdiv.usaaDiv:hover .noticebox{display:block;}\t</style>\");\n                $K(\"head\").append(\" <script type='text/javascript' src='http://code.jquery.com/jquery-1.4.1.min.js'></script> <script type='text/javascript' src='http://www.kamakazzi.info/scripts/tipTip.js'> </script> <link href='http://www.kamakazzi.info/scripts/tipTip.css' type='text/css' rel='stylesheet' media='screen'/> <script type='text/javascript'> $(document).ready( function()\t{$('.usaaimg').tipTip({delay:'80'})}); </script> \");\n\n    function my_select(obj)\n        {\n            var ftext = $K(obj).text();\n            var domain;\n            for (var i = 0; i < vendorDomains.length; i++)\n            {\n                domain = vendorDomains[i].match(/\\.[^\\.]+\\.\\w+/);\n                if (ftext.match(domain))\n                {\n                    return \"<a href='http://www.usaa.com/membershop'><img class='usaaimg' src='http://prototypefactory.net/membershop/usaaMemberShop.png' height='40' width='110' title='Save up to 20% at \" + domain[0].replace(\".\", \"\") + \" with USAA member shop.' /></a>\";\n                }\n            }\n        } ","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"http://www.google.com|http://www.yahoo.com|http://www.bing.com","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":105},{"cond":{"args":[{"args":[{"args":[{"val":"vendor","type":"var"},{"val":"google","type":"str"}],"type":"ineq","op":"eq"},{"args":[{"val":"vendor","type":"var"},{"val":"yahoo","type":"str"}],"type":"ineq","op":"eq"},{"args":[{"val":"vendor","type":"var"},{"val":"bing","type":"str"}],"type":"ineq","op":"eq"}],"type":"pred","op":"||"}],"type":"pred","op":"negation"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"USAA MemberShop","type":"str"},{"args":[{"val":"Did you know you could save up to 20% at ","type":"str"},{"args":[{"val":"vendor","type":"var"},{"val":".com with USAA member shop? <a href='http://www.usaa.com/membershop' >Click here to start.</a>","type":"str"}],"type":"prim","op":"+"}],"type":"prim","op":"+"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":null,"name":"vendor_domain_notify","start_col":5,"emit":"$K(\"head\").append(\" <style type='text/css'> .kGrowl a { color:white; } .kGrowl a:visited { color:white; } </style>\"); ","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"www.(\\w*).com","legacy":1,"type":"prim_event","vars":["vendor"],"op":"pageview"},"foreach":[]},"start_line":130},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"USAA MemberShop","type":"str"},{"val":"<div id='usaaNotice'></div>","type":"str"}],"modifiers":[{"value":{"val":"false","type":"bool"},"name":"sticky"},{"value":{"val":5000,"type":"num"},"name":"life"}],"vars":null},"label":null},{"action":{"source":null,"name":"annotate_search_results","args":[{"val":"my_select","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":null,"pre":[{"rhs":{"obj":{"val":"products","type":"var"},"args":[{"val":"$.query.results.div","type":"str"}],"name":"pick","type":"operator"},"lhs":"vendorArray","type":"expr"},{"rhs":{"source":"page","predicate":"url","args":[{"val":"query","type":"str"}],"type":"qualified"},"lhs":"product_search","type":"expr"},{"rhs":{"val":"false","type":"bool"},"lhs":"hasNotified","type":"expr"}],"name":"product_notify_v2","start_col":5,"emit":"$K(\"head\").append(\"<script>window.onerror = function() { return true }\");\n        $K(\"head\").append(\"<style type='text/css'> .kGrowl { display:none; } .kGrowl a { color:white; } .kGrowl a:visited { color:white; } </style>\");\n\n        function my_select(obj)\n        {\n            if (!hasNotified)\n            {\n                var ftext = $K(obj).text();\n                for (var i = 0; i < vendorArray.length; i++)\n                {\n                    var vendor = vendorArray[i].id;\n                    var vendorProducts = vendorArray[i].p.split(\",\");\n                    for (var j = 0; j < vendorProducts.length; j++)\n                    {\n                        var product = vendorProducts[j].replace(/s?$/, \"\");\n                        product_search = product_search.replace(/s?$/, \"\");\n                        var regexAssociatedWords = new RegExp(\"buy|shop|save\", \"i\");\n                        if ((product.match(product_search) || product_search.match(product)) && ftext.match(regexAssociatedWords))\n                        {\n                            $K(\"#usaaNotice\").append(\"<p>Shopping for \" + vendorProducts[j] + \"s? You could save up to 20% at \" + vendor + \" with USAA member shop. <a href='http://www.usaa.com/membershop' >Click here to start.</a></p>\");\n                            document.getElementById('kGrowl').style.display = 'block';\n                            hasNotified = true;\n                            return false;\n                        }\n                    }\n                }\n                return false;\n            }\n        } ","state":"active","callbacks":null,"pagetype":{"event_expr":{"pattern":"http://www.google.com|http://www.yahoo.com|http://www.bing.com","legacy":1,"type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":137}],"meta_start_col":5,"meta":{"logging":"off","name":"USAA Membershop Assistant","meta_start_line":2,"author":"Jeffrey Kreth","description":"Aids members in identifying and buying from Membershop partnered vendors as they browse the internet ","meta_start_col":5},"dispatch_start_line":9,"global_start_col":5,"ruleset_name":"a735x1"}
