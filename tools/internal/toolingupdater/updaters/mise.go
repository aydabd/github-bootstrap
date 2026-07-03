package updaters

import (
	"github-bootstrap/tools/pkg/toolinglib"
)

func RunMise(root string, scope string, versions toolinglib.Versions, write bool) ([]string, error) {
	templates, err := toolinglib.DiscoverTemplateFiles(root)
	if err != nil {
		return nil, err
	}

	providerAssets := toolinglib.FilterProviderAssets(versions.Providers, "mise:")

	return runScopedProviderUpdater(root, scope, write, scopedProviderConfig{
		repoFile:      "mise.toml",
		templateFiles: templates.MiseFiles,
		repoUpdate: func(content string) (string, error) {
			return toolinglib.UpdateMiseText(content, versions.Conda, versions.Python, versions.NPM, nil)
		},
		templateUpdate: func(content string) (string, error) {
			return toolinglib.UpdateMiseText(content, versions.Conda, versions.Python, versions.NPM, versions.GoModules)
		},
		providerAssets: providerAssets,
	})
}
