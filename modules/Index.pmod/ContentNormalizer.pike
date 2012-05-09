object logger = Tools.Logging.get_logger("fulltext.normalizer");
mapping converters=([]);
multiset allowed_types=(<>);
multiset denied_types=(<>);
object parser, stripper;

mapping limits = (["cpu": 30]);

void start(mixed config)
{
  setup_converters(config);
  setup_type_permits(config);
  set_limits(config);
}

void set_limits(mixed config)
{
  if(config["limits"])
  {
    mixed m = config["limits"];
    if(m->maxcpu)
    {
      logger->info("setting maximum converter cpu time to %d seconds.", (int)m->maxcpu);
      limits->cpu = (int)m->maxcpu;
    }
  }
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
//  logger->debug("prepare_content(%O, %O)", data, type);
   if(converters[type])
  {
    logger->info("performing conversion for data of type " + type);
    data=converters[type]->convert(data);

    if(!data || !strlen(data))
    {
      logger->info("  ...converter returned no data");
    }
  }


   // clear the parsers
    parser=parser->clone();
    stripper=stripper->clone();

     parser->feed(data);
    data=parser->read();

    stripper->feed(data);
    data=stripper->read();

  logger->debug("prepare_content(%O, %O): finished", data, type);

  return data;
}

int allowed_type(string type)
{
   logger->debug(sprintf("allowed: %O, denied: %O\n", allowed_types, denied_types)-"\n");

   foreach(indices(denied_types), string t)
   {
     if(glob(t, type||"unknown/unknown")) return 0;
   }
   foreach(indices(allowed_types), string t)
   {
     if(glob(t, type||"unknown/unknown")) return 1;
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
   //werror("continuing on " + t + "\n");
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
  foreach(glob("transform_*", config->get_sections()); int x; string t)
  {
    mapping c = config[t];
    array mt;
    if(arrayp(c->mimetype))
      mt = c->mimetype;
    else if(stringp(c->mimetype))
      mt = ({ c->mimetype });
    else
      mt = ({});

    foreach(mt;; string mimetype)
    {
      werror("Configuring converter for " + mimetype + "\n");
      if(c->type=="filter")
        converters[mimetype]=FTSupport.Conversion.Filter(c->command, limits);
      else if(c->type=="converter")
        converters[mimetype]=FTSupport.Conversion.Converter(c->command, config["indexer"]->temp, limits);
      else werror("unknown converter type %O for mime type %O\n", c->type, mimetype);
    }
  }

  werror("Configuring internal converter for text/plain\n");
  converters["text/plain"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

  werror("Configuring internal converter for text/html\n");
  converters["text/html"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

}
