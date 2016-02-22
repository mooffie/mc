#include <stdio.h>

typedef char day_name[10];

day_name week[7] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};

int main()
{
  day_name *ptrw;

  ptrw = week;
  ptrw++;

  printf("%d\n", (int)ptrw - (int)week);

  return 0;
}
