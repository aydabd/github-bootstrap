package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

var expectedAllLanguages = []string{"golang", "python", "typescript", "java"}

func TestNormalizeLanguages(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []string
		wantErr bool
	}{
		{name: "default agnostic", input: "", want: []string{"agnostic"}},
		{name: "explicit agnostic", input: "agnostic", want: []string{"agnostic"}},
		{name: "language agnostic only", input: "language-agnostic-only", want: []string{"agnostic"}},
		{name: "single alias", input: "go", want: []string{"golang"}},
		{name: "node alias", input: "node", want: []string{"typescript"}},
		{name: "nodejs alias", input: "nodejs", want: []string{"typescript"}},
		{name: "kotlin alias", input: "kotlin", want: []string{"java"}},
		{name: "multiple dedupe", input: "go,typescript,javascript,python", want: []string{"golang", "typescript", "python"}},
		{name: "all", input: "all", want: expectedAllLanguages},
		{name: "mixed all token", input: "python,all", want: expectedAllLanguages},
		{name: "invalid agnostic with all", input: "agnostic,all", wantErr: true},
		// Current drift: workflows reject unknown tokens, but the renderer falls back to agnostic.
		{name: "current unknown token drift", input: "unknown", want: []string{"agnostic"}},
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

func TestRepositoryTemplateSnapshots(t *testing.T) {
	repoRoot := findRepoRoot(t)
	basePath := filepath.Join(repoRoot, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl")
	snippetsRoot := filepath.Join(repoRoot, "templates", "languages")

	tests := []struct {
		name             string
		languages        []string
		wantPresent      []string
		wantAbsent       []string
		wantExcludeCount map[string]int
	}{
		{
			name:      "agnostic root",
			languages: []string{"agnostic"},
			wantAbsent: []string{
				"id: golangci-lint",
				"id: ruff-check",
				"id: biome",
				"id: spotless",
			},
			wantExcludeCount: map[string]int{
				"|vendor/":       0,
				"|dist/":         0,
				"|node_modules/": 0,
				"|\\.gradle/":    0,
			},
		},
		{
			name:      "all language root",
			languages: expectedAllLanguages,
			wantPresent: []string{
				"id: golangci-lint",
				"id: ruff-check",
				"id: ruff-format",
				"id: mypy",
				"id: biome",
				"id: spotless",
				"id: checkstyle",
			},
			wantExcludeCount: map[string]int{
				"|vendor/":       1,
				"|dist/":         1,
				"|node_modules/": 1,
				"|\\.gradle/":    1,
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rendered, err := renderConfig(basePath, snippetsRoot, tt.languages)
			if err != nil {
				t.Fatalf("renderConfig failed: %v", err)
			}

			for _, want := range tt.wantPresent {
				if !strings.Contains(rendered, want) {
					t.Fatalf("rendered config missing %q:\n%s", want, rendered)
				}
			}
			for _, forbidden := range tt.wantAbsent {
				if strings.Contains(rendered, forbidden) {
					t.Fatalf("rendered config unexpectedly contains %q:\n%s", forbidden, rendered)
				}
			}
			for pattern, wantCount := range tt.wantExcludeCount {
				if gotCount := strings.Count(rendered, pattern); gotCount != wantCount {
					t.Fatalf("exclude count for %q mismatch: got %d want %d", pattern, gotCount, wantCount)
				}
			}
		})
	}
}

func TestRunWithRepositoryTemplatesEmitsAllLanguageFiles(t *testing.T) {
	repoRoot := findRepoRoot(t)
	outputRoot := t.TempDir()
	emitDir := filepath.Join(outputRoot, ".pre-commit", "languages")

	cfg := config{
		basePath:       filepath.Join(repoRoot, "templates", "languages", "agnostic", "pre-commit-snippets", "base.tmpl"),
		snippetsRoot:   filepath.Join(repoRoot, "templates", "languages"),
		languagesInput: "agnostic",
		emitLanguages:  "all",
		outputPath:     filepath.Join(outputRoot, ".pre-commit-config.yaml"),
		emitDir:        emitDir,
	}
	if err := run(cfg); err != nil {
		t.Fatalf("run() failed: %v", err)
	}

	for _, lang := range expectedAllLanguages {
		if _, err := os.Stat(filepath.Join(emitDir, lang+".yaml")); err != nil {
			t.Fatalf("expected emitted language file for %s: %v", lang, err)
		}
	}
	if _, err := os.Stat(filepath.Join(emitDir, "agnostic.yaml")); !os.IsNotExist(err) {
		t.Fatalf("agnostic language file should not be emitted, stat error: %v", err)
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

func findRepoRoot(t *testing.T) string {
	t.Helper()

	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, "templates", "languages")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("repository root not found")
		}
		dir = parent
	}
}
