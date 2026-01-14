Profile the executable or script ${ARGUMENTS}

## Build Configuration

- Use the `build_prof` directory for profiling builds
- Build with flags: `CXXFLAGS="-g -gdwarf-4 -fno-omit-frame-pointer -stdlib=libc++ -ffp-contract=fast -march=native"`
- If TRIQS is required, use the profiled build at `$HOME/opt/triqs_prof`

## Linking gperftools

**Preferred: Link at build time** (avoids LD_PRELOAD permission issues)

Add to CMakeLists.txt:
```cmake
find_library(PROFILER_LIBRARY profiler)
if(PROFILER_LIBRARY)
  target_link_libraries(${TARGET} ${PROFILER_LIBRARY})
endif()
```

Reconfigure, rebuild, and verify with: `ldd <executable> | grep profiler`

**Alternative: LD_PRELOAD** (may have permission issues)
```bash
module load gperftools  # or use $HOME/opt/gperftools/lib/libprofiler.so
LD_PRELOAD=<path>/libprofiler.so CPUPROFILE=<name>.prof ./<executable>
```

## Profiling Workflow

1. **Run with profiler** (when linked at build time):
   ```bash
   sh -c 'CPUPROFILE=<name>.prof ./<executable>'
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
