object logger = Tools.Logging.get_logger("fulltext.security");

Tools.Mapping.MappingCache authcache = Tools.Mapping.MappingCache(300);

static void create(string loc)
{
  Stdio.Stat f = file_stat(loc);
  if(!f || !f->isdir)
  {
    logger->critical("FullText directory %s does not exist, or is a plain file.", loc);
    logger->critical("Please create this directory, or change the location in the configuration file.",);
    throw(Error.Generic("FullText directory " + loc + " does not exist, or is a plain file.\n"));
  }
  indexloc = loc;
}

string get_authfile(string index)
{
  return combine_path(make_indexloc(index), "ftauth");
}

mixed get_auth(string index)
{
  mixed ac;
  if(!(ac = authcache[index]))
  {
    array afc = (Stdio.read_file(get_authfile(index))||"") / "\n";
    ac = (<>);
    foreach(afc;; string l)
    {
      l = String.trim_whites(l);
      if(sizeof(l)) ac[l] = 1;
    }    

    authcache[index] = ac;
  }

  return ac;
}

int save_auth(string index, multiset ac)
{
  return Stdio.write_file(get_authfile(index), (array)ac*"\n");
}

string mkauthcode(string index)
{
  string in = Crypto.Random.random_string(25);
  in += index;
  return String.string2hex(Crypto.MD5()->hash(in + time()));
}

string grant_access(string index)
{
  mixed ac = get_auth(index);
  string authcode = mkauthcode(index);
  ac[authcode] = 1;
  save_auth(index, ac);
  return authcode;
}

int revoke_access(string index, string auth)
{
  mixed ac = get_auth(index);
  int rv = ac[auth];
  ac[auth] = 0;
  save_auth(index, ac);
  return (rv?1:0);
}

int check_access(string index, string auth)
{
  mixed ac = get_auth(index);
  return (ac[auth]?1:0);
}
