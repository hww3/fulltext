import Fins;
import Tools.Logging;

inherit XMLRPCController;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))

string search(object id, string index, string query, string field, int start, int max)
{
  CHECKINDEX();

  Log.info("Got search query '" + query + "' for " + index);

  return app->index->search(index, query, field, start, max);
}
