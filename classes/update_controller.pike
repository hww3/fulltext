import Fins;
import Tools.Logging;

inherit XMLRPCController;

string add(object id, string title, int date, string contents, string handle)
{
  string uuid;
  object dob = Calendar.Gregorian.Second(date);
  Log.info("Adding %s (date %O) to index.", title, dob);
  uuid = app->index->add((["title": title, "date": dob, "contents": contents,
                           "handle": handle]));

  return uuid;
}

int delete_by_handle(string handle)
{
  return app->index->delete_by_handle(handle);
}

int delete_by_uuid(string uuid)
{
  return app->index->delete_by_uuid(uuid);
}

void new()
{
  app->index->new();
}
