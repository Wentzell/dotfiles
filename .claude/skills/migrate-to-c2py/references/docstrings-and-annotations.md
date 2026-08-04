# Phase 3 detail — C++ header docstrings & annotations

Edit the headers the descriptor wrapped. Two jobs in the same files: migrate docstrings (do this
**first**), then add annotations.

### 3a — Migrate docstrings into the headers (critical for hand-written descriptors)

c2py takes docstrings **only** from the C++ `///` / `/** … */` comments — the `doc=` strings in
`*_desc.py` are dropped the moment the descriptor is deleted. `clair-c2py` then **translates the
doxygen into the RST/NumPy Python docstring** (`\f$…\f$`→`:math:`, `\f[…\f]`→`.. math::`,
`@param`/`@return`→NumPy `Parameters`/`Returns` with the C++ arg types injected). So the headers
must be **clean doxygen** before generating — hybrid RST/`$…$` markup left in a header does *not*
round-trip. For **hand-written** descriptors
(tprf), the descriptor is frequently the authoritative or richer copy, so for **every** entity
flagged in Phase 0 you must, *before* generating bindings:
1. **Reconcile**: if the descriptor's `doc=` text is richer/more correct than the header comment (or
   the header has none), move that text into the C++ comment — `///` (or `/** */`) on the
   class/method/free-function/enum; the module `doc=`/`--moduledoc` becomes the `.toml`
   `documentation` field. Even when an auto-generated descriptor's docs already round-tripped into
   the header, the header copy is often a **hybrid** still carrying RST/cpp2py syntax — fix it too.
2. **Convert to doxygen style** (TRIQS uses `\f$…\f$`/`\f[…\f]`, `@param`/`@return`; see the
   `app4triqs.hpp` port for the reference style):
   | cpp2py / RST in `doc=` (or hybrid header) | doxygen |
   |---|---|
   | inline math `:math:`x`` or bare `$x$` | `\f$ x \f$` |
   | display block `.. math::` (also the `.. math ::` space variant!) ⏎ `  x` | `\f[ x \f]` |
   | NumPy block `Parameters` ⏎ `----------` ⏎ `name` ⏎ `   desc` | `@param name desc` |
   | NumPy block `Returns` ⏎ `-------` ⏎ `out` ⏎ `   desc` | `@return desc` |
   | `@head …` / `@tail …` | `@brief …` / `@details …` |
   | `@include foo.hpp` | drop (cpp2py-era directive) |
3. Enum docs go on the C++ enum (its `///`), not in the toml; per-overload docs go on each
   overload's declaration.

Do this as its **own commit** ("Migrate Python docstrings into headers / doxygen style") *before*
the port commit, so the doc reflow is reviewable separately from the binding change and the
regenerated `*.wrap.cxx` docstrings trace to a clean source.

**Beware leftover RST**: any RST directive the conversion misses (the `.. math ::` space variant is
the classic trap — a naive `\.\. math::` regex skips it) does *not* just render literally — clair-c2py
parses the stray block as doxygen and **strips the LaTeX commands** (`\frac`, `\epsilon`, … vanish),
silently mangling the math. Grep `\.\.\s*math\s*::` and `:math:` (space-tolerant) and confirm **zero**
residuals. **Verify, don't assume**: after generating, diff the compiled modules' `__doc__` against
the old `_desc.py` `doc=` strings (a small AST harness over the descriptors works well) and eyeball
that math/params/returns survived — auto-generated descriptors usually round-trip, but hand-edited
ones (and headers that diverged from them) carry content the header never had.

### 3b — Annotations

The annotation macros live in `<triqs/utility/macros.hpp>` — add the include where missing.

- `CPP2PY_IGNORE` → **`C2PY_IGNORE`** (rename). Keep it on `serialize`/`deserialize`/
  `h5_read_construct`. Note `hdf5_format()` no longer needs ignoring in c2py — drop it there.
- **`CPP2PY_ARG_AS_DICT` → delete it.** c2py auto-converts aggregate param structs to/from dict
  given a by-value `params_t const &` argument; no annotation needed (but see Phase 4).
- **`C2PY_PROPERTY_GET(py_name)`** on each getter the descriptor exposed as a property /
  `read_only` member, e.g. `C2PY_PROPERTY_GET(performance_analysis) histo_map_t get_performance_analysis() const`.
  (`C2PY_PROPERTY_SET` exists for setters.)
- **`C2PY_RENAME(PyName)`** on a class whose descriptor `py_type` differed from the C++ name, e.g.
  `class C2PY_RENAME(MeshImFreq) imfreq`.
- **Return concrete values, not references/auto.** c2py wraps the *declared* return type, so getters
  must return by value with an explicit type:
  - `many_body_op_t const &h_loc() const` → `many_body_op_t h_loc() const`
  - `auto const &last_configuration() const` → `std::optional<configuration> last_configuration() const`
- **Overload / default-arg ambiguity**: if a single C++ overload set is ambiguous to wrap, expose
  one and mark the rest `C2PY_IGNORE` (cthyb: keep `configuration(double beta, long id = 0)`, tag
  the 3-arg `configuration(double, long, oplist_t)` overload `C2PY_IGNORE`).
