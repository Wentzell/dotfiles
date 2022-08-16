# Environment & Workflow

## Environment
- Most sources are located in repository directories under `~/Dropbox/Coding`
- Build directories (`build*`) are commonly soft links onto the local disk to keep build files out of Dropbox sync. Never remove a build dir itself (`rm -rf build`) — clear its contents instead (`rm -rf build/*`)
- For searches, prefer the local-disk Dropbox copy and indexed tools (`git grep` in-repo) over filesystem walks
- `curl` command is currently blocked in our company permissions, use alternatives

## Toolchain
- Homebrew installed in `/opt/homebrew` manages all software
- Compiler: Clang (preferred) or GCC. Build: Ninja (preferred) or Make
- Don't invoke the compiler directly — always go through cmake

## Building & Testing
- Layout: `c++/`, `test/c++/`, `python/`, `test/python/`, `docs/` (Sphinx + Doxygen)
- Configure: `cmake -S . -B build -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- Toggles: `-DASAN=ON -DUBSAN=ON` (sanitizers), `-DBuild_Documentation=ON` (docs), `-DCMAKE_INSTALL_PREFIX=~/opt/REPONAME` (install)
- Test: `ctest --test-dir build -j 16` — always use ctest. `python test.py` silently loads the installed module instead of the build version. To run a test manually: `PYTHONPATH=<project>/build/python:$PYTHONPATH python ...`
- Variants: `build_dbg` → `~/opt/triqs_dbg`; `build_san` → `~/opt/triqs_san`; `build_prof` → `~/opt/triqs_prof`

## Code Comments
- Prefer no comment over one that restates the code
- Keep comments short, avoid redundant information like possible failure scenarios
- Never narrate the reasoning that led to the code, that belongs in the commit message

## Debugging
- Use a sanitizer build (ASAN/UBSAN) for segfaults, memory errors, and NaN/Inf tracking — release builds give cryptic crashes; UBSAN's float-cast-overflow pinpoints where NaN is first produced

## Test Reference Files
- Run tests from their own directory so reference files resolve
- Some tests compare against `.ref.h5` files in `test/`. CMake copies them to the build dir at configure time, so after editing a ref in the source tree, also copy it to build/ (or reconfigure)
- To regenerate: run the test (writes `.out.h5`), copy `.out.h5` over `.ref.h5` in both source and build trees, verify pass + diff only expected quantities — anything else is a bug, not stale refs
- CRITICAL: commit regenerated refs in the same commit as the code change, with the reason in the message (e.g. "alpha clipping changed MC trajectory for multi-orbital test")
