#!/usr/bin/env python3
"""Remove Dependabot ecosystem entries the selected provider cannot satisfy.

Reads ENV_MANAGER from the environment. Only the micromamba provider lacks a
root package.json (mise and system providers ship one for JS-based lint
tooling), so its generated repositories always fail the "npm" Dependabot
update with dependency_file_not_found. Remove that entry for micromamba;
leave the file untouched otherwise.
"""
import os
from pathlib import Path

ENV_MANAGER = os.environ.get("ENV_MANAGER", "").strip()
DEPENDABOT_PATH = Path(".github/dependabot.yml")
NPM_ENTRY_MARKER = '- package-ecosystem: "npm"'

summary_path = os.environ.get("GITHUB_STEP_SUMMARY")


def remove_npm_entry(lines):
    start = next(
        (i for i, line in enumerate(lines) if line.strip() == NPM_ENTRY_MARKER),
        None,
    )
    if start is None:
        return lines, False
    block_start = start - 1 if start > 0 and lines[start - 1].strip() == "" else start
    end = start + 1
    while end < len(lines) and not lines[end].lstrip().startswith("- package-ecosystem:"):
        end += 1
    del lines[block_start:end]
    return lines, True


if ENV_MANAGER == "micromamba" and DEPENDABOT_PATH.exists():
    original_lines = DEPENDABOT_PATH.read_text(encoding="utf-8").splitlines(keepends=True)
    updated_lines, removed = remove_npm_entry(original_lines)
    if removed:
        DEPENDABOT_PATH.write_text("".join(updated_lines), encoding="utf-8")
        message = "Removed npm Dependabot ecosystem: micromamba repositories have no package.json\n"
    else:
        message = "npm Dependabot ecosystem entry not found; nothing to remove\n"
else:
    message = f"Kept npm Dependabot ecosystem for env_manager={ENV_MANAGER or 'unset'}\n"

if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary_file:
        summary_file.write(message)
