import Fins;
import Tools.Logging;

constant __uses_session = 0;

#define CHECKINDEX() if(!index || index=="0") throw(Error.Generic("index not specified!\n"))

inherit XMLRPCController;

int shutdown(object id, string auth, int seconds)
{
  if(!app->is_admin_user(auth))
    throw(Error.Generic("Unauthorized access.\n"));

  if(seconds > 60) seconds = 60;
  Log.warn("Shutting down indexer in %d seconds.", seconds);

  call_out(app->shutdown_app, seconds);
  return 1;
}

int exists(object id, string index)
{
  return app->index->exists(index);
}
