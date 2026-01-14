Explore and iteratively apply performance optimizations for ${ARGUMENTS}

This command guides an iterative optimization process using profiling data to identify and address performance bottlenecks.

## Phase 1: Setup

1. **Identify benchmark case(s)** from ${ARGUMENTS}
   - Locate the executable or test that exercises the code to optimize
   - Note any parameters that control workload size

2. **Configure profiling build** (see /profile for details)
   - Ensure `build_prof` directory exists with proper flags
   - Verify gperftools is linked: `ldd <executable> | grep profiler`
   - If not linked, add CMake snippet and reconfigure

3. **Calibrate workload**
   - Time the benchmark: `time ./<executable>`
   - Adjust parameters so runtime is ~1 minute (meaningful sampling without excessive wait)
   - Document the parameter changes (don't commit them)

## Phase 2: Baseline

1. **Establish baseline timing**
   - Run benchmark 2-3 times to confirm consistent timing
   - Record baseline: e.g., "Baseline: 46.4s with 700k samples"

2. **Generate initial profile**
   - Run: `sh -c 'CPUPROFILE=<name>.prof ./<executable>'`
   - Analyze: `pprof --text <executable> <name>.prof | head -40`
   - Generate SVGs for visualization

3. **Identify optimization targets**
   - List functions consuming >5% of total time
   - Focus on the hottest code path first (highest flat%)
   - Read and understand the hot code before optimizing

## Phase 3: Optimization Cycle

Repeat for each optimization attempt:

### 3.1 Implement
- Make ONE focused change at a time
- Common patterns:
  - **Branch elimination**: Restructure loops to avoid conditionals in hot paths
  - **Hoist invariants**: Move repeated computations outside inner loops
  - **Raw pointers**: Use `.data()` to avoid bounds checking in tight loops
  - **Cache values**: Store frequently accessed array elements in locals
  - **Reduce operations**: Precompute divisions, combine redundant lookups

### 3.2 Verify
- **Run tests**: `ctest --test-dir build_prof -R <relevant_tests>`
- Tests MUST pass before measuring performance
- If tests fail, fix the bug or revert

### 3.3 Measure
- Re-run profiler with same workload
- Compare timing to baseline/previous iteration
- Compute improvement: `(old - new) / old * 100%`

### 3.4 Decide
- **If improvement (>3%)**: Commit with descriptive message, continue
- **If regression**: Revert immediately, document what didn't work
- **If neutral (<3%)**: Consider reverting for simplicity unless code is clearer

## Phase 4: Wrap-up

1. **Document results**
   - Total speedup achieved: e.g., "19% faster (46s -> 38s)"
   - List optimizations that worked
   - Note approaches that were tried but didn't help

2. **Review code clarity**
   - Ensure optimized code remains readable
   - Add comments explaining non-obvious optimizations
   - Consider simplifying variable names if code became verbose

3. **Generate final profile**
   - Create SVGs showing the optimized profile
   - Identify remaining hotspots for future work

4. **Restore benchmark parameters**
   - Revert any temporary parameter changes made for profiling
   - Commit only the actual optimizations

## Stopping Criteria

Stop optimizing when:
- **Diminishing returns**: Expected improvement <5%
- **Memory-bound**: Hotspot is random memory access (cache misses)
- **Algorithmic limit**: Complexity is inherent (e.g., O(3^n) recursion)
- **External code**: Hotspot is in library code you don't control

## Example Session Log

```
Baseline: 46.4s
  calc_weights: 58% (27s)

Optimization 1: Eliminate branch in inner loop
  Tests: PASS
  Timing: 38.2s (-18%)
  Committed: a7c0469

Optimization 2: Use lm[lower_bits] instead of lm[T]
  Tests: PASS
  Timing: 38.1s (no improvement)
  Reverted: mathematical equivalence, no cache benefit

Final: 38.2s (18% improvement)
Remaining hotspot: calc_weights at 50% - memory-bound
```
