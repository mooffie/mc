/*
 * My first C program.
 */
#include <stdio.h>

char *week[] = {"Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"};

int main()
{
  char **ptrw;

  ptrw = week;
  ptrw++;

  printf("%d\n", (int)ptrw - (int)week);
}
