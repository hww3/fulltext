import Fins;
import Tools.Logging;

constant __uses_session = 0;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))
#define CHECKAUTH() if(!auth || !app->check_access(index, auth)) throw(Error.Generic("authorization failed!\n"))

inherit XMLRPCController;

string add(object id, string auth, string index, string title, int date, string contents, string handle, string|void excerpt, string mimetype)
{
  CHECKAUTH();
  CHECKINDEX();

  string uuid;
  object dob = Calendar.Gregorian.Second(date);
  Log.info("Adding %s (date %O) to index %s", title, dob, index);
  uuid = app->index->add(index, Index.Document((["title": title, "date": dob, 
                           "contents": MIME.decode_base64(contents),
                           "excerpt": excerpt,
                           "handle": handle,
                           "mimetype": mimetype])));

  return uuid;
}

string add_from_map(object id, string auth, string index, mapping doc)
{
  CHECKAUTH();
  CHECKINDEX();

  string uuid;
  doc->date = Calendar.Gregorian.Second(doc->date);
  doc->contents = MIME.decode_base64(doc->contents);
  Log.info("Adding %s (date %O) to index %s", doc->title, doc->date, index);
  uuid = app->index->add(index, Index.Document(doc));

  return uuid;
}

int delete_by_handle(object id, string auth, string index, string handle)
{
  CHECKAUTH();
  CHECKINDEX();
  return app->index->delete_by_handle(index, handle);
}

int delete_by_uuid(object id, string auth, string index, string uuid)
{
  CHECKAUTH();
  CHECKINDEX();
  return app->index->delete_by_uuid(index, uuid);
}

int new(object id, string auth, string index)
{
  CHECKAUTH();
  CHECKINDEX();
  return app->index->new(index);
}

// should this be auth protected as well?
int exists(object id, string index)
{
  return app->index->exists(index);
}
