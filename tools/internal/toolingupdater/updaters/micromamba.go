package updaters

import (
	"path/filepath"

	"github-bootstrap/tools/pkg/toolinglib"
)

func RunMicromamba(root string, scope string, versions toolinglib.Versions, write bool) ([]string, error) {
	changed := make([]string, 0)
	providerAssets := toolinglib.FilterProviderAssets(versions.Providers, "micromamba:")

	if scope == "repo" || scope == "all" {
		ok, err := toolinglib.UpdateFile(filepath.Join(root, "environment.yml"), func(content string) (string, error) {
			return toolinglib.UpdateEnvText(content, versions.Conda)
		}, write)
		if err != nil {
			return nil, err
		}
		if ok {
			changed = append(changed, filepath.Join(root, "environment.yml"))
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
		for _, envFile := range templates.EnvFiles {
			ok, err := toolinglib.UpdateFile(envFile, func(content string) (string, error) {
				return toolinglib.UpdateEnvText(content, versions.Conda)
			}, write)
			if err != nil {
				return nil, err
			}
			if ok {
				changed = append(changed, envFile)
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
