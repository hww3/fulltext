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
object writer;
object reader;
object analyzer;
object searcher;

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

   analyzer = Java.pkg["org/apache/lucene/analysis/StopAnalyzer"]();


}

object get_writer()
{
  if(!writer)
    writer=Java.pkg["org/apache/lucene/index/IndexWriter"]->_constructor("(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)V")(
      Java.JString(indexloc),
      Java.pkg["org/apache/lucene/analysis/standard/StandardAnalyzer"](sw), 0);
  return writer;
}

object get_reader()
{
  if(!reader)
   reader = Java.pkg["org/apache/lucene/index/IndexReader"]->_method("open", 
                        "(Ljava/lang/String;)Lorg/apache/lucene/index/IndexReader;")(indexloc);
  return reader;
}

object get_searcher()
{

   if(!searcher)
     searcher = Java.pkg["org/apache/lucene/search/IndexSearcher"]->_constructor("(Lorg/apache/lucene/index/IndexReader;)V")(get_reader());
   return searcher;
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

object Document()
{
  return Java.pkg["org/apache/lucene/document/Document"]();
}

object doSearch(string query, string field, string|void sort, int|void rev)
{

  object sorter;

  if(sort)
    sorter = Java.pkg["org/apache/lucene/search/Sort"]->_constructor("(Ljava/lang/String;Z)V")(sort, (int)rev);
  else
    sorter = Java.pkg["org/apache/lucene/search/Sort"]();

  object q = Java.pkg["org/apache/lucene/queryParser/QueryParser"]
                         ->parse(query, field, analyzer);

  object results = get_searcher()->_method("search",
    "(Lorg/apache/lucene/search/Query;Lorg/apache/lucene/search/Sort;)Lorg/apache/lucene/search/Hits;")(q, sorter);

  return results;
}

array search(string query, string field, int|void max, int|void start)
{
  array retval = ({});
  object results = doSearch(query, field);
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

int delete_by_handle(string handle)
{
  object term = Java.pkg["org/apache/lucene/index/Term"]("handle", handle);

  get_reader()->delete(term);

}

int delete_by_uuid(string uuid)
{
  object term = Java.pkg["org/apache/lucene/index/Term"]("uuid", uuid);

  get_reader()->delete(term);

}

void new()
{
  object xwriter=Java.pkg["org/apache/lucene/index/IndexWriter"]->_constructor("(Ljava/lang/String;Lorg/apache/lucene/analysis/Analyzer;Z)V")(
      Java.JString(indexloc),
      Java.pkg["org/apache/lucene/analysis/standard/StandardAnalyzer"](sw), 1);
  xwriter->close();

  xwriter = 0;

}

//! adds a document to the index. fields: title, contents, date (Calendar object)
//! handle
//!
//! @returns
//!  a string containing the uuid of the document in the index.
string add(mapping doc)
{
 string id = Standards.UUID.new_string();
 object d;

  d=Document();

 object uuid=Java.pkg["org/apache/lucene/document/Field"]->_method("Text",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("uuid"),
   Java.JString(id));

 object title=Java.pkg["org/apache/lucene/document/Field"]->_method("Text",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("title"),
   Java.JString(doc->title));

 object handle=Java.pkg["org/apache/lucene/document/Field"]->_method("Text",
"(Ljava/lang/String;Ljava/lang/String;)Lorg/apache/lucene/document/Field;")(Java.JString("handle"),
   Java.JString(doc->handle));

 object contents =Java.pkg["org/apache/lucene/document/Field"]->_method("UnStored",
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

  get_writer()->addDocument(d);

  if(i>optimize_threshold)
  {
    get_writer()->optimize();
    i = 0;
  }
  else i++;

  get_writer()->close();
  if(searcher)
    destruct(searcher);
  if(reader)
    destruct(reader);
  writer = 0;
  d=0; title=0; contents=0; uuid=0; date=0;

  return id;
}

static void destroy()
{
  if(reader)
    reader->close();

  if(writer)
    writer->close();
}

}


