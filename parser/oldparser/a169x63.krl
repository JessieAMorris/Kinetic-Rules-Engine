{"global":[{"source":"http://dev.freshbuzz.net/api/articleurl","name":"articleurl","type":"datasource","datatype":"JSON","cachable":{"period":"seconds","value":"1"}},{"source":"http://dev.freshbuzz.net/api/articlecontent","name":"articlecontent","type":"datasource","datatype":"JSON","cachable":{"period":"seconds","value":"1"}},{"content":"#a169x63-myvoice-container {  /* Cross domain reset to promote consistancy on multiple domains */\n        margin: 0;\n        padding: 0;\n        border: 0;\n        outline: 0;\n        font-size:24px;\n        font-size: 100%;\n        font-weight:normal;\n        vertical-align: baseline;\n        background: transparent;\n        color: #000;\n        font-family:arial,sans-serif;\n        direction: ltr;\n        line-height: 1;\n        letter-spacing: normal;\n        text-align: left;\n        text-decoration: none;\n        text-indent: 0;\n        text-shadow: none;\n        text-transform: none;\n        vertical-align: baseline;\n        white-space: normal;\n        word-spacing: normal;\n        font: normal normal normal medium/1 sans-serif ;\n        list-style: none;\n        clear: none;\n      }\n      .a169x63-myvoice-notification {  /* div wrapping content for entire app */\n        -moz-border-radius: 5px 5px 5px 5px;\n          background-color: #181818;\n                     color: #FFFFFF;\n               font-family: Helvetica,Arial,sans-serif;\n                 font-size: 11px;\n             margin-bottom: 5px;\n                margin-top: 5px;\n                min-height: 35px;\n                   opacity: 1;\n                   padding: 15px;\n                text-align: left;\n                     width: auto;\n                 min-width: 240px;\n                 max-width: 440px;\n      }\n      \n      .a169x63-myvoice-content {\n        background-color:#222222;\n        color:#FFFFFF;\n        font-size:12px;\n      }\n\n      .a169x63-myvoice-footer {\n        padding-top:5px;\n        padding-bottom:5px;\n      }\n\n      .a169x63-myvoice-footer-title {\n        float:left;\n      }\n\n      .a169x63-myvoice-footer-close-button {\n        float:right;\n        align=right;\n      }\n\n      div.a169x63-myvoice-footer-close-button a, a:link {\n        color:#006699;\n        font-weight: bold;\n        text-decoration:none;\n      }\n      \n      div.a169x63-myvoice-footer-close-button a:visited {\n        color:#ffffff;\n        font-weight: bold;\n        text-decoration:none;\n      }\n      div.a169x63-myvoice-footer-close-button a:hover {\n        color:#ffffff;\n        font-weight: bold;\n        text-decoration:none;\n      }\n      div.a169x63-myvoice-footer-close-button a:active {\n        color:#ffffff;\n        font-weight: bold;\n        text-decoration:none;\n      }\n      div.a169x63-myvoice-footer-close-button a:linked {\n        color:#ffffff;\n        font-weight: bold;\n        text-decoration:none;\n      }\n    ","type":"css"},{"rhs":"<div id=\"a169x63-myvoice-container\">\n    <div class=\"a169x63-myvoice-notification\">\n      <div class=\"a169x63-myvoice-content\">\n        <div  class=\"a169x63-myvoice-wrapper\">\n          FooCONTENTHEREFoo\n        </div>\n        <div class=\"a169x63-myvoice-footer\">\n          <div class=\"a169x63-myvoice-footer-title\">\n             A VoicePlant Production\n          </div>\n          <div class=\"a169x63-myvoice-footer-close-button\">\n            <a onclick=\"KOBJ.BlindUp('#a169x63-myvoice-container');false\">close window</a>\n          </div>\n        </div>\n      </div>\n    </div>\n  </div>\n    ","lhs":"MyVoiceContainer","type":"here_doc"}],"global_start_line":17,"dispatch":[{"domain":"dev.freshbuzz.net","ruleset_id":null},{"domain":"www.google.com","ruleset_id":null},{"domain":"www.whitehouse.gov","ruleset_id":null}],"dispatch_start_col":3,"meta_start_line":2,"rules":[{"cond":{"val":"targetURL","type":"var"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Debug: Redirecting","type":"str"},{"args":[{"val":"See you at ","type":"str"},{"val":"targetURL","type":"var"}],"type":"prim","op":"+"}],"modifiers":null,"vars":null},"label":null},{"action":{"source":null,"name":"redirect","args":[{"val":"targetURL","type":"var"}],"modifiers":[{"value":{"val":2,"type":"num"},"name":"delay"}],"vars":null},"label":null}],"post":{"alt":null,"type":"fired","cons":[{"test":null,"value":{"val":1,"type":"num"},"name":"voice_redirect","domain":"ent","from":{"val":1,"type":"num"},"action":"iterator","type":"persistent","op":"+="},{"test":null,"domain":"ent","name":"articleid","action":"mark","type":"persistent","with":{"val":"ArticleID","type":"var"}},{"test":null,"statement":"last","type":"control"}]},"pre":[{"rhs":{"source":"datasource","predicate":"articleurl","args":[{"args":[{"val":"/aid/","type":"str"},{"val":"ArticleID","type":"var"}],"type":"prim","op":"+"}],"type":"qualified"},"lhs":"MyResults","type":"expr"},{"rhs":{"obj":{"val":"MyResults","type":"var"},"args":[{"val":"$..messageUrl","type":"str"}],"name":"pick","type":"operator"},"lhs":"targetURL","type":"expr"}],"name":"voiceplant_redirection","start_col":3,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"domain":null,"pattern":"dev.freshbuzz.net/content/(\\d+)/(\\d+)","type":"prim_event","vars":["ChannelID","ArticleID"],"op":"pageview"},"foreach":[]},"start_line":137},{"cond":{"within":{"val":5,"type":"num"},"domain":"ent","expr":{"val":"true","type":"bool"},"ineq":"==","timeframe":"minutes","var":"voice_redirect","type":"persistent_ineq"},"blocktype":"every","actions":[{"action":{"source":null,"name":"float_html","args":[{"val":"absolute","type":"str"},{"val":"top:0px","type":"str"},{"val":"right:50px","type":"str"},{"val":"VoiceContent","type":"var"}],"modifiers":null,"vars":null},"label":null}],"post":{"alt":null,"type":"always","cons":[{"test":null,"domain":"ent","name":"voice_redirect","action":"clear","type":"persistent"},{"test":null,"domain":"ent","name":"articleid","action":"clear","type":"persistent"}]},"pre":[{"rhs":{"domain":"ent","name":"voice_redirect","type":"persistent"},"lhs":"RedirectCount","type":"expr"},{"rhs":{"domain":"ent","name":"articleid","type":"trail_history","offset":{"val":"0","type":"num"}},"lhs":"ArticleID","type":"expr"},{"rhs":{"source":"datasource","predicate":"articlecontent","args":[{"args":[{"val":"/aid/","type":"str"},{"val":"ArticleID","type":"var"}],"type":"prim","op":"+"}],"type":"qualified"},"lhs":"MyResults","type":"expr"},{"rhs":{"obj":{"val":"MyResults","type":"var"},"args":[{"val":"$..messageContent","type":"str"}],"name":"pick","type":"operator"},"lhs":"MyContent","type":"expr"},{"rhs":{"obj":{"val":"MyVoiceContainer","type":"var"},"args":[{"val":"/FooCONTENTHEREFoo/","type":"regexp"},{"val":"MyContent","type":"var"}],"name":"replace","type":"operator"},"lhs":"VoiceContent","type":"expr"}],"name":"voiceplant_content_display","start_col":3,"emit":null,"state":"active","callbacks":null,"pagetype":{"event_expr":{"domain":null,"pattern":".*","type":"prim_event","vars":[],"op":"pageview"},"foreach":[]},"start_line":156},{"cond":{"val":"targetURL","type":"var"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Hello World ...","type":"str"},{"val":"This is Voiceplant redirection!","type":"str"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null},{"action":{"source":null,"name":"notify","args":[{"val":"ArticleID","type":"str"},{"val":"ArticleID","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null},{"action":{"source":null,"name":"notify","args":[{"val":"Target URL","type":"str"},{"val":"targetURL","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":[{"rhs":{"source":"datasource","predicate":"articleurl","args":[{"args":[{"val":"/aid/","type":"str"},{"val":"ArticleID","type":"var"}],"type":"prim","op":"+"}],"type":"qualified"},"lhs":"MyResults","type":"expr"},{"rhs":{"obj":{"val":"MyResults","type":"var"},"args":[{"val":"$..messageUrl","type":"str"}],"name":"pick","type":"operator"},"lhs":"targetURL","type":"expr"}],"name":"voiceplant_redirection_test","start_col":3,"emit":null,"state":"inactive","callbacks":null,"pagetype":{"event_expr":{"domain":null,"pattern":"dev.freshbuzz.net/content/(\\d+)/(\\d+)","type":"prim_event","vars":["ChannelID","ArticleID"],"op":"pageview"},"foreach":[]},"start_line":182},{"cond":{"val":"true","type":"bool"},"blocktype":"every","actions":[{"action":{"source":null,"name":"notify","args":[{"val":"Hello World ...","type":"str"},{"val":"This is Voiceplant!","type":"str"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null},{"action":{"source":null,"name":"notify","args":[{"val":"ArticleID","type":"str"},{"val":"ArticleID","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null},{"action":{"source":null,"name":"notify","args":[{"val":"Article URL","type":"str"},{"val":"MyURL","type":"var"}],"modifiers":[{"value":{"val":"true","type":"bool"},"name":"sticky"}],"vars":null},"label":null}],"post":null,"pre":[{"rhs":{"source":"datasource","predicate":"articleurl","args":[{"args":[{"val":"/aid/","type":"str"},{"val":"ArticleID","type":"var"}],"type":"prim","op":"+"}],"type":"qualified"},"lhs":"MyResults","type":"expr"},{"rhs":{"obj":{"val":"MyResults","type":"var"},"args":[{"val":"$..messageUrl","type":"str"}],"name":"pick","type":"operator"},"lhs":"MyURL","type":"expr"}],"name":"just_a_test_rule","start_col":3,"emit":null,"state":"inactive","callbacks":null,"pagetype":{"event_expr":{"domain":null,"pattern":"dev.freshbuzz.net/content/(\\d+)/(\\d+)","type":"prim_event","vars":["ChannelID","ArticleID"],"op":"pageview"},"foreach":[]},"start_line":201}],"meta_start_col":3,"meta":{"logging":"on","name":"VoicePlant_Alpha","meta_start_line":2,"author":"Ed Orcutt http://edorcutt.org","description":"7bound project\n    ","meta_start_col":3},"dispatch_start_line":11,"global_start_col":3,"ruleset_name":"a169x63"}
