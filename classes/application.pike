import Fins;
import Tools.Logging;

inherit Application;

object index;

void start()
{
  // if we don't have a FT index, we should create it.

  signal(signum("SIGINT"), shutdown_app);
  signal(signum("SIGQUIT"), shutdown_app);
  signal(signum("SIGKILL"), shutdown_app);
  signal(signum("SIGABRT"), shutdown_app);

  index = Index.Xapian(getcwd() + "/ft", config);
}


void shutdown_app()
{
  Log.critical("Shutting down indexer...\n");
  destruct(index);
  exit(0);
}

int(0..1) is_admin_user(string auth)
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
