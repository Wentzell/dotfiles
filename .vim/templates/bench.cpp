#include <benchmark/benchmark.h>
#include <string>

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

const int N = 100;

static void BM_StringCompare(benchmark::State &state) {
  state.PauseTiming();
  std::string s1(state.range(0), '-');
  std::string s2(state.range(0), '-');
  state.ResumeTiming();
  for (auto _ : state) { benchmark::DoNotOptimize(s1.compare(s2)); }
  state.SetComplexityN(state.range(0));
}
BENCHMARK(BM_StringCompare)->RangeMultiplier(2)->Range(1 << 10, 1 << 18)->Complexity();

BENCHMARK_MAIN();
