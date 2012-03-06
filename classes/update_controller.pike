import Fins;
import Tools.Logging;

constant __uses_session = 0;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))

inherit XMLRPCController;

string add(object id, string index, string title, int date, string contents, string handle, string|void excerpt, string mimetype)
{
  CHECKINDEX();

  string uuid;
  object dob = Calendar.Gregorian.Second(date);
  Log.info("Adding %s (date %O) to index %s", title, dob, index);
  uuid = app->index->add(index, (["title": title, "date": dob, 
                           "contents": MIME.decode_base64(contents),
                           "excerpt": excerpt,
                           "handle": handle,
                           "mimetype": mimetype]));

  return uuid;
}

int delete_by_handle(object id, string index, string handle)
{
  CHECKINDEX();
  return app->index->delete_by_handle(index, handle);
}

int delete_by_uuid(object id, string index, string uuid)
{
  CHECKINDEX();
  return app->index->delete_by_uuid(index, uuid);
}

int new(object id, string index)
{
  CHECKINDEX();
  return app->index->new(index);
}

int exists(object id, string index)
{
  return app->index->exists(index);
}
