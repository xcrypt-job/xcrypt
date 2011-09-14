fib-par: cmd-serial-gcc.c fib-gcc.c sendrecv.c sendrecv.h sock.c sock.h worker-gcc.c
	gcc -O2 -lm -lpthread worker-gcc.c cmd-serial-gcc.c sendrecv.c sock.c fib-gcc.c -o fib-par
