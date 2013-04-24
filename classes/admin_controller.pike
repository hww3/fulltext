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

int new(object id, string auth, string index)
{
  if(!app->is_admin_user(auth))
    throw(Error.Generic("Unauthorized access.\n"));

  CHECKINDEX();

  if(app->index->exists(index))
    throw(Error.Generic("Index " + index + " already exists.\n"));

  return (int)app->index->new(index);
}

string grant_access(object id, string auth, string index)
{
  if(!app->is_admin_user(auth))
    throw(Error.Generic("Unauthorized access.\n"));

  CHECKINDEX();

  if(!app->index->exists(index))
    throw(Error.Generic("Index " + index + " does not exist.\n"));

  return app->security->grant_access(index);
}

int revoke_access(object id, string auth, string index, string authcode)
{
  if(!app->is_admin_user(auth))
    throw(Error.Generic("Unauthorized access.\n"));

  CHECKINDEX();

  if(!app->index->exists(index))
    throw(Error.Generic("Index " + index + " does not exist.\n"));

  return app->security->revoke_access(index, authcode);
}


// should this be auth protected as well?
int exists(object id, string auth, string index)
{
  if(!app->is_admin_user(auth))
    throw(Error.Generic("Unauthorized access.\n"));

  CHECKINDEX();
  return app->index->exists(index);
}


