package updaters

import (
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github-bootstrap/tools/pkg/toolinglib"
)

func mustWriteFile(t *testing.T, path string, content string) {
	t.Helper()
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		t.Fatalf("failed to create parent dir for %s: %v", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatalf("failed to write %s: %v", path, err)
	}
}

func mustReadFile(t *testing.T, path string) string {
	t.Helper()
	payload, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read %s: %v", path, err)
	}
	return string(payload)
}

func containsAll(paths []string, want ...string) bool {
	for _, target := range want {
		if !slices.Contains(paths, target) {
			return false
		}
	}
	return true
}

func TestRunUpdatersEndToEndWithTempWorkspace(t *testing.T) {
	root := t.TempDir()

	repoEnv := filepath.Join(root, "environment.yml")
	tplEnv := filepath.Join(root, "templates", "languages", "go", "providers", "micromamba", "environment.yml")
	repoMise := filepath.Join(root, "mise.toml")
	tplMise := filepath.Join(root, "templates", "languages", "go", "providers", "mise", "mise.toml")
	repoBootstrap := filepath.Join(root, "scripts", "bootstrap-provider-binary.sh")
	tplBootstrap := filepath.Join(root, "templates", "scripts", "bootstrap-provider-binary.sh")
	repoPre := filepath.Join(root, ".pre-commit-config.yaml")
	tplPre := filepath.Join(root, "templates", "languages", "go", ".pre-commit-config.yaml")

	mustWriteFile(t, repoEnv, "dependencies:\n  - pre-commit=1.0.0\n  - go-shfmt=1.0.0\n  - terraform=1.0.0\n")
	mustWriteFile(t, tplEnv, "dependencies:\n  - pre-commit=1.0.0\n  - go-shfmt=1.0.0\n")

	miseSource := "[tools]\nshellcheck = \"0.1.0\"\nshfmt = \"0.1.0\"\nterraform = \"0.1.0\"\ntaplo = \"0.1.0\"\n\n[tasks.install-tools]\nrun = [\n  \"python -m pip install pre-commit==1.0.0 editorconfig-checker==1.0.0 yamllint==1.0.0\",\n  \"npm install -g prettier@1.0.0 markdownlint-cli@1.0.0\",\n  \"go install github.com/daixiang0/gci@v0.1.0\",\n  \"go install github.com/golangci/golangci-lint/cmd/golangci-lint@v0.1.0\",\n]\n"
	mustWriteFile(t, repoMise, miseSource)
	mustWriteFile(t, tplMise, miseSource)

	bootstrap := "case \"$provider:$os:$arch\" in\n  mise:linux:x64)\n    url=\"https://old.example/mise\"\n    sha256=\"old\"\n    ;;\n  micromamba:linux:x64)\n    url=\"https://old.example/mamba\"\n    sha256=\"old\"\n    ;;\nesac\n"
	mustWriteFile(t, repoBootstrap, bootstrap)
	mustWriteFile(t, tplBootstrap, bootstrap)

	mustWriteFile(t, repoPre, "repos:\n  - repo: https://example.invalid\n")
	mustWriteFile(t, tplPre, "repos:\n  - repo: https://example.invalid\n")

	binDir := filepath.Join(root, "bin")
	preCommitPath := filepath.Join(binDir, "pre-commit")
	// Idempotent: only appends the marker when it is not already present.
	fakePreCommit := "#!/bin/sh\nset -eu\nconfig=\"\"\nwhile [ $# -gt 0 ]; do\n  if [ \"$1\" = \"--config\" ]; then\n    shift\n    config=\"$1\"\n  fi\n  shift\ndone\nif ! grep -q '# updated-by-fake-pre-commit' \"$config\"; then\n  echo '# updated-by-fake-pre-commit' >> \"$config\"\nfi\n"
	mustWriteFile(t, preCommitPath, fakePreCommit)
	if err := os.Chmod(preCommitPath, 0o755); err != nil {
		t.Fatalf("failed to chmod fake pre-commit: %v", err)
	}
	t.Setenv("PATH", binDir+string(os.PathListSeparator)+os.Getenv("PATH"))

	versions := toolinglib.Versions{
		Conda: map[string]string{
			"pre-commit": "4.6.0",
			"go-shfmt":   "3.13.1",
			"terraform":  "1.15.6",
			"shellcheck": "0.11.0",
			"taplo":      "0.9.3",
		},
		Python: map[string]string{
			"pre-commit":           "4.6.0",
			"editorconfig-checker": "3.6.1",
			"yamllint":             "1.38.0",
		},
		NPM: map[string]string{
			"prettier":         "3.9.3",
			"markdownlint-cli": "0.49.0",
		},
		GoModules: map[string]string{
			"github.com/daixiang0/gci":                            "v0.13.7",
			"github.com/golangci/golangci-lint/cmd/golangci-lint": "v1.64.8",
		},
		Providers: map[string]toolinglib.ProviderAsset{
			"mise:linux:x64":       {URL: "https://new.example/mise", SHA256: "mise-sha"},
			"micromamba:linux:x64": {URL: "https://new.example/mamba", SHA256: "mamba-sha"},
		},
	}

	mambaChanged, err := RunMicromamba(root, "all", versions, true)
	if err != nil {
		t.Fatalf("RunMicromamba failed: %v", err)
	}
	if !containsAll(mambaChanged, repoEnv, tplEnv, repoBootstrap, tplBootstrap) {
		t.Fatalf("RunMicromamba changed mismatch: %v", mambaChanged)
	}

	miseChanged, err := RunMise(root, "all", versions, true)
	if err != nil {
		t.Fatalf("RunMise failed: %v", err)
	}
	if !containsAll(miseChanged, repoMise, tplMise, repoBootstrap, tplBootstrap) {
		t.Fatalf("RunMise changed mismatch: %v", miseChanged)
	}

	preChanged, err := RunPreCommit(root, "all", true)
	if err != nil {
		t.Fatalf("RunPreCommit failed: %v", err)
	}
	if !containsAll(preChanged, repoPre, tplPre) {
		t.Fatalf("RunPreCommit changed mismatch: %v", preChanged)
	}

	// Dry-run: the fake pre-commit already appended its marker in the write pass above,
	// so autoupdate on the temp copy produces no further change — expect empty result.
	if dryChanged, err := RunPreCommit(root, "all", false); err != nil {
		t.Fatalf("RunPreCommit dry-run failed: %v", err)
	} else if len(dryChanged) != 0 {
		t.Fatalf("RunPreCommit dry-run expected no changes, got %v", dryChanged)
	}

	if !strings.Contains(mustReadFile(t, repoEnv), "pre-commit=4.6.0") {
		t.Fatalf("repo environment.yml was not updated")
	}
	if !strings.Contains(mustReadFile(t, tplEnv), "go-shfmt=3.13.1") {
		t.Fatalf("template environment.yml was not updated")
	}
	if !strings.Contains(mustReadFile(t, repoMise), "shellcheck = \"0.11.0\"") {
		t.Fatalf("repo mise.toml tool pins were not updated")
	}
	if !strings.Contains(mustReadFile(t, tplMise), "github.com/daixiang0/gci@v0.13.7") {
		t.Fatalf("template mise.toml go module pins were not updated")
	}
	if !strings.Contains(mustReadFile(t, repoBootstrap), "url=\"https://new.example/mamba\"") {
		t.Fatalf("repo bootstrap script was not updated")
	}
	if !strings.Contains(mustReadFile(t, tplBootstrap), "sha256=\"mise-sha\"") {
		t.Fatalf("template bootstrap script was not updated")
	}
	if !strings.Contains(mustReadFile(t, repoPre), "# updated-by-fake-pre-commit") {
		t.Fatalf("repo pre-commit config was not updated by fake pre-commit")
	}
	if !strings.Contains(mustReadFile(t, tplPre), "# updated-by-fake-pre-commit") {
		t.Fatalf("template pre-commit config was not updated by fake pre-commit")
	}
}
