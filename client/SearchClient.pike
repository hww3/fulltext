inherit .BaseClient;

string type="search";

Protocols.XMLRPC.Client c;

//! Search the index looking for records whose content matches query.
array search(string query, int|void limit, int|void start)
{
  return advanced_search(query, "contents", limit, start);
}

//! Search a specified field in index for matches on query.
array advanced_search(string query, string search_field, int|void limit, int|void start)
{
  if(!c) c = get_client();
  // for some reason, the logical order of used arguments is reversed.
  mixed r = c["search"](name, query, search_field, limit||25, start||0);
  
  if(objectp(r))
    throw(.RemoteError(r));

  if(r[0] && !sizeof(r[0])) return ({});
  else return r[0];
}
