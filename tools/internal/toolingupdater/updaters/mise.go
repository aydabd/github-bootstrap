package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunMise(root string, scope string, versions toolinglib.Versions, write bool) ([]string, error) {
	changed := make([]string, 0)
	providerAssets := toolinglib.FilterProviderAssets(versions.Providers, "mise:")

	if scope == "repo" || scope == "all" {
		ok, err := toolinglib.UpdateFile(filepath.Join(root, "mise.toml"), func(content string) (string, error) {
			return toolinglib.UpdateMiseText(content, versions.Conda, versions.Python, versions.NPM, nil)
		}, write)
		if err != nil {
			return nil, err
		}
		if ok {
			changed = append(changed, filepath.Join(root, "mise.toml"))
		}
		ok, err = toolinglib.UpdateFile(filepath.Join(root, "scripts", "bootstrap-provider-binary.sh"), func(content string) (string, error) {
			return toolinglib.UpdateBootstrapScriptText(content, providerAssets)
		}, write)
		if err != nil {
			return nil, err
		}
		if ok {
			changed = append(changed, filepath.Join(root, "scripts", "bootstrap-provider-binary.sh"))
		}
	}

	if scope == "templates" || scope == "all" {
		templates, err := toolinglib.DiscoverTemplateFiles(root)
		if err != nil {
			return nil, err
		}
		for _, miseFile := range templates.MiseFiles {
			ok, err := toolinglib.UpdateFile(miseFile, func(content string) (string, error) {
				return toolinglib.UpdateMiseText(content, versions.Conda, versions.Python, versions.NPM, versions.GoModules)
			}, write)
			if err != nil {
				return nil, err
			}
			if ok {
				changed = append(changed, miseFile)
			}
		}
		ok, err := toolinglib.UpdateFile(filepath.Join(root, "templates", "scripts", "bootstrap-provider-binary.sh"), func(content string) (string, error) {
			return toolinglib.UpdateBootstrapScriptText(content, providerAssets)
		}, write)
		if err != nil {
			return nil, err
		}
		if ok {
			changed = append(changed, filepath.Join(root, "templates", "scripts", "bootstrap-provider-binary.sh"))
		}
	}

	return changed, nil
}
