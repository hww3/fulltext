import Fins;
import Tools.Logging;
constant qp = Public.Xapian.QueryParser;
inherit Application;

int flags = qp.FLAG_PHRASE|qp.FLAG_BOOLEAN|qp.FLAG_LOVEHATE|qp.FLAG_SPELLING_CORRECTION;

object index;

void start()
{
  // if we don't have a FT index, we should create it.

  signal(signum("SIGINT"), shutdown_app);
  signal(signum("SIGQUIT"), shutdown_app);
  signal(signum("SIGKILL"), shutdown_app);
  signal(signum("SIGABRT"), shutdown_app);

  index = Index(getcwd() + "/ft");
}


void shutdown_app()
{
  Log.critical("Shutting down indexer...\n");
  destruct(index);
  exit(0);
}

class Index
{

string indexloc;
mapping writers = ([]);
mapping readers = ([]);

static void create(string loc)
{
  Stdio.Stat f = file_stat(loc);
  if(!f || !f->isdir)
  {
    Log.critical("FullText directory %s does not exist, or is a plain file.", loc);
    throw(Error.Generic("FullText directory " + loc + " does not exist, or is a plain file.\n"));
  }
  indexloc = loc;
}

void kill_writer(string index)
{
  if(writers[index])
  {
    destruct(writers[index]);
    m_delete(writers, index);

  }
}

void kill_reader(string index)
{
  if(readers[index])
  {
    destruct(readers[index]);
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

int i = 0;
int optimize_threshold=100;

array stopwords=({"me", "my", "this", "the", "a", "an", "those",
 "and", "their", "mine", "to", "is", "it", "of", "in", "for", "are", "not"
 "if", "any", "re", "i", "but", "could"});

object stopper = Public.Xapian.SimpleStopper(stopwords);
object stemmer = Public.Xapian.Stem("english");

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

object doSearch(string index, string query, int|void start, int|void max)
{
  Log.debug("doSearch");
  object sorter;
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
  res->author = doc->get_value(4);

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

if(e = catch( results = doSearch(index, query, start, max)))
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

//! adds a document to the index. fields: title, contents, date (Calendar object)
//! handle
//!
//! @returns
//!  a string containing the uuid of the document in the index.
string add(string index, mapping doc)
{
 string id = Standards.UUID.new_string();
 object d;

// Log.debug("add");

 d=Public.Xapian.Document();

 d->set_data(doc->excerpt||"");

// Log.debug("added data");

 d->add_value(0, id);
// Log.debug("added value 0");
 d->add_value(1, doc->title || "");
// Log.debug("added value 1");
 d->add_value(2, doc->handle || "");
// Log.debug("added value 2");
 d->add_value(3, doc->date->format_smtp());
 
// Log.debug("getting ready to add terms");

 array terms = ({ doc->handle, doc->title, id });

 object writer = get_writer(index);

 add_contents(writer, d, terms * " ", 1);
 add_contents(writer, d, doc->contents);

 d->add_term("H" + string_to_utf8(doc->handle), 1);
 d->add_term("U" + string_to_utf8(id), 1);

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

}


