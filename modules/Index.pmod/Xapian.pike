#if !constant(Public.Xapian)
#error No Xapian support present.
#endif

inherit .ContentNormalizer : convert;
inherit .Common : common;
object logger = Tools.Logging.get_logger("fulltext.xapian");

constant qp = Public.Xapian.QueryParser;
int flags = qp.FLAG_PHRASE|qp.FLAG_BOOLEAN|qp.FLAG_LOVEHATE|qp.FLAG_SPELLING_CORRECTION;

mapping writers = ([]);
mapping readers = ([]);

int i = 0;
int optimize_threshold=100;

array stopwords=({"me", "my", "this", "the", "a", "an", "those",
 "and", "their", "mine", "to", "is", "it", "of", "in", "for", "are", "not"
 "if", "any", "re", "i", "but", "could"});

object stopper = Public.Xapian.SimpleStopper(stopwords);
object stemmer = Public.Xapian.Stem("english");

protected void create(string loc, mixed config)
{
  Stdio.Stat f = file_stat(loc);
  if(!f || !f->isdir)
  {
    logger->critical("FullText directory %s does not exist, or is a plain file.", loc);
    logger->critical("Please create this directory, or change the location in the configuration file.",);
    throw(Error.Generic("FullText directory " + loc + " does not exist, or is a plain file.\n"));
  }
  logger->info("FullText directory located at %s.", loc);
  indexloc = loc;

  start(config);
}

void start(mixed config)
{
  array stopwords=({});
  if(config["index"] && config["index"]["stopwordsfile"])
  {
    string f = Stdio.read_file(config["index"]["stopwordsfile"]);
    if(f && sizeof(f))
    {
      array words = (f/"\n") - ({""});
      set_stopwords(words);
    }
  }

  if(config["index"] && config["index"]["stem_language"])
  {
    set_stemmer(config["index"]["stem_language"]);
  }

  convert::start(config);
}

void set_stopwords(array words)
{
  stopper = Public.Xapian.SimpleStopper(words);
}

/*
valid langauges (from Xapian):

    none - don't stem terms
    danish (da)
    dutch (nl)
    english (en) - Martin Porter's 2002 revision of his stemmer
    english_lovins (lovins) - Lovin's stemmer
    english_porter (porter) - Porter's stemmer as described in his 1980 paper
    finnish (fi)
    french (fr)
    german (de)
    german2 - Normalises umlauts and �
    hungarian (hu)
    italian (it)
    kraaij_pohlmann - A different Dutch stemmer
    norwegian (nb, nn, no)
    portuguese (pt)
    romanian (ro)
    russian (ru)
    spanish (es)
    swedish (sv)
    turkish (tr)

*/
void set_stemmer(string language)
{
  stemmer = Public.Xapian.Stem(language);
}

void kill_writer(string index)
{
  if(writers[index])
  {
    (writers[index]=0);
    m_delete(writers, index);

  }
}

void kill_reader(string index)
{
  if(readers[index])
  {
    (readers[index]=0);
    m_delete(readers, index);
  }
}

object get_writer(string index)
{
  if(!writers[index])
  {
    logger->info("Creating new writer object for " + index + ".");
    writers[index]=Public.Xapian.WriteableDatabase(make_indexloc(index), Public.Xapian.DB_CREATE_OR_OPEN);
  }
  return writers[index];
}

object get_reader(string index)
{
  if(!readers[index])
  {
    logger->info("Creating new reader object for " + index + ".");
    readers[index] = Public.Xapian.Database(make_indexloc(index));
  }
  return readers[index];
}

object doSearch(string index, string query, int|void max, int|void start)
{
  logger->debug("doSearch");
 // object sorter;
  if(!max) max = 100;

  object q = get_query_parser(index);

  object qry = q->parse_query(query, flags);

  logger->debug("have query");
  object ftdb = get_reader(index);
  object e = Public.Xapian.Enquire(ftdb);
  e->set_query(qry, 0);
  logger->debug("getting results.");
  return e->get_mset(start, max, max);
}

mapping doFetch(string index, int docid)
{
  logger->debug("doFetch");

  object ftdb = get_reader(index);

  mixed doc = ftdb->get_document(docid);

  if(!doc) return 0;

  mapping res = ([]);

  res->data = doc->get_data();
  res->uuid = doc->get_value(0);
  res->title = doc->get_value(1);
  res->handle = doc->get_value(2);
  res->date = doc->get_value(3);
  res->misc = doc->get_value(4);
  res->keywords = doc->get_value(5);

  res->docid = docid;

  return res;
}

object get_query_parser(string index)
{
  object q = Public.Xapian.QueryParser();

  q->set_stopper(stopper);
  q->set_stemmer(stemmer);
  q->set_stemming_strategy(Public.Xapian.QueryParser.STEM_SOME);

  object s = get_reader(index);
  if(!s) throw(Error.Generic("Unable to get a new Xapian Database connection\n"));
  q->set_database(s);

  return q;
}

mapping search_with_corrections(string index, string query, string field, int|void max, int|void start)
{
  mapping res = ([]);

  res->results = search(index, query, field, max, start);
  object q = get_query_parser(index);
  q->parse_query(query, flags);
  string cq = q->get_corrected_query_string();

  if(sizeof(cq)) res->corrected_query = cq;

  return res;
}

mapping fetch(string index, int docid)
{
  return doFetch(index, docid);
}

array search(string index, string query, string field, int|void max, int|void start)
{
  array retval = ({});
  logger->debug("search");
  mixed e;
  object results;

if(e = catch( results = doSearch(index, query, max, start)))
  logger->exception("error while running query", e);
  logger->debug("%O", results);
e = catch{
  foreach(results;; object i)
  {
      retval+= ({ 
                  ([ "score": (float)(i->get_percent()/100.0), 
                     "uuid": i->get_document()->get_value(0),
                     "title": i->get_document()->get_value(1),
                     "handle" : i->get_document()->get_value(2),
                     "excerpt" : i->get_document()->get_data(),
                     "date": i->get_document()->get_value(3),
                     "misc": i->get_document()->get_value(4),
		     "docid": i->get_docid()
                   ]) 
                });
  }
};
if(e) logger->exception("an error occured while generating the results", e);
  return retval;

}

int delete_by_handle(string index, string handle)
{
  get_writer(index)->delete_document("H" + string_to_utf8(handle));
  return 1;
}

int delete_by_uuid(string index, string uuid)
{
  get_writer(index)->delete_document("U" + string_to_utf8(uuid));
  return 1;
}

int new(string index)
{
  if(!catch(make_indexloc(index)))
  {
    throw(Error.Generic("Index " + index + " already exists.\n"));
  }
  logger->info("Creating new index " + index + ".");
  object xwriter=Public.Xapian.WriteableDatabase(make_indexloc(index, 1), Public.Xapian.DB_CREATE);

  xwriter = 0;
  return 0;
}

string make_excerpt(string content)
{
 return FTSupport.make_excerpt(content);
}

//! adds a document to the index. fields: title, excerpt, misc, mimetype, handle, contents, keywords, date (Calendar object)
//! handle
//!
//! @returns
//!  a string containing the uuid of the document in the index.
string add(string index, Index.Document doc)
{
 logger->debug("Index.Xapian.add()");
 logger->debug("Index.Xapian.add(): checking for permission, type=%O.", doc->mimetype);
 if(!allowed_type(doc->mimetype))
 {
   logger->warn("Not indexing prohibited type " + doc->mimetype);
   return 0;
 }
 else
   logger->debug("Index.Xapian.add(): able to add mimetype.");

 doc->uuid = (string)Standards.UUID.make_version4();
 
 object d;
 string content;

 logger->debug("Index.Xapian.add(): creating Document object");

 d=Public.Xapian.Document();

 content = prepare_content(doc);

 if(!doc->excerpt)
   doc->excerpt = (make_excerpt(content)||"");

 logger->debug("Have normalized content: %O.", content);

 logger->debug("Have normalized content: %O.", content);

//werror("content: %O\n", content);
//werror("doc->excerpt: %O, %O\n", doc->excerpt, make_excerpt(content));

 d->set_data(doc->excerpt);

// Log.debug("added data");

 d->add_value(0, doc->uuid);
// Log.debug("added value 0");
 d->add_value(1, doc->title || "");
// Log.debug("added value 1");
 d->add_value(2, doc->handle || "");
// Log.debug("added value 2");
 d->add_value(3, doc->date->format_smtp());
// Log.debug("added value 3");
 d->add_value(4, doc->misc||""); 
// Log.debug("getting ready to add terms");
 d->add_value(5, doc->keywords?(doc->keywords*", "):""); 
// Log.debug("getting ready to add terms");

 array terms = ({ doc->handle, doc->title, doc->uuid });

 if(doc->keywords) terms += doc->keywords;

 object writer = get_writer(index);

 add_contents(writer, d, terms * " ", 1);
//werror("content: %O\n", content);
 add_contents(writer, d, content);

 d->add_term("H" + string_to_utf8(doc->handle), 1);
 d->add_term("U" + string_to_utf8(doc->uuid), 1);

// werror("adding %O\n", d);

 logger->info("adding document with %d terms.", sizeof(terms));
 mixed id = writer->add_document(d);
 doc->docid = id;
 doc->index = index;

 get_reader(index)->reopen();
 kill_writer(index);
 kill_reader(index);

 return id;
}

int exists(string index)
{
  object o;
  catch(o = get_reader(index));
  return(o?1:0);
}

void add_contents(object writer, object doc, string contents, int|void no_postings)
{
  object tg = Public.Xapian.TermGenerator();
  tg->set_database(writer);
  tg->set_document(doc);
  tg->set_stemmer(stemmer);
  tg->set_flags(Public.Xapian.TermGenerator.FLAG_SPELLING, 0);

  if(no_postings)
//   tg->index_text_without_positions(contents, 1, "");
   tg->index_text(contents, 1, "");
  else
//   tg->index_text_without_positions(contents, 1, "");
   tg->index_text(contents, 1, "");
  
}

protected void destroy()
{
  foreach(readers;; object reader)
    reader = 0;

  foreach(writers;; object writer)
    writer = 0;
}

