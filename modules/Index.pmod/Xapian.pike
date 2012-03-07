import Tools.Logging;

inherit .ContentNormalizer : convert;

constant qp = Public.Xapian.QueryParser;
int flags = qp.FLAG_PHRASE|qp.FLAG_BOOLEAN|qp.FLAG_LOVEHATE|qp.FLAG_SPELLING_CORRECTION;

string indexloc;
mapping writers = ([]);
mapping readers = ([]);

Tools.Mapping.MappingCache authcache = Tools.Mapping.MappingCache(300);

int i = 0;
int optimize_threshold=100;

array stopwords=({"me", "my", "this", "the", "a", "an", "those",
 "and", "their", "mine", "to", "is", "it", "of", "in", "for", "are", "not"
 "if", "any", "re", "i", "but", "could"});

object stopper = Public.Xapian.SimpleStopper(stopwords);
object stemmer = Public.Xapian.Stem("english");

static void create(string loc, mixed config)
{
  Stdio.Stat f = file_stat(loc);
  if(!f || !f->isdir)
  {
    Log.critical("FullText directory %s does not exist, or is a plain file.", loc);
    throw(Error.Generic("FullText directory " + loc + " does not exist, or is a plain file.\n"));
  }
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

string get_authfile(string index)
{
  return combine_path(make_indexloc(index), "ftauth");
}

mixed get_auth(string index)
{
  mixed ac;
  if(!(ac = authcache[index]))
  {
    array afc = (Stdio.read_file(get_authfile(index))||"") / "\n";
    ac = (<>);
    foreach(afc;; string l)
    {
      l = String.trim_whites(l);
      if(sizeof(l)) ac[l] = 1;
    }    

    authcache[index] = ac;
  }

  return ac;
}

int save_auth(string index, multiset ac)
{
  return Stdio.write_file(get_authfile(index), (array)ac*"\n");
}

string mkauthcode(string index)
{
  string in = Crypto.Random.random_string(25);
  in += index;
  return String.string2hex(Crypto.MD5()->hash(in + time()));
}

string grant_access(string index)
{
  mixed ac = get_auth(index);
  string authcode = mkauthcode(index);
  ac[authcode] = 1;
  save_auth(index, ac);
  return authcode;
}

int revoke_access(string index, string auth)
{
  mixed ac = get_auth(index);
  int rv = ac[auth];
  ac[auth] = 0;
  save_auth(index, ac);
  return (rv?1:0);
}

int check_access(string index, string auth)
{
  mixed ac = get_auth(index);
  return (ac[auth]?1:0);
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
    german2 - Normalises umlauts and ß
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
    Log.info("Creating new writer object for " + index + ".");
    writers[index]=Public.Xapian.WriteableDatabase(make_indexloc(index), Public.Xapian.DB_CREATE_OR_OPEN);
  }
  return writers[index];
}

object get_reader(string index)
{
  if(!readers[index])
  {
    Log.info("Creating new reader object for " + index + ".");
    readers[index] = Public.Xapian.Database(make_indexloc(index));
  }
  return readers[index];
}

static string make_indexloc(string index, int|void force)
{
  string loc;

  index = replace(index, "/", "_");

  loc = Stdio.append_path(indexloc, index);

  if(!file_stat(loc)) // the requested index directory doesn't exist.
  {

    if(!force)
    {
      throw(Error.Generic("index " + index + " does not exist.\n"));
    }

    else // we're forcing the creation.
    {
       mkdir(loc);
    }
  }

  return loc;
}

object doSearch(string index, string query, int|void max, int|void start)
{
  Log.debug("doSearch");
 // object sorter;
  if(!max) max = 100;

  object q = get_query_parser(index);

  object qry = q->parse_query(query, flags);

  Log.debug("have query");
  object ftdb = get_reader(index);
  object e = Public.Xapian.Enquire(ftdb);
  e->set_query(qry, 0);
  Log.debug("getting results.");
  return e->get_mset(start, max, max);
}

mapping doFetch(string index, int docid)
{
  Log.debug("doFetch");

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
Log.debug("search");
  mixed e;
  object results;

if(e = catch( results = doSearch(index, query, max, start)))
  Log.exception("error while running query", e);
  Log.debug("%O", results);
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
if(e) Log.exception("an error occured while generating the results", e);
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

void new(string index)
{
  if(!catch(make_indexloc(index)))
  {
    throw(Error.Generic("Index " + index + " already exists.\n"));
  }
  Log.info("Creating new index " + index + ".");
  object xwriter=Public.Xapian.WriteableDatabase(make_indexloc(index, 1), Public.Xapian.DB_CREATE);

  xwriter = 0;

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
string add(string index, mapping doc)
{
 Log.debug("Index.Xapian.add()");
 if(!allowed_type(doc->mimetype))
 {
   Log.debug("Index.Xapian.add(): checking for permission.");
   Log.warn("Not indexing prohibited type " + doc->mimetype);
   return 0;
 }
 else
   Log.debug("Index.Xapian.add(): able to add mimetype.");

 string id = (string)Standards.UUID.make_version4();
 object d;
 string content;

 Log.debug("Index.Xapian.add(): creating Document object");

 d=Public.Xapian.Document();

 content = prepare_content(doc->contents, doc->mimetype);

//werror("content: %O\n", content);
//werror("doc->excerpt: %O, %O\n", doc->excerpt, make_excerpt(content));

 d->set_data(doc->excerpt||make_excerpt(content)||"");

// Log.debug("added data");

 d->add_value(0, id);
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

 array terms = ({ doc->handle, doc->title, id });

 if(doc->keywords) terms += doc->keywords;

 object writer = get_writer(index);

 add_contents(writer, d, terms * " ", 1);
//werror("content: %O\n", content);
 add_contents(writer, d, content);

 d->add_term("H" + string_to_utf8(doc->handle), 1);
 d->add_term("U" + string_to_utf8(id), 1);

// werror("adding %O\n", d);

 Log.info("adding document with %d terms.", sizeof(terms));
 writer->add_document(d);

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
   tg->index_text_without_positions(contents, 1, "");
  else
   tg->index_text(contents, 1, "");
  
}

static void destroy()
{
  foreach(readers;; object reader)
    reader = 0;

  foreach(writers;; object writer)
    writer = 0;
}

