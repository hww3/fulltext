mapping converters=([]);
multiset allowed_types=(<>);
multiset denied_types=(<>);
object parser, stripper;

void start(mixed config)
{
  setup_html_converter(config);
  setup_converters();
}

int allowed_type(string type)
{
   foreach(indices(denied_types), string t)
   {
     if(glob(t, type)) return 0;
   }
   foreach(indices(allowed_types), string t)
   {
     if(glob(t, type)) return 1;
   }
   return 0;
}

mixed strip_tag(Parser.HTML p, string t)
{
  return "";
}

mixed continue_tag(Parser.HTML p, mapping args, string t)
{
   werror("continuing on " + t + "\n");
  return 0;
}
    
void setup_html_converter(mixed config)
{
   parser=Parser.HTML();
   stripper=Parser.HTML();

   parser->case_insensitive_tag(1);
   stripper->case_insensitive_tag(1);
   parser->lazy_entity_end(1);
   parser->ignore_unknown(1);
   stripper->lazy_entity_end(1);

   parser->add_container("title", set_title);
//   parser->add_container("pre", continue_tag);
   parser->add_container("a", add_url);
   parser->add_container("script", strip_tag);
   parser->add_container("style", strip_tag);
   stripper->_set_tag_callback(strip_tag);
}

void setup_converters(mixed config)
{
  setup_html_converter();
  foreach(glob("transform_*", indices(config)); int t; string t)
  {
    mapping c = config[t];

    werror("Configuring converter for " + c->mimetype + "\n");
    if(c->type=="filter")
      converters[c->mimetype]=FTSupport.Filter(c->command);
    if(c->type=="converter")
      converters[c->mimetype]=FTSupport.Converter(c->command, config["indexer"]->temp);
    else werror("unknown converter type " + c->type +  " for mime type " + c->mimetype + "\n");
  }

  werror("Configuring internal converter for text/plain\n");
  converters["text/plain"]=FTSupport.PikeFilter(lambda(string d){ return d;});

  werror("Configuring internal converter for text/html\n");
  converters["text/html"]=FTSupport.PikeFilter(lambda(string d){ return d;});

}
