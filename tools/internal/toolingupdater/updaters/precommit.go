package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunPreCommit(root string, scope string, write bool) ([]string, error) {
	if !write {
		return []string{}, nil
	}

	changed := make([]string, 0)
	if scope == "repo" || scope == "all" {
		config := filepath.Join(root, ".pre-commit-config.yaml")
		changedConfigs, err := toolinglib.RunPreCommitAutoupdate([]string{config})
		if err != nil {
			return nil, err
		}
		changed = append(changed, changedConfigs...)
	}
	if scope == "templates" || scope == "all" {
		templates, err := toolinglib.DiscoverTemplateFiles(root)
		if err != nil {
			return nil, err
		}
		changedConfigs, err := toolinglib.RunPreCommitAutoupdate(templates.PreCommitFiles)
		if err != nil {
			return nil, err
		}
		changed = append(changed, changedConfigs...)
	}
	return changed, nil
}
