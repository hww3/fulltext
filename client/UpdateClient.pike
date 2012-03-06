inherit .BaseClient;

string type="update";

//!
static void create(string|void index_url, string|void index_name, int|void create_if_new)
{
  ::create(index_url, index_name);
  int e = exists(name);
  if(!e && create_if_new)
    new(name);
  else if(!e)
    throw(Error.Generic("UpdateClient(): index " + name + " does not exist.\n"));
}

int new(string name)
{
  return call("new", name);
}

int exists(string name)
{
  return call("exists", name);
}

int delete_by_handle(string handle)
{
  return call("delete_by_handle", handle);

}
