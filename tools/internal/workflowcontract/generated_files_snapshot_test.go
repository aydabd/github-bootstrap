package workflowcontract

import (
	"fmt"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func TestGeneratedRepositoryRequiredFilesSnapshot(t *testing.T) {
	repoRoot := findRepoRoot(t)
	script := extractNamedRunScript(
		t,
		filepath.Join(repoRoot, ".github", "workflows", "test-repository-creation.yml"),
		"Validate repository structure",
	)

	requiredFiles := extractBashArray(t, script, "REQUIRED_FILES")
	wantRequiredFiles := []string{
		".github/workflows/lint.yml",
		".github/CODEOWNERS",
		".github/dependabot.yml",
		".pre-commit-config.yaml",
		".editorconfig",
		".gitignore",
		".gitattributes",
		"README.md",
		"LICENSE",
		"Makefile",
		"AGENT.md",
		"CLAUDE.md",
		".github/copilot-instructions.md",
		".github/instructions/project.instructions.md",
		".github/instructions/prompt-quality.instructions.md",
		".cursor/rules/project.mdc",
		".windsurfrules",
	}

	if !reflect.DeepEqual(requiredFiles, wantRequiredFiles) {
		t.Fatalf("REQUIRED_FILES drifted:\n got: %#v\nwant: %#v", requiredFiles, wantRequiredFiles)
	}

	checkRequiredFileSources(t, repoRoot, requiredFiles)
}

func TestGeneratedRepositoryForbiddenPathsSnapshot(t *testing.T) {
	repoRoot := findRepoRoot(t)
	script := extractNamedRunScript(
		t,
		filepath.Join(repoRoot, ".github", "workflows", "test-repository-creation.yml"),
		"Validate repository structure",
	)

	forbiddenPaths := extractBashArray(t, script, "FORBIDDEN_TEMPLATE_PATHS")
	wantForbiddenPaths := []string{
		"languages",
		"providers",
		".github/workflows/providers",
	}
	if !reflect.DeepEqual(forbiddenPaths, wantForbiddenPaths) {
		t.Fatalf("FORBIDDEN_TEMPLATE_PATHS drifted:\n got: %#v\nwant: %#v", forbiddenPaths, wantForbiddenPaths)
	}
}

func checkRequiredFileSources(t *testing.T, repoRoot string, requiredFiles []string) {
	t.Helper()

	templatesRoot := filepath.Join(repoRoot, "templates")
	for _, file := range requiredFiles {
		switch file {
		case ".github/workflows/lint.yml":
			for _, envManager := range []string{"micromamba", "mise", "system"} {
				lintTemplate := filepath.Join(
					templatesRoot,
					".github",
					"workflows",
					"providers",
					"lint-"+envManager+".yml",
				)
				if _, err := os.Stat(lintTemplate); err != nil {
					t.Fatalf("missing lint workflow template for %s: %v", envManager, err)
				}
			}
		case "Makefile":
			for _, langDir := range []string{"agnostic", "python", "golang", "typescript", "java"} {
				for _, envManager := range []string{"micromamba", "mise", "system"} {
					providerMakefile := filepath.Join(
						templatesRoot,
						"languages",
						langDir,
						"providers",
						envManager,
						"Makefile",
					)
					if _, err := os.Stat(providerMakefile); err != nil {
						t.Fatalf("missing provider Makefile for %s/%s: %v", langDir, envManager, err)
					}
				}
			}
		case ".pre-commit-config.yaml":
			baseTemplate := filepath.Join(
				templatesRoot,
				"languages",
				"agnostic",
				"pre-commit-snippets",
				"base.tmpl",
			)
			if _, err := os.Stat(baseTemplate); err != nil {
				t.Fatalf("missing pre-commit base template: %v", err)
			}
			for _, langDir := range []string{"python", "golang", "typescript", "java"} {
				excludeSnippet := filepath.Join(
					templatesRoot,
					"languages",
					langDir,
					"pre-commit-snippets",
					"exclude-block.txt",
				)
				hooksSnippet := filepath.Join(
					templatesRoot,
					"languages",
					langDir,
					"pre-commit-snippets",
					"language-hooks.txt",
				)
				if _, err := os.Stat(excludeSnippet); err != nil {
					t.Fatalf("missing pre-commit exclude snippet for %s: %v", langDir, err)
				}
				if _, err := os.Stat(hooksSnippet); err != nil {
					t.Fatalf("missing pre-commit hooks snippet for %s: %v", langDir, err)
				}
			}
		case ".editorconfig":
			editorConfigTemplate := filepath.Join(templatesRoot, ".github", "linters", ".editorconfig")
			if _, err := os.Stat(editorConfigTemplate); err != nil {
				t.Fatalf("missing editorconfig template source %s: %v", editorConfigTemplate, err)
			}
		default:
			templateFile := filepath.Join(templatesRoot, filepath.FromSlash(file))
			if _, err := os.Stat(templateFile); err != nil {
				t.Fatalf("missing required template file %s (source for generated %s): %v", templateFile, file, err)
			}
		}
	}
}

func extractBashArray(t *testing.T, script, arrayName string) []string {
	t.Helper()

	lines := strings.Split(script, "\n")
	startMarker := arrayName + "=("
	inside := false
	values := make([]string, 0)

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !inside {
			if trimmed == startMarker {
				inside = true
			}
			continue
		}
		if trimmed == ")" {
			return values
		}
		if trimmed == "" || strings.HasPrefix(trimmed, "#") {
			continue
		}
		values = append(values, strings.Trim(trimmed, "\""))
	}

	t.Fatalf("array %s not found or unterminated in script", arrayName)
	return nil
}

func TestProviderToolingTemplateCoverage(t *testing.T) {
	repoRoot := findRepoRoot(t)
	templatesRoot := filepath.Join(repoRoot, "templates")

	tests := []struct {
		langDir    string
		envManager string
		tooling    string
		required   bool
	}{
		{langDir: "agnostic", envManager: "micromamba", tooling: "environment.yml", required: true},
		{langDir: "agnostic", envManager: "mise", tooling: "mise.toml", required: true},
		{langDir: "python", envManager: "micromamba", tooling: "environment.yml", required: true},
		{langDir: "python", envManager: "mise", tooling: "mise.toml", required: true},
		{langDir: "golang", envManager: "micromamba", tooling: "environment.yml", required: true},
		{langDir: "golang", envManager: "mise", tooling: "mise.toml", required: true},
		{langDir: "typescript", envManager: "micromamba", tooling: "environment.yml", required: true},
		{langDir: "typescript", envManager: "mise", tooling: "mise.toml", required: true},
		{langDir: "java", envManager: "micromamba", tooling: "environment.yml", required: true},
		{langDir: "java", envManager: "mise", tooling: "mise.toml", required: true},
	}

	for _, tt := range tests {
		name := fmt.Sprintf("%s/%s/%s", tt.langDir, tt.envManager, tt.tooling)
		t.Run(name, func(t *testing.T) {
			filePath := filepath.Join(
				templatesRoot,
				"languages",
				tt.langDir,
				"providers",
				tt.envManager,
				tt.tooling,
			)
			_, err := os.Stat(filePath)
			if tt.required && err != nil {
				t.Fatalf("expected tooling template missing: %s (%v)", filePath, err)
			}
		})
	}
}
