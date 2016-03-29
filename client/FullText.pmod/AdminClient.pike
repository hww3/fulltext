inherit .BaseClient;

string type="admin";

//!
protected void create(string|void index_url, string authcode)
{
  ::create(index_url, 0, authcode); // we store auth in name field for now.
}


//!
int shutdown(int delay)
{
  return (int)auth_call("shutdown", delay);
}

//!
string grant_access(string index)
{
  return (string)auth_call("grant_access", index);
}

//!
int exists(string index)
{
  return (int)auth_call("exists", index);
}

//!
int revoke_access(string index, string authcode)
{
  return (int)auth_call("revoke_access", index, authcode);
}

//!
int new(string index)
{
  return (int)auth_call("new", index);
}
