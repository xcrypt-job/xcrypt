fib-par: cmd-serial-gcc.c fib-gcc.c sendrecv.c sendrecv.h sock.c sock.h worker-gcc.c
	gcc -O2 worker-gcc.c cmd-serial-gcc.c sendrecv.c sock.c fib-gcc.c -o fib-par -lm -lpthread

# Generate execution file for Xeon Phi in camellia system, ACCMS, Kyoto University (2014-)
# Execute "make fib-par-mic" after "module load PrgEnv-knc"
# http://web.kudpc.kyoto-u.ac.jp/manual/ja/compiler/intel#xeonphi_native
fib-par-mic: cmd-serial-gcc.c fib-gcc.c sendrecv.c sendrecv.h sock.c sock.h worker-gcc.c
	cc -mmic -O2 worker-gcc.c cmd-serial-gcc.c sendrecv.c sock.c fib-gcc.c -o fib-par-mic -lm -lpthread
