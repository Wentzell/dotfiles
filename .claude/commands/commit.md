Commit pending changes

- First, run `git clang-format` on all staged C++ source files to ensure consistent formatting.
- If clang-format made changes, stage those formatting changes as well.
- If tests have not already been verified in this session, run them using `ctest` to ensure they pass. If tests fail, fix the issues before proceeding.
- Create a commit with a concise message:
  - Start with a verb (Add, Fix, Update, Move, Make, etc.)
  - Do NOT include "Generated with Claude Code"
  - Add Claude as co-author using: `Co-authored-by: Claude <noreply@anthropic.com>`
  - For multi-line descriptions, use bullet points with `-`
