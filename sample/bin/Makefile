subdirs = fib-par
.PHONY: all $(subdirs)

all: fib fib-stdo fib-file fib-par

fib: fib.c
	gcc -O2 fib.c -o fib
fib-stdo: fib-stdo.c
	gcc -O2 fib-stdo.c -o fib-stdo
fib-file: fib-file.c
	gcc -O2 fib-file.c -o fib-file

fib-par:
	$(MAKE) -C fib-par