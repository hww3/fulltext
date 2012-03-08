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

void index(object id, object response, mixed args)
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
