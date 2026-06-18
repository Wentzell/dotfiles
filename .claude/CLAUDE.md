# General Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. They bias toward caution over speed; for trivial tasks, use judgment. Provide concise, focused responses — skip non-essential context, keep examples minimal.

## Development Context
- Quantum Many-Body Physics
- Scientific Library Development with C++ and Python
- Emphasize code clarity and maintainability

## Think Before Coding
**Don't assume. Don't hide confusion. Surface tradeoffs.**
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Don't assume the user is correct; push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## Simplicity First
**Minimum code that solves the problem. Nothing speculative.**
- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## Surgical Changes
**Touch only what you must. Clean up only your own mess.**
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.
- Remove imports/variables/functions that YOUR changes made unused; don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

## Goal-Driven Execution
**Define success criteria. Loop until verified.**
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan with a verify check per step. Strong success criteria let you loop independently; weak criteria ("make it work") require constant clarification.

---

# Environment & Workflow

## Environment
- `$HOME` (and `~`) is `/mnt/home/wentzell`, the NFS home shared with cluster nodes
- `/home/wentzell` is local disk; `~/Dropbox` is a symlink into it, so `~/Dropbox/Coding` lives on local disk despite the `~` prefix
- Most sources are located in repository directories under `~/Dropbox/Coding`
- Build directories (`build*`) are commonly soft links onto the local disk to keep build files out of Dropbox sync. Never remove a build dir itself (`rm -rf build`) — clear its contents instead (`rm -rf build/*`)
- NFS caution: avoid recursive `find` / `grep` / `rg` / `bfs` sweeps over `/`, `/mnt/home`, `/mnt/ceph`, or `~`. Scope to a specific subdirectory, prefer the local-disk Dropbox copy, and lean on indexed tools (git grep inside a repo) over filesystem walks.

## Toolchain
- LMod modules; default env: `module show devenv9/clang-py3-mkl`
- Extra libraries in `/mnt/home/wentzell/opt`
- Compiler: Clang (preferred) or GCC. Build: Ninja (preferred) or Make
- Don't invoke the compiler directly — always go through cmake

## Hardware
- Workstation: 16 physical cores, 500 GB RAM — don't oversubscribe with too many parallel builds
- Genoa compute nodes (AMD EPYC Zen 4): 96 cores, ~1.5 TB RAM, Slurm constraint `-C genoa`; cross-compile with `-march=znver4`

## Common Project Structure
- Layout: `c++/`, `test/c++/`, `python/`, `test/python/`, `docs/` (Sphinx + Doxygen)

## Git Workflow
- Feature branches get merged into unstable. We avoid merge commits and instead clean-up the history and rebase
- Pre-authorized to create commits without explicit per-commit confirmation. Still hold off on `push`, `push --force`, amending published commits, destructive resets/checkouts, and any history rewrites on shared branches unless asked

## Python Bindings (clair+c2py)
- Annotations in `c++/**/*.hpp`: `C2PY_IGNORE` / `C2PY_RENAME(PyName)` / `C2PY_PROPERTY_GET(py_name)`
- Per-module config: `python/.../*.toml` (`package_name`, `namespaces`) + `python/.../*.cpp` (`namespace c2py_module` template-instantiation aliases + `extern template` for free functions)
- `///` / `/** */` comments become Python docstrings
- `*.wrap.cxx` / `*.wrap.hxx` are clair-generated — never hand-edit

## Common Commands
- Configure: `cmake -S . -B build -GNinja -DCMAKE_EXPORT_COMPILE_COMMANDS=ON`
- Toggles: `-DASAN=ON -DUBSAN=ON` (sanitizers), `-DBuild_Documentation=ON` (docs), `-DCMAKE_INSTALL_PREFIX=~/opt/REPONAME` (install)
- Test: `ctest --test-dir build -j 16` — always use ctest. `python test.py` silently loads the installed module instead of the build version. To run a test manually: `PYTHONPATH=<project>/build/python:$PYTHONPATH python ...`

## Build Variants
- `build_dbg` → `~/opt/triqs_dbg`; `build_san` → `~/opt/triqs_san`; `build_prof` → `~/opt/triqs_prof`; `build_genoa` → `~/opt/triqs_genoa` (cross-compiled `-march=znver4` for Genoa nodes)

## Debugging
- Use a sanitizer build (ASAN/UBSAN) for segfaults, memory errors, and NaN/Inf tracking — release builds give cryptic crashes; UBSAN's float-cast-overflow pinpoints where NaN is first produced
- When sanitizer tests fail on code outside the branch's diff scope, run `git diff <base> -- <suspected-paths>` first — zero diff means the branch can't have caused it
- In that case, look for stale build artifacts (Python `.cpython-*.so`, regenerated wrap files) or pre-existing bugs on the base branch

## Test Reference Files
- Run tests from their own directory so reference files resolve
- Tests compare against `.ref.h5` files in `test/`. CMake copies them to the build dir at configure time, so after editing a ref in the source tree, also copy it to build/ (or reconfigure)
- To regenerate: run the test (writes `.out.h5`), copy `.out.h5` over `.ref.h5` in both source and build trees, verify pass + diff only expected quantities — anything else is a bug, not stale refs
- CRITICAL: commit regenerated refs in the same commit as the code change, with the reason in the message (e.g. "alpha clipping changed MC trajectory for multi-orbital test")

## Jupyter Notebooks
- NEVER use Write/Edit on .ipynb — corrupts JSON. Use NotebookEdit for single-cell edits; use jupytext for inserts/deletes/refactors
- jupytext format: py:percent. Cells: `# %%`; markdown: `# %% [markdown]`
- If no paired .py exists: `jupytext --to py:percent <file>.ipynb`
- Edit the .py with normal tools, then `jupytext --to ipynb --update <file>.py` (preserves outputs)
- Execute in place: `jupyter nbconvert --execute --inplace <file>.ipynb`
- nbconvert 7.x / nbclient no longer coalesce stream outputs by default → per-line stdout flushes (e.g. TRIQS `mpi.report`) become many `stream` blocks per cell, producing noisy diffs. Fix with `jupyter nbconvert --coalesce-streams --inplace <file>.ipynb` (without `--execute` to coalesce existing outputs in place)
- Re-executing injects environment-specific meta noise: per-cell `execution` timestamps (`iopub.*`), a `language_info.version` bump, and volatile run-time lines. Strip/reset these before committing so the diff is only the substantive change

## DLR (Discrete Lehmann Representation)
- The DLR representation is only valid for Green's-function-like objects that have a spectral (Lehmann) representation. Never apply DLR operations (make_gf_dlr, mesh conversions, evaluation at Matsubara frequencies/imaginary times) to quantities without a spectral representation, such as error bars or uncertainties.
