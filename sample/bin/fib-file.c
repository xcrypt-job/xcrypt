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
  int n;
  FILE *fp1, *fp2;
  fp1 = fopen (argv[1], "r");
  if (!fp1) {
    perror ("Failed to open input file");
    exit (1);
  }
  fscanf (fp1, "%d", &n);
  fp2 = fopen (argv[2], "w");
  if (!fp2) {
    perror ("Failed to open output file");
    exit (1);
  }
  fprintf (fp2, "fib(%d)= %d\n", n, fib(n));
  return 0;
}
