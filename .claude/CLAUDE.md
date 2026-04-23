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
- Test: `ctest --test-dir build -j 16` (always use ctest, never run Python tests directly. Running `python test.py` without the correct PYTHONPATH will silently load the installed system version of the module instead of the build version, producing misleading results. If you must run a Python test manually, prefix with `PYTHONPATH=<project>/build/python:$PYTHONPATH`)
- Clean build: `cmake --build build --clean-first`

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

## Debugging
- For segfaults and memory errors, always use a sanitizer build (ASAN/UBSAN) first — it gives precise error locations vs cryptic crashes or hangs in release builds
- For tracking NaN/Inf origins, use a UBSAN build — UBSAN's float-cast-overflow and other UB checks can pinpoint where NaN is first produced

## DLR (Discrete Lehmann Representation)
- The DLR representation is only valid for Green's-function-like objects that have a spectral (Lehmann) representation. Never apply DLR operations (make_gf_dlr, mesh conversions, evaluation at Matsubara frequencies/imaginary times) to quantities without a spectral representation, such as error bars or uncertainties.

## Code Style
- Strive for expressive and clear code
- Don't compile code by directly invoking the compiler. Always go through the dedicated cmake setup
- Use ctest to run tests
- Tests need to be run from their respective directory, so they can locate any reference files

## Test Reference Files
- Many tests compare results against `.ref.h5` reference files stored in the source `test/` directory
- CMake copies reference files to the build directory at configure time. After updating a `.ref.h5` in the source tree, you must also copy it to the build directory (or reconfigure) for ctest to pick up the change
- Monte Carlo tests with fixed seeds produce deterministic results. Changing the evaluation code path (even if mathematically equivalent) changes floating-point rounding, which causes MC trajectory divergence and requires regenerating reference data
- To regenerate: run the test (it writes `.out.h5`), then copy `.out.h5` over `.ref.h5` in both source and build directories
- Always verify that the regenerated reference gives passing tests before committing
- CRITICAL: Reference files must be committed in the same commit as the code change that caused them to change — never as a separate follow-up commit
- Only regenerate reference files when you understand exactly why the output changed. Document the reason in the commit message (e.g. "mesh type changed from non-symmetrized to symmetrized DLR", "alpha clipping changed MC trajectory for multi-orbital test")
- Before regenerating, verify that only the expected quantities changed and by the expected amount. Unexplained changes indicate a bug, not a need to update refs

## Jupyter Notebook Editing
- NEVER use the Write or Edit tools on .ipynb files -- this corrupts the JSON structure
- For simple cell replacements: use the NotebookEdit tool (operates at cell level, safe)
- For inserting/deleting cells or larger refactors: use jupytext (see below)

### jupytext workflow
- We use jupytext with py:percent format
- Cell boundaries use `# %%` markers; markdown cells use `# %% [markdown]`
- Edit the .py file using standard Edit/Write tools, then convert back to .ipynb
- Convert back (preserving existing outputs): `jupytext --to ipynb --update <file>.py`
- To execute the notebook in place: `jupyter nbconvert --execute --inplace <file>.ipynb`

### If a .ipynb exists but has no paired .py file
Generate the .py file first:
```bash
jupytext --to py:percent <file>.ipynb
```
Then edit the .py file and convert back with `jupytext --to ipynb --update <file>.py`.

### Creating a new notebook
Create a .py file with `# %%` cell markers directly. Convert with:
```bash
jupytext --to ipynb <file>.py
```

## Git Workflow
- Group changes logically into small commits with concise messages
- Feature branches get merged into unstable. We avoid merge commits and instead clean-up the history and rebase
- Pre-authorized to create commits without explicit per-commit confirmation. Still hold off on `push`, `push --force`, amending published commits, destructive resets/checkouts, and any history rewrites on shared branches unless asked

## Build Variants
- Debug: `build_dbg` directory, triqs installed into `~/opt/triqs_dbg`
- Sanitizer: `build_san` directory, triqs installed into `~/opt/triqs_san`
- Profiling: `build_prof` directory, triqs installed into `~/opt/triqs_prof`
