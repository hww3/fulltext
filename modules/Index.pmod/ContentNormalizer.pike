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

string prepare_content(Index.Document doc)
{
  string data = doc->content;
  string type = doc->mimetype;
//  logger->debug("prepare_content(%O, %O)", data, type);
   if(converters[type])
  {
    logger->info("performing conversion for data of type " + type);
    mixed e = catch(data=converters[type]->convert(data, doc));
    if(e)
    {
      logger->exception("Exception:", Error.mkerror(e));
    }
    if(!data || !strlen(data))
    {
      logger->info("  ...converter returned no data");
    }
  }
  // TODO we should complain if we can't get from the original type to a 
  //   reasonable text format (plain or html).

   object lparser, lstripper;
   // clear the parsers
    lparser=parser->clone();
    lstripper=stripper->clone();

    lparser->set_extra(doc);
     lparser->feed(data);
    data=lparser->read();

    lstripper->feed(data);
    data=lstripper->read();

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

mixed set_title(Parser.HTML p, mapping args, string content, mapping doc)
{
  doc->title = content;
  return "";
}

void setup_converters(mixed config)
{
  array sections = ({});

  setup_html_converter(config);
  if(objectp(config)) 
    sections = config->get_sections();
  else if(mappingp(config)) 
    sections = indices(config);

  foreach(glob("transform_*", sections); int x; string t)
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
      logger->debug("Configuring converter for " + mimetype);
      if(c->type=="filter")
        converters[mimetype]=FTSupport.Conversion.Filter(c->command, limits);
      else if(c->type=="converter")
        converters[mimetype]=FTSupport.Conversion.Converter(c->command, config["indexer"]->temp, limits);
      else logger->warn("unknown converter type %O for mime type %O", c->type, mimetype);
    }
  }

  logger->debug("Configuring internal converter for text/plain");
  converters["text/plain"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

  logger->debug("Configuring internal converter for text/html");
  converters["text/html"]=FTSupport.Conversion.PikeFilter(lambda(string d){ return d;});

}
