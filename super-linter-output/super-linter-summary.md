# Super Linter output (documentation)

This directory is intended to hold **generated output** from the Super Linter
(for example, when run in CI). Actual linter run results are ephemeral and
**should not be committed to version control**.

If you run the Super Linter locally or in CI, configure it to write reports
into this directory, but ensure your `.gitignore` excludes `super-linter-output/`
so that those reports do not become stale files in the repository.

This file exists only as documentation of the directory's purpose and does
not represent the result of any particular linter run.
