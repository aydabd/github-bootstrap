package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunPreCommit(root string, scope string, write bool) ([]string, error) {
	changed := make([]string, 0)
	if scope == "repo" || scope == "all" {
		config := filepath.Join(root, ".pre-commit-config.yaml")
		changed = append(changed, config)
		if write {
			if err := toolinglib.RunPreCommitAutoupdate([]string{config}); err != nil {
				return nil, err
			}
		}
	}
	if scope == "templates" || scope == "all" {
		templates, err := toolinglib.DiscoverTemplateFiles(root)
		if err != nil {
			return nil, err
		}
		changed = append(changed, templates.PreCommitFiles...)
		if write {
			if err := toolinglib.RunPreCommitAutoupdate(templates.PreCommitFiles); err != nil {
				return nil, err
			}
		}
	}
	return changed, nil
}
