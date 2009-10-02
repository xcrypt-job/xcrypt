#include <stdio.h>
#include <stdlib.h>

int fib (int n)
{
  if (n<=1) return 1;
  else
    return fib (n-1) + fib (n-2);
}

int main (int argc, char** argv)
{
  int n = (argc>1)?(atoi(argv[1])):40;
  printf ("fib(%d)=%d\n", n, fib(n));
  return 0;
}
