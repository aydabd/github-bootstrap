package toolinglib

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
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
	mode := os.FileMode(0o644)
	if info, err := os.Stat(path); err == nil {
		mode = info.Mode().Perm()
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
		if err := os.WriteFile(path, []byte(updated), mode); err != nil {
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

func ReplaceIfPresent(pattern string, replacement string, text string) (string, bool, error) {
	re, err := regexp.Compile(pattern)
	if err != nil {
		return "", false, err
	}
	if !re.MatchString(text) {
		return text, false, nil
	}
	return re.ReplaceAllString(text, replacement), true, nil
}

func requireVersion(versions map[string]string, key string, source string) (string, error) {
	value, ok := versions[key]
	if !ok || strings.TrimSpace(value) == "" {
		return "", fmt.Errorf("missing %s version for %s", source, key)
	}
	return value, nil
}

func UpdateEnvText(text string, versions map[string]string) (string, error) {
	updated := text
	for pkg, version := range versions {
		pattern := fmt.Sprintf(`(?m)(^\s*-\s*%s=)[^ \n#]+`, regexp.QuoteMeta(pkg))
		replacement := fmt.Sprintf(`${1}%s`, version)
		next, _, err := ReplaceIfPresent(pattern, replacement, updated)
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
		value, err := requireVersion(envVersions, condaSource, "conda")
		if err != nil {
			return "", fmt.Errorf("missing conda version for %s (source %s)", miseKey, condaSource)
		}
		next, err := UpdateTOMLAssignment(updated, miseKey, value)
		if err != nil {
			return "", err
		}
		updated = next
	}

	replacements := make([][2]string, 0)
	for pkg, pattern := range PipVersionPatterns {
		value, err := requireVersion(pythonVersions, pkg, "python")
		if err != nil {
			return "", err
		}
		replacements = append(replacements, [2]string{pattern, fmt.Sprintf("%s==%s", pkg, value)})
	}
	for pkg, pattern := range NPMVersionPatterns {
		value, err := requireVersion(npmVersions, pkg, "npm")
		if err != nil {
			return "", err
		}
		replacements = append(replacements, [2]string{pattern, fmt.Sprintf("%s@%s", pkg, value)})
	}
	if goVersions != nil {
		for pkg, pattern := range GoVersionPatterns {
			value, err := requireVersion(goVersions, pkg, "go")
			if err != nil {
				return "", err
			}
			replacement := fmt.Sprintf("%s@%s", pkg, value)
			next, _, err := ReplaceIfPresent(pattern, replacement, updated)
			if err != nil {
				return "", err
			}
			updated = next
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

func fileSHA256(path string) (string, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	digest := sha256.Sum256(payload)
	return hex.EncodeToString(digest[:]), nil
}

func RunPreCommitAutoupdate(configs []string) ([]string, error) {
	if err := EnsureCommandAvailable("pre-commit"); err != nil {
		return nil, err
	}
	changed := make([]string, 0)
	for _, config := range configs {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		beforeHash, err := fileSHA256(config)
		if err != nil {
			cancel()
			return nil, err
		}
		cmd := exec.CommandContext(ctx, "pre-commit", "autoupdate", "--config", config)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			cancel()
			return nil, err
		}
		afterHash, err := fileSHA256(config)
		if err != nil {
			cancel()
			return nil, err
		}
		if beforeHash != afterHash {
			changed = append(changed, config)
		}
		cancel()
	}
	return changed, nil
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
