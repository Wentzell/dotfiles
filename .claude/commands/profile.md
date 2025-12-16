Profile the executable or script ${ARGUMENTS}

- Build any compiled code with the CXXFLAGS="-g -gdwarf-4 -fno-omit-frame-pointer -stdlib=libc++ -ffp-contract=fast -march=native"
- If the TRIQS library is required, use the profiled build at `$HOME/opt/triqs_prof`
- Use the `build_prof` directory for the profiling build
- Choose a `PROFILE_NAME` based on the executable or script
- For an executable:
  `PROFILE_COMMAND` executes the executable
  `PROFILE_BINARY` is the executable
- For a Python Script:
  `PROFILE_COMMAND` executes the Python script
  `PROFILE_BINARY` is the compiled Python module used in the script
- Change to the directory where the script or executable is located
- Generate benchmark data using gperftools:
  ```bash
  LD_PRELOAD=$HOME/opt/gperftools/lib/libprofiler.so CPUPROFILE=[PROFILE_NAME].prof [PROFILE_COMMAND]
  ```
- Visualize the profiling graph using the `pprof` executable:
  ```bash
  pprof --svg [PROFILE_BINARY] [PROFILE_NAME].prof > [PROFILE_NAME].prof.svg
  pprof --svg --lines [PROFILE_BINARY] [PROFILE_NAME].prof > [PROFILE_NAME].prof.lines.svg
  ```
