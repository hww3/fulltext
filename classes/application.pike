import Fins;
import Tools.Logging;

inherit Application;

object index;

void start()
{
  // if we don't have a FT index, we should create it.
  index = Index(getcwd() + "/ft");
}



class Index
{

string indexloc;
mapping writers = ([]);
mapping readers = ([]);
mapping analyzers = ([]);
mapping searchers = ([]);

static void create(string loc)
{

  Stdio.Stat f = file_stat(loc);
  if(!f || !f->isdir)
  {
    Log.critical("FullText directory %s does not exist, or is a plain file.", loc);
    throw(Error.Generic("FullText directory " + loc + " does not exist, or is a plain file.\n"));
  }
  indexloc = loc;

  if(!sw) sw = Java.JArray(stopwords);

}

object get_writer(string index)
{
  if(!writers[index])
    writers[index]=Java.pkg["org/apache/lucene/index/IndexWriter"]->_constructor("(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)V")(
      Java.JString(make_indexloc(index)),
      Java.pkg["org/apache/lucene/analysis/standard/StandardAnalyzer"](sw), 0);
  return writers[index];
}

object get_analyzer(string index)
{
  if(!analyzers[index])
    analyzers[index]= Java.pkg["org/apache/lucene/analysis/standard/StandardAnalyzer"](sw);

  return analyzers[index];
}

object get_reader(string index)
{
  if(!readers[index])
   readers[index] = Java.pkg["org/apache/lucene/index/IndexReader"]->_method("open", 
                        "(Ljava/lang/String;)Lorg/apache/lucene/index/IndexReader;")(make_indexloc(index));
  return readers[index];
}

object get_searcher(string index)
{

   if(!searchers[index])
     searchers[index] = Java.pkg["org/apache/lucene/search/IndexSearcher"]->_constructor("(Lorg/apache/lucene/index/IndexReader;)V")(get_reader(index));
   return searchers[index];
}

//! converts a unix timestamp integer or Calendar object
//! into a Java Date object.
object JDate(int|object t)
{
  object x;
  if(intp(t))
  {
    x=Calendar.Second(t);
  }
  else x=t;

  object c=Java.pkg["java/util/Calendar"]->getInstance();

  c->set(
    x->year_no(),
    x->month_no()-1,
    x->month_day(),
    x->hour_no(),
    x->minute_no(),
    x->second_no()
  );

  return c->getTime();
}

int i = 0;
int optimize_threshold=100;

array stopwords=({"me", "my", "this", "the", "a", "an", "those", "pike",
 "and", "their", "mine", "to", "is", "it", "of", "in", "for", "are", "not"
 "if", "any", "re", "i", "but", "could"});

object sw;

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

object Document()
{
  return Java.pkg["org/apache/lucene/document/Document"]();
}

object doSearch(string index, string query, string field, string|void sort, int|void rev)
{

  object sorter;

  if(sort)
    sorter = Java.pkg["org/apache/lucene/search/Sort"]->_constructor("(Ljava/lang/String;Z)V")(sort, (int)rev);
  else
    sorter = Java.pkg["org/apache/lucene/search/Sort"]();

  object q = Java.pkg["org/apache/lucene/queryParser/QueryParser"]
                         ->parse(query, field, get_analyzer(index));

  object results = get_searcher(index)->_method("search",
    "(Lorg/apache/lucene/search/Query;Lorg/apache/lucene/search/Sort;)Lorg/apache/lucene/search/Hits;")(q, sorter);

  return results;
}

array search(string index, string query, string field, int|void max, int|void start)
{
  array retval = ({});
  object results = doSearch(index, query, field);
  if(!max) max=25;

  for(int i = start; (i < (int)results->length()) && (i < (start+max)); i++)
  {
      object document = results->doc(i);
      object jdate = Java.pkg["org/apache/lucene/document/DateField"]->stringToDate(document->get("date"));
      object df = Java.pkg["java/text/SimpleDateFormat"]("yyyy/MM/dd kk:mm");
      string date = (string)df->_method("format", "(Ljava/util/Date;)Ljava/lang/String;")(jdate);
      retval+= ({ 
                  ([ "score": (float)(results->score(i)), 
                     "uuid": (string)document->get("uuid"),
                     "title": (string)document->get("title"),
                     "handle" : (string)document->get("handle"),
                     "date": date 
                   ]) 
                });
    }

  return retval;

}

int delete_by_handle(string index, string handle)
{
  object term = Java.pkg["org/apache/lucene/index/Term"]("handle", handle);

  return get_reader(index)->delete(term);

}

int delete_by_uuid(string index, string uuid)
{
  object term = Java.pkg["org/apache/lucene/index/Term"]("uuid", uuid);

  return get_reader(index)->delete(term);

}

void new(string index)
{
  if(!catch(make_indexloc(index)))
  {
    throw(Error.Generic("Index " + index + " already exists.\n"));
  }
  object xwriter=Java.pkg["org/apache/lucene/index/IndexWriter"]->_constructor("(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)V")(
      Java.JString(make_indexloc(index, 1)),
      Java.pkg["org/apache/lucene/analysis/standard/StandardAnalyzer"](sw), 1);
  xwriter->close();

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

  d=Document();

 object 
uuid=Java.pkg["org/apache/lucene/document/Field"]->_method("Keyword",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("uuid"),
   Java.JString(id));

 object title=Java.pkg["org/apache/lucene/document/Field"]->_method("Text",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("title"),
   Java.JString(doc->title));

 object handle=Java.pkg["org/apache/lucene/document/Field"]->_method("Keyword",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("handle"),
   Java.JString(doc->handle));

 object contents =Java.pkg["org/apache/lucene/document/Field"]->_method("Text",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("contents"),
   Java.JString(doc->contents));

object ddate=JDate(doc->date);

object date=Java.pkg["org/apache/lucene/document/Field"]->_method("Keyword",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("date"),
Java.pkg["org/apache/lucene/document/DateField"]->dateToString(ddate));

 d->add(date);
 d->add(uuid);
 d->add(title);
 d->add(handle);
 d->add(contents);

  get_writer(index)->addDocument(d);

  if(i>optimize_threshold)
  {
    get_writer(index)->optimize();
    i = 0;
  }
  else i++;

  get_writer(index)->close();
  if(get_searcher(index))
    destruct(get_searcher(index));
  if(get_reader(index))
    destruct(get_reader(index));
  destruct(get_writer(index));
  d=0; title=0; contents=0; uuid=0; date=0;

  return id;
}

static void destroy()
{
  foreach(readers;; object reader)
    reader->close();

  foreach(writers;; object writer)
    writer->close();
}

}


