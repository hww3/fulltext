inherit .BaseClient;

string type="admin";

//!
static void create(string|void index_url, string auth)
{
  ::create(index_url, auth); // we store auth in name field for now.
}

int shutdown(int delay)
{
  return call("shutdown", name, delay);
}

