import Fins;
import Tools.Logging;

inherit Application;

mapping admin_user_cache = ([]);
int simple_security = 0;

object index;
object security;

void start()
{
  // if we don't have a FT index, we should create it.

  signal(signum("SIGINT"), shutdown_app);
  signal(signum("SIGQUIT"), shutdown_app);
  signal(signum("SIGKILL"), shutdown_app);
  signal(signum("SIGABRT"), shutdown_app);

  string indexloc = combine_path(getcwd(), "ft");
  index = Index.Xapian(indexloc, config);
  security = Index.Security(indexloc);

  mixed t;
  mixed e = catch(t = config->get_value("auth", "admin"));
  if(e || !t)
  {
    string atoken = security->mkauthcode("_FullTextAdmin");
    config->set_value("auth", "admin", atoken);
    Log.info("***");
    Log.info("*** You do not appear to have any admin tokens in your configuration.");
    Log.info("*** That's not very useful, so we've created one for you: %s", atoken);
    Log.info("***");
  }
  
  catch
  {
    if((int)config->get_value("auth", "use_simple_security")) 
    {
      Log.info("Using simple security, admin auth codes are valid for all indices.");
      simple_security = 1;
    }
  };
}

void shutdown_app()
{
  Log.critical("Shutting down indexer...\n");
  destruct(index);
  exit(0);
}

int(0..1) check_access(string index, string auth)
{
  if(simple_security) return is_admin_user(auth);
  else return this->security->check_access(index, auth);
}

string grant_access(string index)
{
  if(simple_security) throw(Error.Generic("Simple Security in effect, this method is not available\n"));
  else return this->security->grant_access(index);
}

int(0..1) revoke_access(string index, string auth)
{
  if(simple_security) throw(Error.Generic("Simple Security in effect, this method is not available\n"));
  else return this->security->revoke_access(index, auth);
}

int(0..1) is_admin_user(string auth)
{
  if(admin_user_cache[auth]) return 1;

  int rv = low_is_admin_user(auth);

  if(!rv) return 0;

  admin_user_cache[auth] = 1;

  return 1;  
}

int(0..1) low_is_admin_user(string auth)
{
  if(config["auth"])
  {
    mixed a = config["auth"]["admin"];
    if(stringp(a) && String.trim_whites(a) == auth) return 1;
    else if(arrayp(a))
    {
      foreach(a;; string v)
       if(String.trim_whites(v) == auth) return 1;
    }
  }

  return 0;
}
