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

## Communication
- Give concise answers
- Avoid using emojis
- Check your assumptions
- Ask for clarifications
- Don't assume that the user is correct

## Code Style
- Strive for expressive and clear code
- Don't compile code by directly invoking the compiler. Always go through the dedicated cmake setup
- Use ctest to run tests
- Tests need to be run from their respective directory, so they can locate any reference files

## Git Workflow
- Group changes logically into small commits with concise messages
- Feature branches get merged into unstable. We avoid merge commits and instead clean-up the history and rebase

## Build Variants
- Debug: `build_dbg` directory, triqs installed into `~/opt/triqs_dbg`
- Sanitizer: `build_san` directory, triqs installed into `~/opt/triqs_san`
- Profiling: `build_prof` directory, triqs installed into `~/opt/triqs_prof`
