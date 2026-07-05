package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNormalizeLanguages(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []string
		wantErr bool
	}{
		{name: "default agnostic", input: "", want: []string{"agnostic"}},
		{name: "single alias", input: "go", want: []string{"golang"}},
		{name: "multiple dedupe", input: "go,typescript,javascript,python", want: []string{"golang", "typescript", "python"}},
		{name: "all", input: "all", want: []string{"golang", "python", "typescript", "java"}},
		{name: "mixed all token", input: "python,all", want: []string{"golang", "python", "typescript", "java"}},
		{name: "invalid agnostic with all", input: "agnostic,all", wantErr: true},
		{name: "invalid fallback", input: "unknown", want: []string{"agnostic"}},
		{name: "invalid mixed agnostic", input: "language-agnostic-only,go", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := normalizeLanguages(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("normalizeLanguages returned error: %v", err)
			}
			if strings.Join(got, ",") != strings.Join(tt.want, ",") {
				t.Fatalf("normalizeLanguages mismatch: got %v want %v", got, tt.want)
			}
		})
	}
}

func TestRunRendersCombinedAndPerLanguageFiles(t *testing.T) {
	root := t.TempDir()
	basePath := filepath.Join(root, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(root, "templates", "languages")
	outPath := filepath.Join(root, "out", ".pre-commit-config.yaml")
	emitDir := filepath.Join(root, "out", ".pre-commit", "languages")

	mustWrite(t, basePath, "exclude:\n  |-\n    build/\n{{EXCLUDE_BLOCK}}hooks:\n  - repo: local\n    hooks:\n{{LANGUAGE_HOOKS}}")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "exclude-block.txt"), "|vendor/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "language-hooks.txt"), "- id: golangci-lint\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "exclude-block.txt"), "|node_modules/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "language-hooks.txt"), "- id: biome\n")

	cfg := config{
		basePath:       basePath,
		snippetsRoot:   snippetsRoot,
		languagesInput: "go",
		emitLanguages:  "go,typescript",
		outputPath:     outPath,
		emitDir:        emitDir,
	}
	if err := run(cfg); err != nil {
		t.Fatalf("run() failed: %v", err)
	}

	combined := mustRead(t, outPath)
	if !strings.Contains(combined, "|vendor/") || strings.Contains(combined, "|node_modules/") {
		t.Fatalf("combined output exclude set mismatch: %s", combined)
	}
	if !strings.Contains(combined, "golangci-lint") || strings.Contains(combined, "biome") {
		t.Fatalf("combined output hook set mismatch: %s", combined)
	}

	goLang := mustRead(t, filepath.Join(emitDir, "golang.yaml"))
	if !strings.Contains(goLang, "golangci-lint") || strings.Contains(goLang, "biome") {
		t.Fatalf("golang language config incorrect: %s", goLang)
	}
	tsLang := mustRead(t, filepath.Join(emitDir, "typescript.yaml"))
	if !strings.Contains(tsLang, "biome") || strings.Contains(tsLang, "golangci-lint") {
		t.Fatalf("typescript language config incorrect: %s", tsLang)
	}
}

func TestRunMissingSnippetFileReturnsWrappedError(t *testing.T) {
	root := t.TempDir()
	basePath := filepath.Join(root, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(root, "templates", "languages")
	outPath := filepath.Join(root, "out", ".pre-commit-config.yaml")

	mustWrite(t, basePath, "exclude:\n  |-\n    build/\n{{EXCLUDE_BLOCK}}hooks:\n  - repo: local\n    hooks:\n{{LANGUAGE_HOOKS}}")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "exclude-block.txt"), "vendor/\n")

	cfg := config{
		basePath:       basePath,
		snippetsRoot:   snippetsRoot,
		languagesInput: "go",
		outputPath:     outPath,
	}
	err := run(cfg)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "read hooks snippet for golang") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestRunEmitLanguagesRequiresEmitDir(t *testing.T) {
	root := t.TempDir()
	basePath := filepath.Join(root, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(root, "templates", "languages")
	outPath := filepath.Join(root, "out", ".pre-commit-config.yaml")

	mustWrite(t, basePath, "exclude:\n  |-\n    build/\n{{EXCLUDE_BLOCK}}hooks:\n  - repo: local\n    hooks:\n{{LANGUAGE_HOOKS}}")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "exclude-block.txt"), "|vendor/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "language-hooks.txt"), "- id: golangci-lint\n")

	cfg := config{
		basePath:       basePath,
		snippetsRoot:   snippetsRoot,
		languagesInput: "go",
		emitLanguages:  "go",
		outputPath:     outPath,
	}
	err := run(cfg)
	if err == nil {
		t.Fatal("expected error, got nil")
	}
	if !strings.Contains(err.Error(), "--emit-languages requires --emit-language-files-dir") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestRenderConfigUsesRegexAlternationForExcludes(t *testing.T) {
	root := t.TempDir()
	basePath := filepath.Join(root, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(root, "templates", "languages")

	mustWrite(t, basePath, "exclude:\n  |-\n    build/\n{{EXCLUDE_BLOCK}}hooks:\n  - repo: local\n    hooks:\n{{LANGUAGE_HOOKS}}")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "exclude-block.txt"), "|vendor/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "language-hooks.txt"), "- id: golangci-lint\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "exclude-block.txt"), "|node_modules/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "language-hooks.txt"), "- id: biome\n")

	rendered, err := renderConfig(basePath, snippetsRoot, []string{"golang", "typescript"})
	if err != nil {
		t.Fatalf("renderConfig failed: %v", err)
	}
	if !strings.Contains(rendered, "|vendor/") || !strings.Contains(rendered, "|node_modules/") {
		t.Fatalf("exclude alternation not rendered correctly: %s", rendered)
	}
}

func TestRenderConfigDedupesDuplicateExcludePatterns(t *testing.T) {
	root := t.TempDir()
	basePath := filepath.Join(root, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(root, "templates", "languages")

	mustWrite(t, basePath, "exclude:\n  |-\n    build/\n{{EXCLUDE_BLOCK}}hooks:\n  - repo: local\n    hooks:\n{{LANGUAGE_HOOKS}}")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "exclude-block.txt"), "|vendor/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "golang", "pre-commit-snippets", "language-hooks.txt"), "- id: golangci-lint\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "exclude-block.txt"), "|node_modules/\n")
	mustWrite(t, filepath.Join(snippetsRoot, "typescript", "pre-commit-snippets", "language-hooks.txt"), "- id: biome\n")

	rendered, err := renderConfig(basePath, snippetsRoot, []string{"golang", "typescript"})
	if err != nil {
		t.Fatalf("renderConfig failed: %v", err)
	}
	if strings.Count(rendered, "|vendor/") != 1 {
		t.Fatalf("expected duplicate exclude to be deduped, got: %s", rendered)
	}
}

func mustWrite(t *testing.T, path, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("mkdir failed: %v", err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("write failed: %v", err)
	}
}

func mustRead(t *testing.T, path string) string {
	t.Helper()
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read failed: %v", err)
	}
	return string(data)
}
