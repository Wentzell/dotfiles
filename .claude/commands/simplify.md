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

## Simplification Categories

Simplifications fall into five categories, roughly ordered by priority:

### 1. Dead Code and Unused Elements
- Remove unused parameters, variables, and functions
- Delete unreachable code paths
- Remove redundant checks (e.g., null checks after already dereferencing)
- Clean up commented-out code blocks
- Remove unused includes, typedefs, or forward declarations

### 2. Clarity and Readability
- Improve variable/function naming to be more descriptive
- Use early returns to reduce nesting depth
- Break up deeply nested conditionals
- Replace magic numbers with named constants
- Add structure with blank lines between logical sections
- Simplify boolean expressions (e.g., `if (x == true)` → `if (x)`)

### 3. Complexity Reduction
- Break up long functions into smaller, focused ones
- Simplify overly clever or "tricky" code
- Flatten unnecessary indirection
- Replace complex conditional chains with clearer alternatives
- Reduce function parameter counts where possible

### 4. Duplication
- Consolidate repeated code patterns into helper functions
- Extract common logic from similar branches
- Unify inconsistent implementations of the same operation

### 5. Modernization (C++20/23)
- Replace `std::enable_if_t` SFINAE with C++20 concepts
- Replace manual loops with range-based algorithms
- Use structured bindings for tuple/pair unpacking
- Use `auto` for obvious types
- Use `std::ssize` for signed container sizes
- Replace `nullptr` checks with `std::optional` where appropriate

## Principles

- **Clarity over cleverness**: Code should be self-explanatory
- **Concise but not cryptic**: Remove verbosity without sacrificing readability
- **Consistent style**: Match existing codebase conventions
- **No functional changes**: Simplifications must preserve behavior exactly
- **Fix warnings**: Compiler warnings (unused parameters, etc.) are simplification opportunities

### Avoid

- Changing public API signatures
- Altering behavior, even edge cases
- Adding new features under the guise of simplification
- Over-abstracting one-time operations
- Removing comments that explain non-obvious logic

## Workflow

### Step 1: Exploration

Thoroughly explore the target to identify simplification opportunities:

1. **For directories**: Read all relevant source files (headers, implementation files)
2. **For files**: Read the entire file and understand its structure
3. **Build first**: Run the build to catch any warnings - these are simplification targets
   ```bash
   cmake --build build 2>&1 | grep -E "warning:|error:"
   ```

Look for opportunities in all five categories:
- Compiler warnings (unused parameters, variables, etc.)
- Dead or unreachable code
- Deep nesting that could use early returns
- Long or complex functions
- Duplicated code patterns
- Verbose code that could use modern C++ features
- Poor naming or unclear logic

Create a prioritized list of specific simplifications with:
- File path and line numbers
- Current code snippet
- Proposed simplification
- Category (dead code, clarity, complexity, duplication, modernization)
- Rationale

**If no opportunities found**: Report "No simplification opportunities identified" and stop.

### Step 2: Review and Select

Review the proposed simplifications:

1. **Filter out** any that:
   - Might change behavior
   - Would require changing public APIs
   - Are purely stylistic with no clarity benefit

2. **Prioritize** by:
   - Dead code removal (safest, often flagged by compiler)
   - Clarity improvements (high value, usually safe)
   - Complexity reduction (high value, moderate risk)
   - Duplication (moderate value, requires care)
   - Modernization (lower priority if code is already clear)

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
cmake --build build
ctest --test-dir build -j 16
```

**If tests cannot be run** (missing dependencies, build not configured):
- Document this limitation in the commit message
- Limit to ONE simplification per iteration
- Only make changes that are provably equivalent
- Complete the verification checklist below

**Verification Checklist** (when tests unavailable):
- [ ] No change to public API signatures
- [ ] Semantics are identical (not just similar)
- [ ] All related uses are updated consistently
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
- "Remove unused config parameter from probs_factory_t constructor"
- "Use early return to reduce nesting in process()"
- "Extract common validation logic into validate_input()"
- "Use C++20 concepts for type constraints in foo.hpp"

### Step 6: Iterate

Track iterations explicitly. After each iteration report:
- Iteration number
- What was simplified (with category)
- Files changed
- Tests status (passed/failed/skipped)
- Remaining opportunities

Repeat from Step 1 until:
- No more simplifications are identified
- User requests to stop
- 5 iterations completed

## Examples

**Dead code** - Remove unused parameter:
```cpp
// Before
void process(Config const& config, Data const& data) {
  // config is never used
  transform(data);
}

// After
void process(Data const& data) {
  transform(data);
}
```

**Clarity** - Early return to reduce nesting:
```cpp
// Before
void handle(Request const& req) {
  if (req.valid()) {
    if (req.authorized()) {
      if (req.has_data()) {
        process(req.data());
      }
    }
  }
}

// After
void handle(Request const& req) {
  if (!req.valid()) return;
  if (!req.authorized()) return;
  if (!req.has_data()) return;
  process(req.data());
}
```

**Modernization** - SFINAE to concept:
```cpp
// Before
template <typename T, typename = std::enable_if_t<std::is_integral_v<T>>>
void process(T value) { ... }

// After
template <std::integral T>
void process(T value) { ... }
```
