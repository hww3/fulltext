import Fins;
import Tools.Logging;

inherit XMLRPCController;

string search(object id, string query, string field, int start, int max)
{
  Log.info("Got search query " + query);

  return app->index->search(query, field, start, max);
}
