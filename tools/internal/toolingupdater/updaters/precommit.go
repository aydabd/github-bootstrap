package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunPreCommit(root string, scope string, write bool) ([]string, error) {
	configs := make([]string, 0)
	if scope == "repo" || scope == "all" {
		configs = append(configs, filepath.Join(root, ".pre-commit-config.yaml"))
	}
	if scope == "templates" || scope == "all" {
		templates, err := toolinglib.DiscoverTemplateFiles(root)
		if err != nil {
			return nil, err
		}
		configs = append(configs, templates.PreCommitFiles...)
	}
	return toolinglib.RunPreCommitAutoupdate(configs, write)
}
