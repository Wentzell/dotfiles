# Development Context
- Scientific Software with C++ and Python
- Quantum Many-Body Physics

## Common Commands
- Configure: `cmake -S . -B build -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- Configure Install Prefix only if required: `-DCMAKE_INSTALL_PREFIX=~/opt/REPONAME`
- To enable Sanitizer checks configure with `-DASAN=ON -DUBSAN=ON`
- To enable Documentation configure with `-DBuild_Documentation=ON`
- Build: `cmake --build build`
- Install: `cmake --install build`
- Test: `ctest --test-dir build -j 16`
- Clean: `rm -rf build/*`

## Common Project Structure
- C++ sources and headers: `c++/`
- C++ Tests in `test/c++/`
- Python sources and bindings: `python/`
- Python Tests in `test/python/`
- Documentation using Sphinx and Doxygen: `docs/`

## Software Stack
- LMod Environment Modules
- List Modules: `module list`
- Available Modules: `module avail`
- Default Environment Information: `module show devenv9/clang-py3-mkl`
- Some additional libraries are installed in the /mnt/home/wentzell/opt directory

## Tools
- Explore Directory Structure: `tree -d`
- Compiler: Clang (preferred) or GCC
- Build: Ninja (preferred) or Make

## Environment
- The HOME environment variable as well as ~ point to /mnt/home/wentzell which is the network-file-system home directory shared with the cluster nodes
- Most sources are located in repository directories in the Dropbox folder /home/wentzell/Dropbox/Coding on the local disk

## General
- Do not add 'Generated with Claude Code' to commit messages
- Add claude as a co-author
- Give concise answers
- Check your assumptions
- Ask for clarifications
- Group changes logically into small commits with concise messages
- Avoid using emojis
- Don't assume that the user is correct
- Strive for expressive and clear code
- Tests need to be run from their respective directory, so they can locate any reference files
- Use ctest to run tests
- Feature branches get merged into unstable. We avoid merge commits and instead clean-up the history and rebase
- Debug builds use the build_dbg directory
- Debug builds of triqs are installed into ~/opt/triqs_dbg
- Sanitizer builds use the build_san directory
- Sanitized builds of triqs are installed into ~/opt/triqs_san
- Profiling builds the build_prof
- Profiling builds of triqs are installed into ~/opt/triqs_prof
- Profiling builds should use CXXFLAGS="-g -gdwarf-4 -fno-omit-frame-pointer -stdlib=libc++ -ffp-contract=fast -march=native"
- Don't compile code by directly invoking the compiler. Always go through the dedicated cmake setup
