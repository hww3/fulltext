import Tools.Logging;

//! used for internal pike converters
  class PikeFilter(function convert)
  {

  }

//! a filter for programs that act as filters (read on stdin and write the
//! converted data on stdout.
  class Filter(string command)
  {

    //!
    string convert(string data)
    {
       string ret="";
       object i=Stdio.File();
       object o=Stdio.File();
       object e=Stdio.File();
       array args=command/" ";

       object p=Process.create_process(args, (["stdin": i->pipe(), "stdout": o->pipe(), "stderr":
         e->pipe()]));

       i->write(data);
       i->close();

       mixed r;
       do
       {
         r=o->read(1024, 1);
         if(sizeof(r)>0)
           ret+=r;
         else break;
       }
       while(1);
        Log.debug(e->read(1024,1));
       return ret;
    }
  }

//! this is a filter for programs that do not act as filters (they read a
//!   file and write converted output on stdout.
  class Converter(string command, string tempdir)
  {
    int i=0;

    //!
    string convert(string data)
    {
       string ret="";
       i++;
       string t=MIME.encode_base64(Crypto.MD5()->update(data + i)->update((string)time())->digest());

       t=(string)hash(t);

       string tempfile=combine_path(tempdir, t);

       Stdio.write_file(tempfile, data);

       if(file_stat(tempfile))
       {
       string ncommand=(command/"%f")*(string)tempfile;
       array args=ncommand/" ";
         object o=Stdio.File();
         object e=Stdio.File();
         object p=Process.create_process(args, (["stdout": o->pipe(), "stderr": e->pipe()]));


         mixed r;
         do
         {
           r=o->read(1024, 1);
           if(sizeof(r)>0)
             ret+=r;
           else break;
          }
         while(1);
         Log.debug(e->read(1024,1));
         do
         {
           p->wait();
         }
         while(p && p->status()==0);

       }

       if(file_stat(tempfile))
       {
         rm(tempfile);
       }
       tempfile="";
       return ret;
    }
  }
