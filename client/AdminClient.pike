inherit .BaseClient;

string type="admin";

//!
static void create(string|void index_url, string authcode)
{
  ::create(index_url, 0); // we store auth in name field for now.
  auth = authcode;
}

protected mixed auth_call(string func, mixed ... args)
{
  return call(func, auth, @args);
}

//!
int shutdown(int delay)
{
  return auth_call("shutdown", delay);
}

//!
string grant_access(string index)
{
  return auth_call("grant_access", index);
}

//!
int revoke_access(string index, string authcode)
{
  return auth_call("grant_access", index, authcode);
}
