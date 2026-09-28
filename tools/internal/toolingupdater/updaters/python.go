package updaters

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunPython(root string, scope string, versions toolinglib.Versions, write bool) ([]string, error) {
	if scope != "repo" && scope != "templates" && scope != "all" {
		return nil, fmt.Errorf("invalid scope: %s", scope)
	}

	projects := make([]string, 0, 1)
	if scope == "repo" || scope == "all" {
		projects = append(projects, filepath.Join(root, "pyproject.toml"))
	}
	if scope == "templates" || scope == "all" {
		templateProjects, err := filepath.Glob(filepath.Join(root, "templates", "languages", "*", "pyproject.toml"))
		if err != nil {
			return nil, err
		}
		projects = append(projects, templateProjects...)
	}
	sort.Strings(projects)

	changed := make([]string, 0, len(projects))
	for _, project := range projects {
		if _, err := os.Stat(project); err != nil {
			if os.IsNotExist(err) {
				return nil, fmt.Errorf("missing Python project: %s", project)
			}
			return nil, err
		}
		updated, err := toolinglib.UpdateFile(project, func(content string) (string, error) {
			return toolinglib.UpdatePythonProjectText(content, versions.Python)
		}, write)
		if err != nil {
			return nil, err
		}
		if updated {
			changed = append(changed, project)
		}
	}
	return changed, nil
}
