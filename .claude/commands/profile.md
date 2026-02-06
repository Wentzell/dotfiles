---
description: Profile CPU usage with gperftools
argument-hint: <executable|script>
---

Profile the executable or script ${ARGUMENTS}

## Build Configuration

- Use the `build_prof` directory for profiling builds
- Build with flags: `CXXFLAGS="-g -gdwarf-4 -fno-omit-frame-pointer -stdlib=libc++ -ffp-contract=fast -march=native"`
- If TRIQS is required, use the profiled build at `$HOME/opt/triqs_prof`

## gperftools Setup

Use the local gperftools installation at `~/opt/gperftools`.

**Preferred: LD_PRELOAD** (simplest, no rebuild required)
```bash
LD_PRELOAD=~/opt/gperftools/lib/libprofiler.so CPUPROFILE=<name>.prof CPUPROFILE_FREQUENCY=50 ./<executable>
```

**For Python scripts using TRIQS** (must use triqs_prof for line-level info):
```bash
source ~/opt/triqs_prof/share/triqs/triqsvars.sh
LD_PRELOAD=~/opt/gperftools/lib/libprofiler.so \
  CPUPROFILE=<name>.prof CPUPROFILE_FREQUENCY=10 CPUPROFILE_REALTIME=1 \
  python <script>
```

**Alternative: Link at build time**

Add to CMakeLists.txt:
```cmake
find_library(PROFILER_LIB profiler HINTS $ENV{HOME}/opt/gperftools/lib NO_DEFAULT_PATH)
set(PROFILER_INCLUDE $ENV{HOME}/opt/gperftools/include)
if(PROFILER_LIB)
  target_link_libraries(${TARGET} ${PROFILER_LIB})
  target_include_directories(${TARGET} PRIVATE ${PROFILER_INCLUDE})
endif()
```

Reconfigure, rebuild, and verify with: `ldd <executable> | grep profiler`

## Important Notes

- **Signal issues**: Use `CPUPROFILE_FREQUENCY=50` (or lower) to avoid conflicts with debugging signals. For Python scripts, use `CPUPROFILE_REALTIME=1` and `CPUPROFILE_FREQUENCY=10` to avoid crashes
- **TRIQS environment**: When profiling Python scripts that use TRIQS, you MUST source `~/opt/triqs_prof/share/triqs/triqsvars.sh` to load the profiled build. Otherwise, the profile will be captured from the non-profiled build and will lack line-level debug information
- **Forking processes**: When the process forks (e.g., Google Benchmark), the profile may be written to `<name>.prof_<PID>` instead of `<name>.prof`. Check for these files: `ls -la *.prof*`
- **Verify correct binary**: Check `pprof --raw <binary> <profile> | grep "^108:"` to confirm the profile was captured from the profiled build (paths should point to `triqs_prof`, not `triqs`)

## Profiling Workflow

1. **Run with profiler**:
   ```bash
   CPUPROFILE=<name>.prof CPUPROFILE_FREQUENCY=50 ./<executable>
   # Check for output files (may have PID suffix if process forked)
   ls -la *.prof*
   ```

2. **Text analysis** (quick hotspot identification):
   ```bash
   pprof --text <executable> <name>.prof | head -40
   pprof --text --lines <executable> <name>.prof | head -50
   ```

3. **Generate visualizations** (redirect stderr to keep SVG clean):
   ```bash
   pprof --svg <executable> <name>.prof 2>/dev/null > <name>.prof.svg
   pprof --svg --lines <executable> <name>.prof 2>/dev/null > <name>.prof.lines.svg
   ```
