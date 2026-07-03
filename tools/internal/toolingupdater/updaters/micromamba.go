package updaters

import (
	"github-bootstrap/tools/pkg/toolinglib"
)

func RunMicromamba(root string, scope string, versions toolinglib.Versions, write bool) ([]string, error) {
	templates, err := toolinglib.DiscoverTemplateFiles(root)
	if err != nil {
		return nil, err
	}

	providerAssets := toolinglib.FilterProviderAssets(versions.Providers, "micromamba:")

	return runScopedProviderUpdater(root, scope, write, scopedProviderConfig{
		repoFile:      "environment.yml",
		templateFiles: templates.EnvFiles,
		repoUpdate: func(content string) (string, error) {
			return toolinglib.UpdateEnvText(content, versions.Conda)
		},
		templateUpdate: func(content string) (string, error) {
			return toolinglib.UpdateEnvText(content, versions.Conda)
		},
		providerAssets: providerAssets,
	})
}
