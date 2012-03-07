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
