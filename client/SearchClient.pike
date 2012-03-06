inherit .BaseClient;

string type="search";

Protocols.XMLRPC.Client c;

//! Search the index looking for records whose content matches query.
//!
//! @returns
//!  an array containing zero or more mappings, one for each match
//!  in the index.
array search(string query, int|void limit, int|void start)
{
  return advanced_search(query, "contents", limit, start);
}

//! Search a specified field in index for matches on query.
//!
//! @returns
//!  an array containing zero or more mappings, one for each match
//!  in the index.
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

//! Search the index looking for records whose content matches query with
//! automatic spelling correction.
//!
//! @returns
//!  A mapping containg up to 2 elements: "results" with the search
//!  results of the current query and optionally "corrected_query",
//!  which suggests a query that my return more accurate results.
//!  
//!  In either case, results will always be returned, though it may 
//!  not contain any data (if the query was so incorrect that no results
//!  matched, for example).
array search_with_corrections(string query, int|void limit, int|void start)
{
  return advanced_search_with_corrections(query, "contents", limit, start);
}

//! Search a specified field in index for matches on query with 
//! automatic spelling correction.
//!
//! @returns
//!  A mapping containg up to 2 elements: "results" with the search
//!  results of the current query and optionally "corrected_query",
//!  which suggests a query that my return more accurate results.
//!  
//!  In either case, results will always be returned, though it may 
//!  not contain any data (if the query was so incorrect that no results
//!  matched, for example).
array advanced_search_with_corrections(string query, string search_field, int|void limit, int|void start)
{
  if(!c) c = get_client();
  // for some reason, the logical order of used arguments is reversed.
  mixed r = c["search_with_corrections"](name, query, search_field, limit||25, start||0);
  
  if(objectp(r))
    throw(.RemoteError(r));

  if(r[0] && !sizeof(r[0])) return ({});
  else return r[0];
}

mapping fetch(int document_id)
{
    if(!c) c = get_client();
  // for some reason, the logical order of used arguments is reversed.
  mixed r = c["fetch"](name, document_id);

  if(objectp(r))
    throw(.RemoteError(r));

  return r[0];
}
