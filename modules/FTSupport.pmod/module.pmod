string make_excerpt(string c)
{
        if(sizeof(c)<500)
          return c;
   int loc = search(c, " ", 499);

        // we don't have a space?
   if(loc == -1)
        {
                c = c[0..499] + "...";
        }
        else
        {
                c = c[..loc] + "...";
        }

        return c;
}


