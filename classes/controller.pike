import Fins;
import Tools.Logging;

inherit FinsController;

object update;
object admin;
object search;

static void create(Fins.Application a)
{
  ::create(a);
  update = ((program)"update_controller")(a);
  search = ((program)"search_controller")(a);
  admin = ((program)"admin_controller")(a);
}

void index(object id, object response, mixed ... args)
{
  object t = view->get_view("index");
  array i = ({});

  foreach(get_dir(app->index->indexloc);;string d)
  {
werror("adding %O\n", d);
    object r;
    catch(r = app->index->get_reader(d));
    if(!r) continue;
    mapping m = ([]);
    m->name = d;
    m->doccount = r->get_doccount();
    m->maxdoc = r->get_lastdocid();
    i += ({m});
  }

  t->add("indices", i);
  response->set_view(t);
}

void info(object id, object response, mixed ... args)
{
  object r;
  string d = args[0];
  if(!d || !sizeof(d))
    response->not_found(d);
  object t = view->get_view("info");
  catch(r = app->index->get_reader(d));
  if(!r) 
    response->not_found(d);
  mapping i = ([]);

  i->name = d;
  i->doccount = r->get_doccount();
  i->maxdoc = r->get_lastdocid();
  i->avlength = r->get_avlength();
  i->positions = r->has_positions();
  t->add("index", i);
/*
if(id->variables->term)
{
  t->add("termcount", r->get_termfreq(id->variables->term));
  t->add("term", id->variables->term);
}
*/

  response->set_view(t);
}
