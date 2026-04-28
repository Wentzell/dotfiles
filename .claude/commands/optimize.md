---
description: Iteratively optimize performance using profiling
argument-hint: <target>
effort: high
---

Iteratively optimize ${ARGUMENTS} using profiling data to find and address bottlenecks.

## Profilers

- **gperftools** — full-program profiling, finds unexpected hotspots
- **Google Benchmark** — microbenchmarks for iterating on a specific function
- Combine them: gperftools to localize, microbench to iterate

See `/profile` for gperftools setup, env vars, and analysis commands.

## Phase 1: Setup

1. Identify the executable/test that exercises the code in ${ARGUMENTS}; note workload-size parameters.
2. Confirm `build_prof/` is configured and that the binary picks up libprofiler (LD_PRELOAD or `ldd | grep profiler`).
3. Calibrate workload to ~1 minute runtime — meaningful sampling without excessive wait. Don't commit the parameter changes.
4. Optional: add a Google Benchmark microbenchmark under `benchmarks/` for the targeted hotspot, parametrized over problem size / tolerance.

## Phase 2: Baseline

1. Run the benchmark 2–3× to confirm timing is stable; record baseline (e.g. "46.4s, 700k samples").
2. Capture an initial profile (see `/profile`). Analyze with `pprof --text` and generate SVGs.
3. List functions consuming >5% flat; focus on the hottest code path first. Read and understand it before changing anything.

## Phase 3: Optimization cycle

For each attempt:

1. **Implement** one focused change. Common patterns: branch elimination in inner loops, hoisting invariants, raw `.data()` pointers to skip bounds checks, caching frequently-accessed values, precomputing divisions, tolerance tuning for numerical algorithms.
2. **Verify**: `cmake --build build_prof` then `ctest --test-dir build_prof -R <relevant> -j 16`. Tests must pass before measuring.
3. **Measure**: re-profile with the same workload; compute `(old - new) / old * 100%`. For microbenchmarks: `--benchmark_repetitions=5 --benchmark_report_aggregates_only=true`.
4. **Decide**:
   - >3% gain → commit with descriptive message, continue
   - regression → revert immediately
   - <3% → revert unless code is clearly cleaner

## Phase 4: Wrap-up

1. Document final speedup and what worked vs. what didn't.
2. Restore any temporary workload parameters.
3. Generate final SVGs and note remaining hotspots for future work.
4. Optional: run `/simpl` on the touched files to undo any clarity loss.

## Stop when

- Expected next gain <5%
- Hotspot is memory-bound (random access / cache misses)
- Algorithmic limit reached
- Hotspot is in third-party code you don't control
