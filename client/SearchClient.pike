inherit .BaseClient;

string type="search";

Protocols.XMLRPC.Client c;

array search(string query)
{
  return advanced_search(query, "contents");
}

array advanced_search(string query, string loc)
{
  if(!c) c = get_client();
  return c["search"](name, query, loc);
}
