package toolinglib

import (
	"os"
	"strings"
	"testing"
)

func TestUpdateEnvText(t *testing.T) {
	source := "dependencies:\n  - pre-commit=4.0.0\n  - prettier=1.0.0\n"
	updated, err := UpdateEnvText(source, map[string]string{"pre-commit": "4.6.0", "prettier": "3.9.3"})
	if err != nil {
		t.Fatalf("UpdateEnvText returned error: %v", err)
	}
	if !strings.Contains(updated, "pre-commit=4.6.0") {
		t.Fatalf("expected updated pre-commit version, got: %s", updated)
	}
	if !strings.Contains(updated, "prettier=3.9.3") {
		t.Fatalf("expected updated prettier version, got: %s", updated)
	}
}

func TestUpdateEnvTextIgnoresMissingPackage(t *testing.T) {
	source := "dependencies:\n  - pre-commit=4.0.0\n"
	updated, err := UpdateEnvText(source, map[string]string{"pre-commit": "4.6.0", "terraform": "1.2.3"})
	if err != nil {
		t.Fatalf("UpdateEnvText returned error: %v", err)
	}
	if !strings.Contains(updated, "pre-commit=4.6.0") {
		t.Fatalf("expected updated pre-commit version, got: %s", updated)
	}
}

func TestUpdateEnvTextKeepsTemplatePlaceholders(t *testing.T) {
	source := "dependencies:\n  - python={{PYTHON_VERSION}}\n  - nodejs={{NODE_VERSION}}\n  - pre-commit=4.0.0\n"
	updated, err := UpdateEnvText(source, map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "pre-commit": "4.6.0"})
	if err != nil {
		t.Fatalf("UpdateEnvText returned error: %v", err)
	}
	if !strings.Contains(updated, "python={{PYTHON_VERSION}}") {
		t.Fatalf("expected python placeholder to remain, got: %s", updated)
	}
	if !strings.Contains(updated, "nodejs={{NODE_VERSION}}") {
		t.Fatalf("expected node placeholder to remain, got: %s", updated)
	}
	if !strings.Contains(updated, "pre-commit=4.6.0") {
		t.Fatalf("expected updated pre-commit version, got: %s", updated)
	}
}

func TestUpdateMiseTextKeepsTemplatePlaceholders(t *testing.T) {
	source := "[tools]\npython = \"{{PYTHON_VERSION}}\"\nshellcheck = \"0.10.0\"\nshfmt = \"3.0.0\"\nterraform = \"1.0.0\"\ntaplo = \"0.1.0\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "go": "1.26.4", "shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.10.0"},
		map[string]string{"pre-commit": "4.6.0", "editorconfig-checker": "3.6.1", "yamllint": "1.38.0"},
		map[string]string{"prettier": "3.9.3", "markdownlint-cli": "0.49.0"},
		nil,
	)
	if err != nil {
		t.Fatalf("UpdateMiseText returned error: %v", err)
	}
	expects := []string{
		`python = "{{PYTHON_VERSION}}"`,
		`shellcheck = "0.11.0"`,
		`shfmt = "3.13.1"`,
		`terraform = "1.15.6"`,
		`taplo = "0.10.0"`,
		"pre-commit==4.6.0",
		"editorconfig-checker==3.6.1",
		"yamllint==1.38.0",
		"prettier@3.9.3",
		"markdownlint-cli@0.49.0",
	}
	for _, expected := range expects {
		if !strings.Contains(updated, expected) {
			t.Fatalf("expected %q in output", expected)
		}
	}
}

func TestUpdateMiseTextIgnoresMissingGoModulePatterns(t *testing.T) {
	source := "[tools]\npython = \"{{PYTHON_VERSION}}\"\nshellcheck = \"0.10.0\"\nshfmt = \"3.0.0\"\nterraform = \"1.0.0\"\ntaplo = \"0.1.0\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "go": "1.26.4", "shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.10.0"},
		map[string]string{"pre-commit": "4.6.0", "editorconfig-checker": "3.6.1", "yamllint": "1.38.0"},
		map[string]string{"prettier": "3.9.3", "markdownlint-cli": "0.49.0"},
		map[string]string{"github.com/daixiang0/gci": "v0.1.0", "github.com/golangci/golangci-lint/cmd/golangci-lint": "v1.2.3"},
	)
	if err != nil {
		t.Fatalf("UpdateMiseText returned error: %v", err)
	}
	if !strings.Contains(updated, "pre-commit==4.6.0") {
		t.Fatalf("expected updated pre-commit version, got: %s", updated)
	}
}

func TestUpdateMiseTextUpdatesJavaTemurinPrefix(t *testing.T) {
	source := "[tools]\njava = \"temurin-21\"\npython = \"3.12\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "go": "1.26.4", "openjdk": "25.0.2", "shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.10.0"},
		map[string]string{"pre-commit": "4.6.0", "editorconfig-checker": "3.6.1", "yamllint": "1.38.0"},
		map[string]string{"prettier": "3.9.3", "markdownlint-cli": "0.49.0"},
		nil,
	)
	if err != nil {
		t.Fatalf("UpdateMiseText returned error: %v", err)
	}
	if !strings.Contains(updated, `java = "temurin-25.0.2"`) {
		t.Fatalf("expected java temurin prefix update, got: %s", updated)
	}
	if !strings.Contains(updated, `python = "3.13.14"`) {
		t.Fatalf("expected python update, got: %s", updated)
	}
}

func TestUpdateMiseTextPreservesJavaTemplatePlaceholder(t *testing.T) {
	source := "[tools]\njava = \"temurin-{{JAVA_VERSION}}\"\npython = \"{{PYTHON_VERSION}}\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "go": "1.26.4", "openjdk": "25.0.2", "shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.10.0"},
		map[string]string{"pre-commit": "4.6.0", "editorconfig-checker": "3.6.1", "yamllint": "1.38.0"},
		map[string]string{"prettier": "3.9.3", "markdownlint-cli": "0.49.0"},
		nil,
	)
	if err != nil {
		t.Fatalf("UpdateMiseText returned error: %v", err)
	}
	if !strings.Contains(updated, `java = "temurin-{{JAVA_VERSION}}"`) {
		t.Fatalf("expected java placeholder to be preserved, got: %s", updated)
	}
	if !strings.Contains(updated, `python = "{{PYTHON_VERSION}}"`) {
		t.Fatalf("expected python placeholder to be preserved, got: %s", updated)
	}
}

func TestUpdateMiseTextUpdatesRuntimePinsWhenPresent(t *testing.T) {
	source := "[tools]\npython = \"3.12\"\nnode = \"22\"\ngo = \"1.25\"\nshellcheck = \"0.10.0\"\nshfmt = \"3.0.0\"\nterraform = \"1.0.0\"\ntaplo = \"0.1.0\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"python": "3.13.14", "nodejs": "24.10.0", "go": "1.26.4", "shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.10.0"},
		map[string]string{"pre-commit": "4.6.0", "editorconfig-checker": "3.6.1", "yamllint": "1.38.0"},
		map[string]string{"prettier": "3.9.3", "markdownlint-cli": "0.49.0"},
		nil,
	)
	if err != nil {
		t.Fatalf("UpdateMiseText returned error: %v", err)
	}
	expects := []string{`python = "3.13.14"`, `node = "24.10.0"`, `go = "1.26.4"`}
	for _, expected := range expects {
		if !strings.Contains(updated, expected) {
			t.Fatalf("expected %q in output", expected)
		}
	}
}

func TestUpdateBootstrapScriptText(t *testing.T) {
	source := "case \"$provider:$os:$arch\" in\n    mise:linux:x64)\n        url=\"https://example.invalid/old\"\n        sha256=\"old\"\n        ;;\nesac\n"
	updated, err := UpdateBootstrapScriptText(source, map[string]ProviderAsset{
		"mise:linux:x64": {URL: "https://example.invalid/new", SHA256: "abc123"},
	})
	if err != nil {
		t.Fatalf("UpdateBootstrapScriptText returned error: %v", err)
	}
	if !strings.Contains(updated, `url="https://example.invalid/new"`) {
		t.Fatalf("expected updated url, got: %s", updated)
	}
	if !strings.Contains(updated, `sha256="abc123"`) {
		t.Fatalf("expected updated sha256, got: %s", updated)
	}
}

func TestUpdateFilePreservesPermissions(t *testing.T) {
	tmp, err := os.CreateTemp(t.TempDir(), "bootstrap-*.sh")
	if err != nil {
		t.Fatalf("CreateTemp: %v", err)
	}
	if _, err := tmp.WriteString("#!/bin/sh\necho old\n"); err != nil {
		t.Fatalf("WriteString: %v", err)
	}
	_ = tmp.Close()
	if err := os.Chmod(tmp.Name(), 0o755); err != nil {
		t.Fatalf("Chmod: %v", err)
	}

	changed, err := UpdateFile(tmp.Name(), func(content string) (string, error) {
		return strings.ReplaceAll(content, "old", "new"), nil
	}, true)
	if err != nil {
		t.Fatalf("UpdateFile failed: %v", err)
	}
	if !changed {
		t.Fatal("expected file to be reported changed")
	}

	info, err := os.Stat(tmp.Name())
	if err != nil {
		t.Fatalf("Stat: %v", err)
	}
	if info.Mode().Perm() != 0o755 {
		t.Fatalf("expected permission 0755, got %o", info.Mode().Perm())
	}
}
