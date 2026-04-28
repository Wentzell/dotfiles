---
description: Profile CPU usage with gperftools
argument-hint: <executable|script>
effort: medium
---

Profile ${ARGUMENTS} with gperftools.

## Build

Use `build_prof/` configured with: `-g -gdwarf-4 -fno-omit-frame-pointer -stdlib=libc++ -ffp-contract=fast -march=native`. If TRIQS is needed, source the profiled build at `~/opt/triqs_prof/share/triqs/triqsvars.sh` — otherwise the profile lacks line-level info.

## Capture

Preferred — LD_PRELOAD (no rebuild):
```bash
LD_PRELOAD=~/opt/gperftools/lib/libprofiler.so \
  CPUPROFILE=<name>.prof CPUPROFILE_FREQUENCY=50 ./<executable>
```

For Python+TRIQS use `CPUPROFILE_REALTIME=1 CPUPROFILE_FREQUENCY=10` to avoid signal-related crashes.

Alternative — link at build time:
```cmake
find_library(PROFILER_LIB profiler HINTS $ENV{HOME}/opt/gperftools/lib NO_DEFAULT_PATH)
target_link_libraries(${TARGET} ${PROFILER_LIB})
target_include_directories(${TARGET} PRIVATE $ENV{HOME}/opt/gperftools/include)
```
Verify with `ldd <executable> | grep profiler`.

## Gotchas

- Forking processes (e.g. Google Benchmark) write `<name>.prof_<PID>` — `ls -la *.prof*`.
- Confirm the profile came from the profiled build: `pprof --raw <bin> <prof> | grep "^108:"` should reference `triqs_prof`, not `triqs`.

## Analyze

```bash
pprof --text <bin> <name>.prof | head -40
pprof --text --lines <bin> <name>.prof | head -50

# Isolate a subsystem (regex matches call stack):
pprof --text --focus='<regex>' <bin> <name>.prof | head -40

# SVG callgraph (redirect stderr to keep SVG clean):
pprof --svg --lines [--focus='<regex>'] <bin> <name>.prof 2>/dev/null > <name>.svg
```
