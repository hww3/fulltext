import Fins;
import Tools.Logging;

inherit Application;

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

array stopwords=({"me", "my", "this", "the", "a", "an", "those", "pike",
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

  object q = Public.Xapian.QueryParser();

  q->set_stopper(stopper);
  q->set_stemmer(stemmer);

  object qry = q->parse_query(query, 0);
  Log.debug("have query");
  object s = get_reader(index);
  object e = Public.Xapian.Enquire(s);
  e->set_query(qry, 0);
  Log.debug("getting results.");
  return e->get_mset(start, max, max);
}

array search(string index, string query, string field, int|void max, int|void start)
{
  int i;
  array retval = ({});
Log.debug("search");
  mixed e;
  object results;

if(e = catch( results = doSearch(index, query, start, max)))
  Log.exception("error while running query", e);
  Log.debug("%O", results);
e = catch{
  for(i = results->begin(); i != results->end(); i->next())
  {
      retval+= ({ 
                  ([ "score": (float)(i->get_percent()/100.0), 
                     "uuid": i->get_document()->get_value(0),
                     "title": i->get_document()->get_value(1),
                     "handle" : i->get_document()->get_value(2),
                     "excerpt" : i->get_document()->get_data(),
                     "date": i->get_document()->get_value(3)
                   ]) 
                });
  }
};
if(e) Log.exception("an error occured while generating the results", e);
  return retval;

}

int delete_by_handle(string index, string handle)
{
  get_writer(index)->delete_document(handle);
  return 1;
}

int delete_by_uuid(string index, string uuid)
{
  get_writer(index)->delete_document(uuid);
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

 Log.debug("add");

 d=Public.Xapian.Document();

 d->set_data(doc->excerpt||"");

 Log.debug("added data");

 d->add_value(0, id);
 Log.debug("added value 0");
 d->add_value(1, doc->title || "");
 Log.debug("added value 1");
 d->add_value(2, doc->handle || "");
 Log.debug("added value 2");
 d->add_value(3, doc->date->format_smtp());
 
 Log.debug("getting ready to add terms");

 d->add_term(doc->handle || "", 1);
 d->add_term(id || "", 1);

 add_contents(d, doc->contents);

 get_writer(index)->add_document(d);

 kill_writer(index);
 kill_reader(index);

 return id;
}

void add_contents(object doc, string contents)
{
  contents = replace(contents, ({"\t", "\r", "\n", ".", "!", ",", "?", "!", "/", "\\", ":"}), ({" ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " "}));

Log.debug("contents: %s", contents);
  array terms = (contents / " ") - ({""});

  foreach(terms; int i; string term)
  {
    if(!strlen(term)) continue;
    string word = stemmer->stem_word(lower_case(term));
    if(stopper(word)) continue;
    write("adding " + word + "\n");
    doc->add_posting(word, i, 1);
  }
  
}

static void destroy()
{
  foreach(readers;; object reader)
    reader = 0;

  foreach(writers;; object writer)
    writer = 0;
}

}


