inherit Error.Generic;

constant __is_xmlrpc_remote_error = 1;

Protocols.XMLRPC.Fault fault;

static void create(Protocols.XMLRPC.Fault e)
{
  fault = e;
  ::create("Remote Error: " + e->fault_code + "/" + e->fault_string, backtrace()[1..]);
}
