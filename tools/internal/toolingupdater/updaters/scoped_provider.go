package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

type scopedProviderConfig struct {
	repoFile       string
	templateFiles  []string
	repoUpdate     func(string) (string, error)
	templateUpdate func(string) (string, error)
	providerAssets map[string]toolinglib.ProviderAsset
}

func runScopedProviderUpdater(root string, scope string, write bool, cfg scopedProviderConfig) ([]string, error) {
	changed := make([]string, 0)

	if scope == "repo" || scope == "all" {
		repoPath := filepath.Join(root, cfg.repoFile)
		ok, err := toolinglib.UpdateFile(repoPath, cfg.repoUpdate, write)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, repoPath)
		}

		repoProviderAssets := filepath.Join(root, "scripts", "provider-assets.txt")
		ok, err = toolinglib.UpdateFile(repoProviderAssets, func(content string) (string, error) {
			return toolinglib.UpdateProviderAssetManifestText(content, cfg.providerAssets)
		}, write)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, repoProviderAssets)
		}
	}

	if scope == "templates" || scope == "all" {
		for _, templateFile := range cfg.templateFiles {
			ok, err := toolinglib.UpdateFile(templateFile, cfg.templateUpdate, write)
			if err != nil {
				return changed, err
			}
			if ok {
				changed = append(changed, templateFile)
			}
		}

		templateProviderAssets := filepath.Join(root, "templates", "scripts", "provider-assets.txt")
		ok, err := toolinglib.UpdateFile(templateProviderAssets, func(content string) (string, error) {
			return toolinglib.UpdateProviderAssetManifestText(content, cfg.providerAssets)
		}, write)
		if err != nil {
			return changed, err
		}
		if ok {
			changed = append(changed, templateProviderAssets)
		}
	}

	return changed, nil
}
