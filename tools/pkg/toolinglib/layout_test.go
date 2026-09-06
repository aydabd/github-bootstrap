package toolinglib

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDiscoverTemplateFilesIncludesMicromambaLockfiles(t *testing.T) {
	root := t.TempDir()
	providerDir := filepath.Join(root, "templates", "languages", "agnostic", "providers", "micromamba")
	if err := os.MkdirAll(providerDir, 0o755); err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"environment.yml", "conda-lock.yml"} {
		if err := os.WriteFile(filepath.Join(providerDir, name), []byte("content\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	files, err := DiscoverTemplateFiles(root)
	if err != nil {
		t.Fatal(err)
	}
	if len(files.EnvFiles) != 1 || len(files.CondaLockFiles) != 1 {
		t.Fatalf("expected one environment and one conda lock file, got %#v", files)
	}
	if filepath.Base(files.CondaLockFiles[0]) != "conda-lock.yml" {
		t.Fatalf("unexpected lockfile path: %s", files.CondaLockFiles[0])
	}
}

func TestVerifyWorkspaceLayoutRejectsUnpairedMicromambaEnvironment(t *testing.T) {
	root := t.TempDir()
	for _, name := range []string{
		"environment.yml",
		"mise.toml",
		"scripts/bootstrap-provider-binary.sh",
		"scripts/provider-assets.txt",
		".pre-commit-config.yaml",
		"templates/scripts/bootstrap-provider-binary.sh",
		"templates/scripts/provider-assets.txt",
	} {
		path := filepath.Join(root, name)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("content\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	providerDir := filepath.Join(root, "templates", "languages", "agnostic", "providers", "micromamba")
	miseDir := filepath.Join(root, "templates", "languages", "agnostic", "providers", "mise")
	preCommit := filepath.Join(root, "templates", "languages", "agnostic", ".pre-commit-config.yaml")
	for _, path := range []string{
		filepath.Join(providerDir, "environment.yml"),
		filepath.Join(miseDir, "mise.toml"),
		preCommit,
	} {
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, []byte("content\n"), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	if err := VerifyWorkspaceLayout(root); err == nil {
		t.Fatal("expected missing conda-lock.yml to fail layout verification")
	}
}
