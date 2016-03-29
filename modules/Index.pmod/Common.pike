string indexloc;

protected string make_indexloc(string index, int|void force)
{
  string loc;

  index = replace(index, "/", "_");

  loc = Stdio.append_path(indexloc, index);

  if(!file_stat(loc)) // the requested index directory doesn't exist.
  {
    if(!force)
    {
      throw(Error.Generic("index " + index + " does not exist.\n"));
    }
     
    else // we're forcing the creation.
    {
       mkdir(loc);
    }
  }  
   
  return loc;
}
