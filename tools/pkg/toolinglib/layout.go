package toolinglib

import (
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

func DiscoverTemplateFiles(root string) (TemplateFiles, error) {
	templatesRoot := filepath.Join(root, "templates")
	envFiles, err := filepath.Glob(filepath.Join(templatesRoot, "languages", "*", "providers", "micromamba", "environment.yml"))
	if err != nil {
		return TemplateFiles{}, err
	}
	miseFiles, err := filepath.Glob(filepath.Join(templatesRoot, "languages", "*", "providers", "mise", "mise.toml"))
	if err != nil {
		return TemplateFiles{}, err
	}
	preCommitFiles, err := filepath.Glob(filepath.Join(templatesRoot, "languages", "*", ".pre-commit-config.yaml"))
	if err != nil {
		return TemplateFiles{}, err
	}
	sort.Strings(envFiles)
	sort.Strings(miseFiles)
	sort.Strings(preCommitFiles)
	return TemplateFiles{EnvFiles: envFiles, MiseFiles: miseFiles, PreCommitFiles: preCommitFiles}, nil
}

func VerifyWorkspaceLayout(root string) error {
	requiredFiles := []string{
		filepath.Join(root, "environment.yml"),
		filepath.Join(root, "mise.toml"),
		filepath.Join(root, "scripts", "bootstrap-provider-binary.sh"),
		filepath.Join(root, ".pre-commit-config.yaml"),
		filepath.Join(root, "templates", "scripts", "bootstrap-provider-binary.sh"),
	}
	missing := make([]string, 0)
	for _, p := range requiredFiles {
		if _, err := os.Stat(p); err != nil {
			if os.IsNotExist(err) {
				rel, _ := filepath.Rel(root, p)
				missing = append(missing, rel)
			} else {
				return err
			}
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("workspace layout verification failed, missing files: %s", strings.Join(missing, ", "))
	}
	templateFiles, err := DiscoverTemplateFiles(root)
	if err != nil {
		return err
	}
	if len(templateFiles.EnvFiles) == 0 {
		return fmt.Errorf("workspace layout verification failed: no template micromamba environment.yml files found")
	}
	if len(templateFiles.MiseFiles) == 0 {
		return fmt.Errorf("workspace layout verification failed: no template mise.toml files found")
	}
	if len(templateFiles.PreCommitFiles) == 0 {
		return fmt.Errorf("workspace layout verification failed: no template .pre-commit-config.yaml files found")
	}
	return nil
}
