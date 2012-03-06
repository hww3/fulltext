inherit .BaseClient;

string type="search";

Protocols.XMLRPC.Client c;

array search(string query, int|void limit, int|void start)
{
  return advanced_search(query, "contents", limit, start);
}

array advanced_search(string query, string loc, int|void limit, int|void start)
{
  if(!c) c = get_client();
  // for some reason, the logical order of used arguments is reversed.
  mixed r = c["search"](name, query, loc, limit||25, start||0);
  
  if(objectp(r))
    throw(.RemoteError(r));

  if(r[0] && !sizeof(r[0])) return ({});
  else return r[0];
}
