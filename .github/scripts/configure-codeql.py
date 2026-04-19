#!/usr/bin/env python3
"""Configure the CodeQL workflow for the selected languages.

Reads CODEQL_INPUT_LANGUAGES from the environment, maps each bootstrap language
name to its CodeQL identifier, deduplicates, and either replaces the
{{CODEQL_LANGUAGES}} placeholder in .github/workflows/codeql.yml or removes
the workflow entirely when no supported language was selected.
"""
import os
from pathlib import Path

# Map bootstrap language name to the CodeQL language identifier.
# Languages not supported by CodeQL (rust, php, terraform, docker, css, html) are skipped.
LANGUAGE_MAP = {
    "javascript": "javascript-typescript",
    "typescript": "javascript-typescript",
    "python": "python",
    "java": "java-kotlin",
    "kotlin": "java-kotlin",
    "go": "go",
    "csharp": "csharp",
    "cpp": "cpp",
    "ruby": "ruby",
}

ALL_CODEQL_LANGUAGES = [
    "javascript-typescript",
    "python",
    "java-kotlin",
    "csharp",
    "go",
    "ruby",
    "cpp",
]


def dedupe_preserve_order(items):
    seen = set()
    result = []
    for item in items:
        if item and item not in seen:
            seen.add(item)
            result.append(item)
    return result


languages = os.environ.get("CODEQL_INPUT_LANGUAGES", "").strip().lower()
codeql_langs = []

if languages == "all":
    codeql_langs = ALL_CODEQL_LANGUAGES[:]
elif languages != "language-agnostic-only":
    selected = [part.strip().lower() for part in languages.split(",") if part.strip()]
    mapped = [LANGUAGE_MAP.get(lang, "") for lang in selected]
    codeql_langs = dedupe_preserve_order(mapped)

workflow_path = Path(".github/workflows/codeql.yml")
summary_path = os.environ.get("GITHUB_STEP_SUMMARY")

PLACEHOLDER = "{{CODEQL_LANGUAGES}}"

if codeql_langs:
    if workflow_path.exists():
        content = workflow_path.read_text(encoding="utf-8")
        if PLACEHOLDER not in content:
            error_message = (
                f"CodeQL workflow template is missing the {PLACEHOLDER} placeholder\n"
            )
            if summary_path:
                with open(summary_path, "a", encoding="utf-8") as f:
                    f.write(error_message)
            raise SystemExit(error_message.strip())
        content = content.replace(PLACEHOLDER, ", ".join(codeql_langs))
        workflow_path.write_text(content, encoding="utf-8")
    summary_message = f"CodeQL configured for: {', '.join(codeql_langs)}\n"
else:
    # No supported CodeQL language — remove the workflow to avoid an empty matrix
    if workflow_path.exists():
        workflow_path.unlink()
    summary_message = "CodeQL skipped — no supported language selected\n"

if summary_path:
    with open(summary_path, "a", encoding="utf-8") as summary_file:
        summary_file.write(summary_message)
