// Commitlint configuration for conventional commits.
// See: https://www.conventionalcommits.org/
//
// This is a CommonJS module rather than .commitlintrc.yml because commitlint
// only applies the ignores() function from the PRIMARY config file, not from
// extends entries. YAML cannot express functions, so this CJS file is the
// primary config. .commitlintrc.yml is intentionally null so cosmiconfig skips
// it and lands here.
"use strict";

module.exports = {
    extends: ["@commitlint/config-conventional"],

    // Skip any pre-conventional automation commits that were created before
    // commitlint was enabled in this project and cannot be rewritten.
    // Use .trim() because git commit messages include trailing newlines.
    ignores: [(commit) => commit.trim() === "Initial plan"],

    rules: {
        // Type must be one of the following
        "type-enum": [
            2,
            "always",
            [
                "feat",
                "fix",
                "docs",
                "style",
                "refactor",
                "perf",
                "test",
                "build",
                "ci",
                "chore",
                "revert",
            ],
        ],

        // Subject must not be empty
        "subject-empty": [2, "never"],

        // Type must not be empty
        "type-empty": [2, "never"],

        // Header max length
        "header-max-length": [2, "always", 100],
    },
};
