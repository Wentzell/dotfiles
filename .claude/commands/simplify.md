# Simplify ${ARGUMENTS}

Iteratively simplify code while maintaining functionality.

## Prerequisites

1. Verify clean working directory:
   ```bash
   git status --porcelain
   ```
   If dirty, ask user to commit or stash changes first.

2. Parse target: `${ARGUMENTS}` specifies the file, directory, or scope to simplify.

3. Assess scope:
   - **Single file**: Proceed directly
   - **Small directory** (< 10 files): Read all relevant files
   - **Large directory**: Ask user to prioritize specific files or patterns

## Simplification Principles

Follow these TRIQS project coding practices:

- **Clarity over cleverness**: Code should be self-explanatory
- **Use modern C++ idioms**: Prefer C++20/23 features (concepts, ranges, structured bindings) over older patterns (SFINAE, raw loops)
- **Concise but not cryptic**: Remove unnecessary verbosity without sacrificing readability
- **Consistent style**: Match existing codebase conventions
- **No functional changes**: Simplifications must preserve behavior exactly

### Good Simplifications

- Replace `std::enable_if_t` SFINAE with C++20 concepts
- Use `auto` for obvious types in variable declarations
- Replace manual loops with range-based algorithms
- Simplify boolean expressions
- Remove redundant includes, typedefs, or forward declarations
- Consolidate duplicate code into helper functions
- Use structured bindings for tuple/pair unpacking
- Replace `nullptr` checks with `std::optional` where appropriate

### Avoid

- Changing public API signatures
- Altering behavior, even edge cases
- Adding new features under the guise of simplification
- Over-abstracting one-time operations
- Removing comments that explain non-obvious logic
- Simplifying code that already uses modern idioms

## Workflow

### Step 1: Exploration

Thoroughly explore the target to identify simplification opportunities:

1. **For directories**: Read all relevant source files (headers, implementation files)
2. **For files**: Read the entire file and understand its structure
3. **Check existing patterns**: Note what modern idioms are already in use to avoid redundant changes

Focus on finding:
- SFINAE patterns (`std::enable_if_t`, `std::void_t`) that could use concepts
- Verbose code that could use modern C++ features
- Duplicate or redundant code
- Overly complex conditionals or loops

Create a prioritized list of specific simplifications with:
- File path and line numbers
- Current code snippet
- Proposed simplification
- Rationale

**If no opportunities found**: Report "Code already uses modern idioms - no simplification needed" and stop. This is a valid, positive outcome.

### Step 2: Review and Select

Review the proposed simplifications:

1. **Filter out** any that:
   - Might change behavior
   - Apply to code already using modern idioms
   - Would require changing public APIs

2. **Prioritize** by:
   - Impact (clarity improvement)
   - Risk (lower risk first)
   - Locality (changes in one file preferred)

3. **Group** related changes that should be committed together

4. **Present to user** if changes affect more than 3 files or touch any public APIs

### Step 3: Implementation

For each approved simplification:

1. Read the target file (if not already read)
2. Apply the simplification using Edit tool
3. Verify the change is syntactically correct

### Step 4: Testing

Run tests to verify no regressions:
```bash
cmake --build build_mac
ctest --test-dir build_mac -j 16
```

**If tests cannot be run** (missing dependencies, build not configured):
- Document this limitation in the commit message
- Limit to ONE simplification per iteration
- Only make changes that are provably equivalent
- Complete the verification checklist below

**Verification Checklist** (when tests unavailable):
- [ ] No change to public API signatures
- [ ] Constraint semantics are identical (not just similar)
- [ ] All uses of replaced patterns are updated consistently
- [ ] No new dependencies introduced

If tests fail:
- Revert the change: `git checkout -- <file>`
- Report the failure and skip this simplification

### Step 5: Commit

Create a focused commit for the simplification:
```bash
git add <files>
git commit -m "<concise description>

Co-Authored-By: Claude <noreply@anthropic.com>"
```

Use descriptive but concise commit messages:
- "Use C++20 concepts for type constraints in foo.hpp"
- "Simplify boolean logic in bar::process()"
- "Replace manual loop with std::ranges::transform"

### Step 6: Iterate

Track iterations explicitly. After each iteration report:
- Iteration number
- What was simplified
- Files changed
- Tests status (passed/failed/skipped)
- Remaining opportunities

Repeat from Step 1 until:
- No more simplifications are identified
- User requests to stop
- 5 iterations completed

## Example

**Before** (SFINAE):
```cpp
template <typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
void process(T value) { ... }
```

**After** (C++20 concept):
```cpp
template <std::integral T>
void process(T value) { ... }
```
