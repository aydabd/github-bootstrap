package toolinglib

import (
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

func TestUpdateMiseTextKeepsTemplatePlaceholders(t *testing.T) {
	source := "[tools]\npython = \"{{PYTHON_VERSION}}\"\nshellcheck = \"0.10.0\"\nshfmt = \"3.0.0\"\nterraform = \"1.0.0\"\ntaplo = \"0.1.0\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n]\n"
	updated, err := UpdateMiseText(
		source,
		map[string]string{"shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.9.3"},
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
		`taplo = "0.9.3"`,
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
		map[string]string{"shellcheck": "0.11.0", "go-shfmt": "3.13.1", "terraform": "1.15.6", "taplo": "0.9.3"},
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
