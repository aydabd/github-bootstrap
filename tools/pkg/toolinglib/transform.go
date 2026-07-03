package toolinglib

import (
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
)

var MiseToolSource = map[string]string{
	"shellcheck": "shellcheck",
	"shfmt":      "go-shfmt",
	"terraform":  "terraform",
	"taplo":      "taplo",
}

var PipVersionPatterns = map[string]string{
	"pre-commit":           `pre-commit==[0-9A-Za-z.\-]+`,
	"editorconfig-checker": `editorconfig-checker==[0-9A-Za-z.\-]+`,
	"yamllint":             `yamllint==[0-9A-Za-z.\-]+`,
}

var NPMVersionPatterns = map[string]string{
	"prettier":         `prettier@[0-9A-Za-z.\-]+`,
	"markdownlint-cli": `markdownlint-cli@[0-9A-Za-z.\-]+`,
}

var GoVersionPatterns = map[string]string{
	"github.com/daixiang0/gci":                            `github.com/daixiang0/gci@[0-9A-Za-z.\-]+`,
	"github.com/golangci/golangci-lint/cmd/golangci-lint": `github.com/golangci/golangci-lint/cmd/golangci-lint@[0-9A-Za-z.\-]+`,
}

func EnsureCommandAvailable(command string) error {
	if _, err := exec.LookPath(command); err != nil {
		return fmt.Errorf("missing required command: %s", command)
	}
	return nil
}

func UpdateFile(path string, updater func(string) (string, error), write bool) (bool, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return false, err
	}
	original := string(payload)
	updated, err := updater(original)
	if err != nil {
		return false, err
	}
	if updated == original {
		return false, nil
	}
	if write {
		if err := os.WriteFile(path, []byte(updated), 0o644); err != nil {
			return false, err
		}
	}
	return true, nil
}

func ReplaceOrFail(pattern string, replacement string, text string) (string, error) {
	re, err := regexp.Compile(pattern)
	if err != nil {
		return "", err
	}
	if !re.MatchString(text) {
		return "", fmt.Errorf("expected pattern not found: %s", pattern)
	}
	return re.ReplaceAllString(text, replacement), nil
}

func UpdateEnvText(text string, versions map[string]string) (string, error) {
	updated := text
	for pkg, version := range versions {
		pattern := fmt.Sprintf(`(?m)(^\s*-\s*%s=)[^ \n#]+`, regexp.QuoteMeta(pkg))
		replacement := fmt.Sprintf(`${1}%s`, version)
		next, err := ReplaceOrFail(pattern, replacement, updated)
		if err != nil {
			return "", err
		}
		updated = next
	}
	return updated, nil
}

func UpdateTOMLAssignment(text string, key string, value string) (string, error) {
	pattern := fmt.Sprintf(`(?m)(^\s*%s\s*=\s*")([^"]+)("\s*$)`, regexp.QuoteMeta(key))
	re, err := regexp.Compile(pattern)
	if err != nil {
		return "", err
	}
	if !re.MatchString(text) {
		return "", fmt.Errorf("expected TOML key not found: %s", key)
	}
	updated := re.ReplaceAllStringFunc(text, func(match string) string {
		sub := re.FindStringSubmatch(match)
		if len(sub) != 4 {
			return match
		}
		if strings.Contains(sub[2], "{{") {
			return match
		}
		return sub[1] + value + sub[3]
	})
	return updated, nil
}

func UpdateBootstrapScriptText(text string, providerData map[string]ProviderAsset) (string, error) {
	updated := text
	for key, values := range providerData {
		caseLabel := regexp.QuoteMeta(key)
		pattern := fmt.Sprintf(`(%s\)\n\s*url=")[^"]+("\n\s*sha256=")[^"]+(")`, caseLabel)
		replacement := fmt.Sprintf(`${1}%s${2}%s${3}`, values.URL, values.SHA256)
		next, err := ReplaceOrFail(pattern, replacement, updated)
		if err != nil {
			return "", err
		}
		updated = next
	}
	return updated, nil
}

func UpdateMiseText(text string, envVersions map[string]string, pythonVersions map[string]string, npmVersions map[string]string, goVersions map[string]string) (string, error) {
	updated := text
	for miseKey, condaSource := range MiseToolSource {
		next, err := UpdateTOMLAssignment(updated, miseKey, envVersions[condaSource])
		if err != nil {
			return "", err
		}
		updated = next
	}

	replacements := make([][2]string, 0)
	for pkg, pattern := range PipVersionPatterns {
		replacements = append(replacements, [2]string{pattern, fmt.Sprintf("%s==%s", pkg, pythonVersions[pkg])})
	}
	for pkg, pattern := range NPMVersionPatterns {
		replacements = append(replacements, [2]string{pattern, fmt.Sprintf("%s@%s", pkg, npmVersions[pkg])})
	}
	if goVersions != nil {
		for pkg, pattern := range GoVersionPatterns {
			replacements = append(replacements, [2]string{pattern, fmt.Sprintf("%s@%s", pkg, goVersions[pkg])})
		}
	}

	out := updated
	for _, pair := range replacements {
		next, err := ReplaceOrFail(pair[0], pair[1], out)
		if err != nil {
			return "", err
		}
		out = next
	}
	return out, nil
}

func RunPreCommitAutoupdate(configs []string) error {
	if err := EnsureCommandAvailable("pre-commit"); err != nil {
		return err
	}
	for _, config := range configs {
		cmd := exec.Command("pre-commit", "autoupdate", "--config", config)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			return err
		}
	}
	return nil
}

func FilterProviderAssets(providerAssets map[string]ProviderAsset, prefix string) map[string]ProviderAsset {
	out := make(map[string]ProviderAsset)
	for key, value := range providerAssets {
		if strings.HasPrefix(key, prefix) {
			out[key] = value
		}
	}
	return out
}
