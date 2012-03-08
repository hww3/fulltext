constant description = "Administrative Tool for Fins/Xapian FullText.";

#define ERROR(X) { werror(X + "\n"); return 1; }

#ifndef FINS_APPDIR
#define FINS_APPDIR 0
#endif

string auth;
int port;
object client;

int main(int argc, array argv)
{
   if(!argv || sizeof(argv) < 2)
   {
     werror("invalid arguments. usage: ftadmin.sh [command]\n");
     return 1;
   }

   if(!FINS_APPDIR)
   {
     ERROR("Full Text App dir not specified. Are you not running this using ftadmin.sh?");
   }

   function meth;

   string command = argv[1];

   switch(command)
   {
     case "new":
       meth = new_index;
       break;

     case "revoke":
       meth = revoke_access;
       break;

     case "grant":
       meth = grant_access;
       break;

     case "shutdown":
       meth = shutdown;
       break;

     default:
       werror("unknown command \"%s\".\n", command);
       werror("valid commands include: new, grant, revoke, shutdown\n");
       return 1;
       break;
   }

   array newargs = ({});
   if(sizeof(argv) > 1) newargs = argv[2..];

   string configfile = combine_path(FINS_APPDIR, "config/dev.cfg");
   object config = Fins.Configuration(FINS_APPDIR, configfile);
   if(catch(auth = config->get_value("auth", "admin")))
     ERROR("No admin authentication code set in configuration file. Have you not started the app yet?\nConfiguration file=" + configfile);

   if(catch(port = (int)config->get_value("web", "port")))
     ERROR("No listen port set in configuration file. Please update your configuration file.\nConfiguration file=" + configfile);

   client = FullText.AdminClient("http://127.0.0.1:" + port, auth);

   return meth(@newargs);
}

int new_index(string index)
{
  if(!index)
  ERROR("No index name specified.")
  int rv = client->new(index);
  if(!rv)
    write("Index %O created successfully.\n", index);
  return rv;
}

int grant_access(string index)
{
  if(!index)
  ERROR("No index name specified.")
  string key = client->grant_access(index);
  werror("Authorization Key for %O is %O\n", index, key);
}

int revoke_access(string index, string auth)
{
  if(!index)
  ERROR("No index name specified.")
  if(!auth)
  ERROR("No authorization code specified.")
  int res = client->revoke_access(index, auth);

  if(res) 
    write("Access revoked successfully.\n");
  else
    werror("Unable to revoke access for key %O on index %O. Is this information correct?\n", auth, index);

  return res;
}

int shutdown(string|void seconds)
{
  if(!auth)
  ERROR("No authorization code specified.")
  int res = client->shutdown(seconds);
  return res;
}
