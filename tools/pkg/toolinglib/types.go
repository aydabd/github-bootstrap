package toolinglib

type ProviderAsset struct {
	URL    string
	SHA256 string
}

type Versions struct {
	Conda     map[string]string
	Python    map[string]string
	NPM       map[string]string
	GoModules map[string]string
	Providers map[string]ProviderAsset
}

type TemplateFiles struct {
	EnvFiles       []string
	MiseFiles      []string
	PreCommitFiles []string
}
