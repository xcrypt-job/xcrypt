CC=gcc
CC_MIC=icc

.PHONY: clean

fib-par: fib-omp.c
	$(CC) -O2 -fopenmp $< -o $@

# Generate execution file for Xeon Phi in camellia system, ACCMS, Kyoto University (2014-)
# Execute "make fib-par-mic" after "module load PrgEnv-knc"
# http://web.kudpc.kyoto-u.ac.jp/manual/ja/compiler/intel#xeonphi_native
fib-par-mic: fib-omp.c
	$(CC_MIC) -mmic -fopenmp -O2 $< -o $@

clean:
	rm -f fib-par fib-par-mic
