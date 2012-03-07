import Fins;
import Tools.Logging;

inherit XMLRPCController;

constant __uses_session = 0;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))
#define CHECKAUTH() if(!auth || !app->check_access(index, auth)) throw(Error.Generic("authorization failed!\n"))

array fetch(object id, string auth, string index, int docid)
{
  CHECKAUTH();
  CHECKINDEX();
  Log.info("Got fetch request '" + docid + "' for " + index);

  return app->index->fetch(index, docid);
}

array search(object id, string auth, string index, string query, string field, int max, int start)
{
  CHECKAUTH();
  CHECKINDEX();

  Log.info("Got search query '" + query + "' for " + index);

  return app->index->search(index, query, field, max, start);
}

mapping search_with_corrections(object id, string auth, string index, string query, string field, int max, int start)
{
  CHECKAUTH();
  CHECKINDEX();

  Log.info("Got search query (corrections requested) '" + query + "' for " + index);

  return app->index->search_with_corrections(index, query, field, max, start);
}

