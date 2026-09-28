package updaters

import (
	"path/filepath"
	"strings"
	"testing"

	"github-bootstrap/tools/pkg/toolinglib"
)

func TestRunPythonRespectsScopeAndUpdatesExactPins(t *testing.T) {
	root := t.TempDir()
	repoProject := filepath.Join(root, "pyproject.toml")
	templateProject := filepath.Join(root, "templates", "languages", "agnostic", "pyproject.toml")
	project := "dev = [\n  \"zizmor==1.30.0\",\n  \"ruff\",\n]\n"
	mustWriteFile(t, repoProject, project)
	mustWriteFile(t, templateProject, project)
	versions := toolinglib.Versions{Python: map[string]string{"zizmor": "1.30.1"}}

	changed, err := RunPython(root, "repo", versions, true)
	if err != nil {
		t.Fatalf("RunPython repo failed: %v", err)
	}
	if !containsAll(changed, repoProject) || len(changed) != 1 {
		t.Fatalf("repo scope changed unexpected files: %v", changed)
	}
	if !strings.Contains(mustReadFile(t, repoProject), `"zizmor==1.30.1"`) {
		t.Fatalf("repo project was not updated")
	}
	if !strings.Contains(mustReadFile(t, templateProject), `"zizmor==1.30.0"`) {
		t.Fatalf("repo scope changed template project")
	}

	changed, err = RunPython(root, "templates", versions, true)
	if err != nil {
		t.Fatalf("RunPython templates failed: %v", err)
	}
	if !containsAll(changed, templateProject) || len(changed) != 1 {
		t.Fatalf("template scope changed unexpected files: %v", changed)
	}
	if !strings.Contains(mustReadFile(t, templateProject), `"zizmor==1.30.1"`) {
		t.Fatalf("template project was not updated")
	}
}
