import Fins;
import Tools.Logging;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))

inherit XMLRPCController;

string add(object id, string index, string title, int date, string contents, string handle, string|void excerpt)
{
  CHECKINDEX();

  string uuid;
  object dob = Calendar.Gregorian.Second(date);
  Log.info("Adding %s (date %O) to index %s", title, dob, index);
  uuid = app->index->add(index, (["title": title, "date": dob, 
                           "contents": contents,
                           "excerpt": excerpt,
                           "handle": handle]));

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

void new(object id, string index)
{
  CHECKINDEX();
  app->index->new(index);
}
