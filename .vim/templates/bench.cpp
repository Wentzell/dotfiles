// Cf Carruth cppcon 2015.  https://www.youtube.com/watch?v=nXaxk27zwlk
static void escape(void *p) { asm volatile("" : : "g"(p) : "memory"); }
static void clobber() { asm volatile("" : : : "memory"); }

#include <benchmark/benchmark.h>

const int N = 100;

static void accumulate(benchmark::State &state) {

  int acc;
  for (int i = 0; i < N; ++i) arr[i] += i;
}
BENCHMARK(explicit_loops);

BENCHMARK_MAIN();
