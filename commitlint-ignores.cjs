// Commitlint ignores for pre-conventional automation commits.
// This file is referenced by .commitlintrc.yml via "extends" so that the
// ignores() function (not expressible in YAML) is available.
//
// The "Initial plan" commit was created by the copilot automation agent
// before commitlint was enabled in this project and cannot be rewritten.
"use strict";

module.exports = {
    ignores: [
        // Skip the empty "Initial plan" bootstrap commit from the agent.
        (commit) => commit === "Initial plan",
    ],
};
