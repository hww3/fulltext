string url = "http://localhost:8124";
string type;
string name = "default";

void create(string|void index_url, string|void index_name)
{
  if(index_url) 
    url = index_url;
  if(index_name)
    name = index_name;

  if(!type) throw(Error.Generic("Cannot instantiate BaseClient directly!\n"));
}

Protocols.XMLRPC.Client get_client()
{
  object u = Standards.URI("/" + type + "/", Standards.URI(url));
  u->add_query_variable("PSESSIONID", "123");
  return Protocols.XMLRPC.Client(u);
}
