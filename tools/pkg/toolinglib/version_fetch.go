package toolinglib

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	userAgent          = "github-bootstrap-tooling-updater"
	httpTimeoutSeconds = 60
	httpRetries        = 3
	hashChunkSize      = 1024 * 1024
)

var condaPackages = []string{
	"pre-commit",
	"prettier",
	"markdownlint-cli",
	"yamllint",
	"taplo",
	"go-shfmt",
	"shellcheck",
	"libxml2",
	"terraform",
	"jq",
	"coreutils",
}

func githubAPIToken() string {
	if token := strings.TrimSpace(os.Getenv("GH_TOKEN")); token != "" {
		return token
	}
	if token := strings.TrimSpace(os.Getenv("GITHUB_TOKEN")); token != "" {
		return token
	}
	return ""
}

func newRequest(rawURL string, acceptJSON bool) (*http.Request, error) {
	req, err := http.NewRequest(http.MethodGet, rawURL, nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("User-Agent", userAgent)
	if acceptJSON {
		req.Header.Set("Accept", "application/json")
	}
	if strings.HasPrefix(rawURL, "https://api.github.com/") {
		if token := githubAPIToken(); token != "" {
			req.Header.Set("Authorization", "Bearer "+token)
		}
	}
	return req, nil
}

func readURLBytes(rawURL string, timeoutSeconds int) ([]byte, error) {
	client := &http.Client{Timeout: time.Duration(timeoutSeconds) * time.Second}
	var lastErr error
	for range httpRetries {
		req, err := newRequest(rawURL, true)
		if err != nil {
			return nil, err
		}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		body, readErr := io.ReadAll(resp.Body)
		closeErr := resp.Body.Close()
		if readErr != nil {
			lastErr = readErr
			continue
		}
		if closeErr != nil {
			lastErr = closeErr
			continue
		}
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			lastErr = fmt.Errorf("http status %d for %s", resp.StatusCode, rawURL)
			continue
		}
		return body, nil
	}
	return nil, fmt.Errorf("failed to fetch URL after retries: %s: %w", rawURL, lastErr)
}

func httpGetJSON(rawURL string) (map[string]any, error) {
	payload, err := readURLBytes(rawURL, httpTimeoutSeconds)
	if err != nil {
		return nil, err
	}
	var decoded map[string]any
	if err := json.Unmarshal(payload, &decoded); err != nil {
		return nil, err
	}
	return decoded, nil
}

func fetchSHA256(rawURL string) (string, error) {
	client := &http.Client{Timeout: 120 * time.Second}
	var lastErr error
	for range httpRetries {
		req, err := newRequest(rawURL, false)
		if err != nil {
			return "", err
		}
		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}
		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			lastErr = fmt.Errorf("http status %d for %s", resp.StatusCode, rawURL)
			_ = resp.Body.Close()
			continue
		}
		hasher := sha256.New()
		buffer := make([]byte, hashChunkSize)
		for {
			count, readErr := resp.Body.Read(buffer)
			if count > 0 {
				if _, err := hasher.Write(buffer[:count]); err != nil {
					lastErr = err
					_ = resp.Body.Close()
					break
				}
			}
			if readErr == io.EOF {
				if closeErr := resp.Body.Close(); closeErr != nil {
					lastErr = closeErr
					break
				}
				return hex.EncodeToString(hasher.Sum(nil)), nil
			}
			if readErr != nil {
				lastErr = readErr
				_ = resp.Body.Close()
				break
			}
		}
	}
	return "", fmt.Errorf("failed to fetch binary for checksum after retries: %s: %w", rawURL, lastErr)
}

func latestCondaVersion(pkg string) (string, error) {
	encoded := url.PathEscape(pkg)
	data, err := httpGetJSON("https://api.anaconda.org/package/conda-forge/" + encoded)
	if err != nil {
		return "", err
	}
	version, ok := data["latest_version"].(string)
	if !ok || version == "" {
		return "", fmt.Errorf("unable to resolve conda-forge latest version for %s", pkg)
	}
	return version, nil
}

func latestPyPIVersion(pkg string) (string, error) {
	encoded := url.PathEscape(pkg)
	data, err := httpGetJSON("https://pypi.org/pypi/" + encoded + "/json")
	if err != nil {
		return "", err
	}
	info, ok := data["info"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("unable to parse PyPI response for %s", pkg)
	}
	version, ok := info["version"].(string)
	if !ok || version == "" {
		return "", fmt.Errorf("unable to resolve PyPI latest version for %s", pkg)
	}
	return version, nil
}

func latestNPMVersion(pkg string) (string, error) {
	encoded := strings.ReplaceAll(url.PathEscape(pkg), "%2F", "/")
	data, err := httpGetJSON("https://registry.npmjs.org/" + encoded)
	if err != nil {
		return "", err
	}
	distTags, ok := data["dist-tags"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("unable to parse npm response for %s", pkg)
	}
	version, ok := distTags["latest"].(string)
	if !ok || version == "" {
		return "", fmt.Errorf("unable to resolve npm latest version for %s", pkg)
	}
	return version, nil
}

func latestGoModuleVersion(module string) (string, error) {
	encoded := strings.ReplaceAll(url.PathEscape(module), "%2F", "/")
	data, err := httpGetJSON("https://proxy.golang.org/" + encoded + "/@latest")
	if err != nil {
		return "", err
	}
	version, ok := data["Version"].(string)
	if !ok || version == "" {
		return "", fmt.Errorf("unable to resolve Go module latest version for %s", module)
	}
	return version, nil
}

func latestGitHubReleaseTag(repo string) (string, error) {
	data, err := httpGetJSON("https://api.github.com/repos/" + repo + "/releases/latest")
	if err != nil {
		return "", err
	}
	tag, ok := data["tag_name"].(string)
	if !ok || tag == "" {
		return "", fmt.Errorf("unable to resolve latest GitHub release tag for %s", repo)
	}
	return tag, nil
}

func CollectVersions(selectedUpdaters []string) (Versions, error) {
	needsMicromamba := false
	needsMise := false
	for _, updater := range selectedUpdaters {
		if updater == "micromamba" {
			needsMicromamba = true
		}
		if updater == "mise" {
			needsMise = true
		}
	}
	if !needsMicromamba && !needsMise {
		needsMicromamba = true
		needsMise = true
	}

	conda := make(map[string]string)
	for _, pkg := range condaPackages {
		v, err := latestCondaVersion(pkg)
		if err != nil {
			return Versions{}, err
		}
		conda[pkg] = v
	}

	python := map[string]string{}
	npm := map[string]string{}
	goModules := map[string]string{}
	if needsMise {
		for _, pkg := range []string{"pre-commit", "editorconfig-checker", "yamllint"} {
			v, err := latestPyPIVersion(pkg)
			if err != nil {
				return Versions{}, err
			}
			python[pkg] = v
		}

		for _, pkg := range []string{"prettier", "markdownlint-cli"} {
			v, err := latestNPMVersion(pkg)
			if err != nil {
				return Versions{}, err
			}
			npm[pkg] = v
		}

		for _, module := range []string{"github.com/daixiang0/gci", "github.com/golangci/golangci-lint/cmd/golangci-lint"} {
			v, err := latestGoModuleVersion(module)
			if err != nil {
				return Versions{}, err
			}
			goModules[module] = v
		}
	}

	providerURLs := map[string]string{}
	if needsMise {
		miseTag, err := latestGitHubReleaseTag("jdx/mise")
		if err != nil {
			return Versions{}, err
		}
		providerURLs["mise:linux:x64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-linux-x64"
		providerURLs["mise:linux:arm64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-linux-arm64"
		providerURLs["mise:macos:x64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-macos-x64"
		providerURLs["mise:macos:arm64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-macos-arm64"
	}
	if needsMicromamba {
		micromambaTag, err := latestGitHubReleaseTag("mamba-org/micromamba-releases")
		if err != nil {
			return Versions{}, err
		}
		providerURLs["micromamba:linux:x64"] = "https://github.com/mamba-org/micromamba-releases/releases/download/" + micromambaTag + "/micromamba-linux-64"
		providerURLs["micromamba:linux:arm64"] = "https://github.com/mamba-org/micromamba-releases/releases/download/" + micromambaTag + "/micromamba-linux-aarch64"
		providerURLs["micromamba:macos:x64"] = "https://github.com/mamba-org/micromamba-releases/releases/download/" + micromambaTag + "/micromamba-osx-64"
		providerURLs["micromamba:macos:arm64"] = "https://github.com/mamba-org/micromamba-releases/releases/download/" + micromambaTag + "/micromamba-osx-arm64"
	}

	providers := map[string]ProviderAsset{}
	for key, rawURL := range providerURLs {
		digest, err := fetchSHA256(rawURL)
		if err != nil {
			return Versions{}, err
		}
		providers[key] = ProviderAsset{URL: rawURL, SHA256: digest}
	}

	return Versions{Conda: conda, Python: python, NPM: npm, GoModules: goModules, Providers: providers}, nil
}
