#include <benchmark/benchmark.h>

static void BM_test(benchmark::State &state) {
  for (auto _ : state) {
    int x = 0;
    for (int i = 0; i < 64; ++i) { benchmark::DoNotOptimize(x += i); }
  }
}
BENCHMARK(BM_test);

static void BM_vector_push_back(benchmark::State &state) {
  for (auto _ : state) {
    std::vector<int> v;
    v.reserve(1);
    benchmark::DoNotOptimize(v.data()); // Allow v.data() to be clobbered.
    v.push_back(42);
    benchmark::ClobberMemory(); // Force 42 to be written to memory.
  }
}
BENCHMARK(BM_vector_push_back);

BENCHMARK_MAIN();
