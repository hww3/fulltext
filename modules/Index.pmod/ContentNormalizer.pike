import Tools.Logging;

mapping converters=([]);
multiset allowed_types=(<>);
multiset denied_types=(<>);
object parser, stripper;

void start(mixed config)
{
  setup_converters(config);
  setup_type_permits(config);
}

void setup_type_permits(mixed config)
{
  mapping permits = config["permits"];  

  if(permits && sizeof(permits))
  {
    if(permits["allow"])
    {
      mixed r = permits["allow"];
      if(stringp(r))
        r = ({permits["allow"]});
      allowed_types = (multiset)r;
    }
    if(permits["deny"])
    {
      mixed r = permits["deny"];
      if(stringp(r))
        r = ({permits["deny"]});
      denied_types = (multiset)r;
    }
  }
}

string prepare_content(string data, string type)
{
   if(converters[type])
  {
    Log.info("performing conversion for data of type " + type);
    data=converters[type]->convert(data);
  }
  if(!data || !strlen(data))
  {
    Log.info("  ...converter returned no data");
  }


   // clear the parsers
    parser=parser->clone();
    stripper=stripper->clone();

     parser->feed(data);
    data=parser->read();

    stripper->feed(data);
    data=stripper->read();

  return data;
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

   // if we specify any allowed types, only permit those on the list.
   // otherwise, allow anything that's not denied.
   if(sizeof(allowed_types))
     return 0;
   else return 1;
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
//   parser->add_container("a", add_url);
   parser->add_container("script", strip_tag);
   parser->add_container("style", strip_tag);
   stripper->_set_tag_callback(strip_tag);
}

mixed set_title(Parser.HTML p, mapping args, string content)
{
  return "";
}

void setup_converters(mixed config)
{
  setup_html_converter(config);
  foreach(glob("transform_*", indices(config)); int x; string t)
  {
    mapping c = config[t];

    werror("Configuring converter for " + c->mimetype + "\n");
    if(c->type=="filter")
      converters[c->mimetype]=FTSupport.Conversion.Filter(c->command);
    if(c->type=="converter")
      converters[c->mimetype]=FTSupport.Conversion.Converter(c->command, config["indexer"]->temp);
    else werror("unknown converter type " + c->type +  " for mime type " + c->mimetype + "\n");
  }

  werror("Configuring internal converter for text/plain\n");
  converters["text/plain"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

  werror("Configuring internal converter for text/html\n");
  converters["text/html"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

}
