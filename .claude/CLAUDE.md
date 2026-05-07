# Development Context
- Quantum Many-Body Physics
- Scientific Library Development with C++ and Python
- Emphasize Code clarity and maintainability

## Communication
- Don't assume that the user is correct
- Make sure your answers are concise and to the point

## Environment
- `$HOME` (and `~`) is `/mnt/home/wentzell`, the NFS home shared with cluster nodes
- `/home/wentzell` is local disk; `~/Dropbox` is a symlink into it, so `~/Dropbox/Coding` lives on local disk despite the `~` prefix
- Most sources are located in repository directories under `~/Dropbox/Coding`
- Be mindful of NFS traffic: avoid large recursive `find` / `grep` / `rg` sweeps over `~` or other NFS paths. Scope searches to a specific subdirectory, prefer the local-disk Dropbox copy when available, and lean on indexed tools (git grep inside a repo) over filesystem walks

## Software Stack
- LMod modules; default env: `module show devenv9/clang-py3-mkl`
- Extra libraries in `/mnt/home/wentzell/opt`

## Tools
- Compiler: Clang (preferred) or GCC. Build: Ninja (preferred) or Make

## Common Project Structure
- Layout: `c++/`, `test/c++/`, `python/`, `test/python/`, `docs/` (Sphinx + Doxygen)

## Git Workflow
- Feature branches get merged into unstable. We avoid merge commits and instead clean-up the history and rebase
- Pre-authorized to create commits without explicit per-commit confirmation. Still hold off on `push`, `push --force`, amending published commits, destructive resets/checkouts, and any history rewrites on shared branches unless asked

## Additional Instructions
- Don't invoke the compiler directly — always go through cmake
- Run tests from their own directory so reference files resolve

## Python Bindings (clair+c2py)
- Bindings are driven by `C2PY_IGNORE` / `C2PY_RENAME(PyName)` / `C2PY_PROPERTY_GET(py_name)` annotations in `c++/**/*.hpp`, plus per-module `python/.../*.toml` (`package_name`, `namespaces`) and `python/.../*.cpp` (`namespace c2py_module` template-instantiation aliases + `extern template` for free functions). `///` / `/** */` comments become Python docstrings. `*.wrap.cxx` and `*.wrap.hxx` are clair-generated — never hand-edit.

## Common Commands
- Configure: `cmake -S . -B build -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- Configure Install Prefix only if required: `-DCMAKE_INSTALL_PREFIX=~/opt/REPONAME`
- To enable Sanitizer checks configure with `-DASAN=ON -DUBSAN=ON`
- To enable Documentation configure with `-DBuild_Documentation=ON`
- Test: `ctest --test-dir build -j 16` — always use ctest. `python test.py` silently loads the installed module instead of the build version. To run a test manually: `PYTHONPATH=<project>/build/python:$PYTHONPATH python ...`

## Build Variants
- Variants: `build_dbg` → `~/opt/triqs_dbg`; `build_san` → `~/opt/triqs_san`; `build_prof` → `~/opt/triqs_prof`

## Debugging
- Use a sanitizer build (ASAN/UBSAN) for segfaults, memory errors, and NaN/Inf tracking — release builds give cryptic crashes; UBSAN's float-cast-overflow pinpoints where NaN is first produced
- When sanitizer tests fail on code outside the branch's diff scope, run `git diff <base> -- <suspected-paths>` before debugging. Zero diff means the branch can't have caused it — look for stale build artifacts (Python `.cpython-*.so`, regenerated wrap files) or pre-existing bugs on the base branch.

## Test Reference Files
- Tests compare against `.ref.h5` files in `test/`. CMake copies them to the build dir at configure time, so after editing a ref in the source tree, also copy it to build/ (or reconfigure)
- To regenerate: run the test (writes `.out.h5`), copy over `.ref.h5` in both source and build trees, verify the test now passes, and confirm only expected quantities changed by the expected amount — unexplained changes mean a bug, not stale refs
- CRITICAL: commit regenerated refs in the same commit as the code change, with the reason in the message (e.g. "alpha clipping changed MC trajectory for multi-orbital test")

## Jupyter Notebooks
- NEVER use Write/Edit on .ipynb — corrupts JSON. Use NotebookEdit for single-cell edits; use jupytext for inserts/deletes/refactors
- jupytext format: py:percent. Cells: `# %%`; markdown: `# %% [markdown]`
- If no paired .py exists: `jupytext --to py:percent <file>.ipynb`
- Edit the .py with normal tools, then `jupytext --to ipynb --update <file>.py` (preserves outputs)
- Execute in place: `jupyter nbconvert --execute --inplace <file>.ipynb`

## DLR (Discrete Lehmann Representation)
- The DLR representation is only valid for Green's-function-like objects that have a spectral (Lehmann) representation. Never apply DLR operations (make_gf_dlr, mesh conversions, evaluation at Matsubara frequencies/imaginary times) to quantities without a spectral representation, such as error bars or uncertainties.
