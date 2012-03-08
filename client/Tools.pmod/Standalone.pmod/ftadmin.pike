constant description = "Administrative Tool for Fins/Xapian FullText.";

#define ERROR(X) { werror(X + "\n"); return 1; }

#ifndef FINS_APPDIR
#define FINS_APPDIR 0
#endif

string auth;

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

   return meth(@newargs);
}

int new_index(string index)
{
  if(!index)
  ERROR("No index name specified.")
}

int grant_access(string index)
{
  if(!index)
  ERROR("No index name specified.")
}

int revoke_access(string index, string auth)
{
  if(!index)
  ERROR("No index name specified.")
  if(!auth)
  ERROR("No authorization code specified.")
}

int shutdown(string|void seconds)
{
}
