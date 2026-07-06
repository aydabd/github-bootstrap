package toolinglib

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"regexp"
	"strings"
	"time"
)

// MiseToolSource maps mise.toml tool keys to their conda-forge package names.
// Tool value in TOML is a plain version string (e.g. python = "3.13.1").
// Add new entries here to extend runtime version management to new languages.
var MiseToolSource = map[string]string{
	"python":     "python",
	"node":       "nodejs",
	"go":         "go",
	"rust":       "rust",
	"ruby":       "ruby",
	"shellcheck": "shellcheck",
	"shfmt":      "go-shfmt",
	"terraform":  "terraform",
	"taplo":      "taplo",
}

// MisePrefixedToolSource maps mise.toml tool keys whose value carries a
// non-version prefix to their conda-forge package names.
// Example: java = "temurin-21" — prefix "temurin-" is preserved, only the
// numeric version part is updated.
// Add new entries here for languages with prefixed mise version strings.
var MisePrefixedToolSource = map[string]struct {
	CondaPackage string
	Prefix       string
}{
	"java": {CondaPackage: "openjdk", Prefix: "temurin-"},
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
		pattern := fmt.Sprintf(`(?m)(^\s*-\s*%s=)([^ \n#]+)`, regexp.QuoteMeta(pkg))
		re, err := regexp.Compile(pattern)
		if err != nil {
			return "", err
		}
		next := re.ReplaceAllStringFunc(updated, func(match string) string {
			sub := re.FindStringSubmatch(match)
			if len(sub) != 3 {
				return match
			}
			// Keep template placeholders intact in template provider files.
			if strings.Contains(sub[2], "{{") {
				return match
			}
			return sub[1] + version
		})
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

func UpdateTOMLAssignmentIfPresent(text string, key string, value string) (string, error) {
	pattern := fmt.Sprintf(`(?m)(^\s*%s\s*=\s*")([^"]+)("\s*$)`, regexp.QuoteMeta(key))
	re, err := regexp.Compile(pattern)
	if err != nil {
		return "", err
	}
	if !re.MatchString(text) {
		return text, nil
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

func HasTOMLAssignment(text string, key string) (bool, error) {
	pattern := fmt.Sprintf(`(?m)^\s*%s\s*=\s*"[^"]+"\s*$`, regexp.QuoteMeta(key))
	re, err := regexp.Compile(pattern)
	if err != nil {
		return false, err
	}
	return re.MatchString(text), nil
}

func parseProviderKey(key string) (string, string, string, error) {
	parts := strings.Split(key, ":")
	if len(parts) != 3 {
		return "", "", "", fmt.Errorf("invalid provider asset key: %s", key)
	}
	return parts[0], parts[1], parts[2], nil
}

func UpdateProviderAssetManifestText(text string, providerData map[string]ProviderAsset) (string, error) {
	updated := text
	for key, values := range providerData {
		provider, osName, arch, err := parseProviderKey(key)
		if err != nil {
			return "", err
		}
		pattern := fmt.Sprintf(`(?m)^%s\s+%s\s+%s\s+\S+\s+\S+\s*$`, regexp.QuoteMeta(provider), regexp.QuoteMeta(osName), regexp.QuoteMeta(arch))
		re, err := regexp.Compile(pattern)
		if err != nil {
			return "", err
		}
		if !re.MatchString(updated) {
			return "", fmt.Errorf("expected pattern not found: %s", pattern)
		}
		replacement := fmt.Sprintf("%s %s %s %s %s", provider, osName, arch, values.URL, values.SHA256)
		updated = re.ReplaceAllStringFunc(updated, func(_ string) string {
			return replacement
		})
	}
	return updated, nil
}

func UpdateMiseText(text string, envVersions map[string]string, pythonVersions map[string]string, npmVersions map[string]string, goVersions map[string]string) (string, error) {
	updated := text

	// Plain version tools: mise key → conda package, e.g. python = "3.13.1"
	for miseKey, condaSource := range MiseToolSource {
		hasKey, err := HasTOMLAssignment(updated, miseKey)
		if err != nil {
			return "", err
		}
		if !hasKey {
			continue
		}
		value, ok := envVersions[condaSource]
		if !ok || strings.TrimSpace(value) == "" {
			// Version not collected (e.g. runtime-only template with placeholder) — skip.
			continue
		}
		next, err := UpdateTOMLAssignmentIfPresent(updated, miseKey, value)
		if err != nil {
			return "", err
		}
		updated = next
	}

	// Prefixed version tools: mise key → conda package with a preserved prefix,
	// e.g. java = "temurin-21" — only the numeric portion is updated.
	for miseKey, spec := range MisePrefixedToolSource {
		version, ok := envVersions[spec.CondaPackage]
		if !ok || strings.TrimSpace(version) == "" {
			continue
		}
		pattern := fmt.Sprintf(`(?m)(^\s*%s\s*=\s*"%s)([^"]+)("\s*$)`, regexp.QuoteMeta(miseKey), regexp.QuoteMeta(spec.Prefix))
		re, err := regexp.Compile(pattern)
		if err != nil {
			return "", err
		}
		if !re.MatchString(updated) {
			continue
		}
		updated = re.ReplaceAllStringFunc(updated, func(match string) string {
			sub := re.FindStringSubmatch(match)
			if len(sub) != 4 {
				return match
			}
			if strings.Contains(sub[2], "{{") {
				return match
			}
			return sub[1] + version + sub[3]
		})
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

// RunPreCommitAutoupdate runs "pre-commit autoupdate" on each config via a temp
// copy, preventing partial writes to the originals on failure. When write is
// false (dry-run) the originals are not modified; the returned list still
// contains every config that would have changed.
func RunPreCommitAutoupdate(configs []string, write bool) ([]string, error) {
	if err := EnsureCommandAvailable("pre-commit"); err != nil {
		return nil, err
	}
	changed := make([]string, 0)
	for _, config := range configs {
		original, err := os.ReadFile(config)
		if err != nil {
			return changed, err
		}

		tmp, err := os.CreateTemp("", "pre-commit-autoupdate-*.yaml")
		if err != nil {
			return changed, err
		}
		tmpPath := tmp.Name()
		if _, err := tmp.Write(original); err != nil {
			_ = tmp.Close()
			_ = os.Remove(tmpPath)
			return changed, err
		}
		if err := tmp.Close(); err != nil {
			_ = os.Remove(tmpPath)
			return changed, err
		}

		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
		cmd := exec.CommandContext(ctx, "pre-commit", "autoupdate", "--config", tmpPath)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		runErr := cmd.Run()
		cancel()

		if runErr != nil {
			_ = os.Remove(tmpPath)
			return changed, runErr
		}

		updated, err := os.ReadFile(tmpPath)
		_ = os.Remove(tmpPath)
		if err != nil {
			return changed, err
		}

		if bytes.Equal(original, updated) {
			continue
		}
		changed = append(changed, config)
		if write {
			mode := os.FileMode(0o644)
			if info, err := os.Stat(config); err == nil {
				mode = info.Mode().Perm()
			}
			if err := os.WriteFile(config, updated, mode); err != nil {
				return changed, err
			}
		}
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
