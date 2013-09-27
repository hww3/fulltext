//!
string title;

//! read-only, set by index
int docid;

//! read-only, set by index
string uuid;

//!
string handle;

//!
string excerpt;

//!
Calendar.YMD date;

//!
string misc;

//! read-only, set by index
float score;

//! read-only, set by index
string index;

//!
array(string) keywords;

//!
string mimetype;

//!
string content;

//!
protected void create(void|mapping map)
{
  if(map)
  {
    foreach(map; string ind; mixed val)
    {
      advise(ind, val);
    }
  }
}

//!
void advise(string name, mixed value)
{
  if(has_index(this, name) && !this[name])
    this[name] = value;
}
