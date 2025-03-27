#include<stdio.h>
#include<time.h>
#include<stdlib.h>
#include<omp.h>

// 現在時刻を取得する．精度はナノ秒（ns），返す値の単位は秒（s）
double get_current_time (void) {
  struct timespec tp;
  clock_gettime(CLOCK_REALTIME, &tp);
  return (tp.tv_sec+(double)tp.tv_nsec/1000/1000/1000);
}

long fib_s(long n) {
    if (n < 2) {
        return 1;
    } else {
        return fib_s(n-1) + fib_s(n-2);
    }
}

long fib(long n) {
    long s1, s2;
    if (n < 2) {
        return 1;
    } else if (n<25) {
        return fib_s(n);
    } else {
        #pragma omp task shared(s1) firstprivate (n)
        s1 = fib(n-1);
        #pragma omp task shared(s2) firstprivate (n)
        s2 = fib(n-2);
        #pragma omp taskwait
        return s1+s2;
    }
}

int main (int argc, char** argv) {
  long n, r;
  int nthreads;
  double t1, t2;
  if (argc>=2) { n = atol (argv[1]); }
  else { n = 10; }
  if (argc>=3) { nthreads = atoi (argv[2]); }
  else { nthreads = 8; }

  omp_set_dynamic(0);
  omp_set_num_threads(nthreads);

  t1 = get_current_time();
  #pragma omp parallel shared(r,n)
  {
      #pragma omp single
      r = fib(n);
  }
  t2 = get_current_time();
  printf ("# threads = %d\n", nthreads);
  printf ("fib(%ld) = %ld\n", n, r);  
  printf ("Time: %f\n", t2-t1);
  return 0;
}
