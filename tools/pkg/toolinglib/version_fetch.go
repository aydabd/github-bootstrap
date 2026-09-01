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
	"regexp"
	"sort"
	"strings"
	"time"
)

const (
	userAgent          = "github-bootstrap-tooling-updater"
	httpTimeoutSeconds = 60
	httpRetries        = 3
	hashChunkSize      = 1024 * 1024
)

// condaRuntimePackages lists language runtime packages fetched from conda-forge.
// Add new language runtimes here — UpdateEnvText will pick them up automatically
// for any env file that contains a matching pin. For mise.toml keys, also add a
// mapping in MiseToolSource / MisePrefixedToolSource.
var condaRuntimePackages = []string{
	"python",
	"go",
	"nodejs",
	"openjdk",
	"rust",
	"ruby",
}

var condaToolPackages = []string{
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

func allCondaPackages() []string {
	packages := make([]string, 0, len(condaRuntimePackages)+len(condaToolPackages))
	packages = append(packages, condaRuntimePackages...)
	packages = append(packages, condaToolPackages...)
	return packages
}

func retryBackoff(attempt int) {
	if attempt <= 0 {
		return
	}
	delay := time.Second * time.Duration(1<<uint(attempt-1))
	if delay > 8*time.Second {
		delay = 8 * time.Second
	}
	time.Sleep(delay)
}

func githubAPIToken() string {
	for _, name := range []string{EnvGitHubTokenPrimary, EnvGitHubTokenFallback} {
		if value := strings.TrimSpace(os.Getenv(name)); value != "" {
			return value
		}
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
	for attempt := range httpRetries {
		retryBackoff(attempt)
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
	for attempt := range httpRetries {
		retryBackoff(attempt)
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

// stableVersionPattern matches plain numeric dotted releases such as "3.14.7".
// It deliberately rejects pre-releases like "3.15.0rc1", "3.15.0a7" or
// "3.15.0b4": conda-forge only serves those under separate labels, so pinning
// one breaks `micromamba create` against the default channel.
var stableVersionPattern = regexp.MustCompile(`^[0-9]+(?:\.[0-9]+)*$`)

// releaseCandidate pairs a version string with the earliest time it was
// published upstream. A zero released time means the publish time is unknown.
type releaseCandidate struct {
	version  string
	released time.Time
}

// cooldownCutoff converts a cooldown window in days into an absolute cutoff
// time. A non-positive value disables the cooldown and yields the zero time.
func cooldownCutoff(days int) time.Time {
	if days <= 0 {
		return time.Time{}
	}
	return time.Now().UTC().AddDate(0, 0, -days)
}

// parsePublishTime parses the timestamp formats the upstream version APIs
// return. It yields the zero time for an empty or unrecognised value.
func parsePublishTime(value string) time.Time {
	value = strings.TrimSpace(value)
	if value == "" {
		return time.Time{}
	}
	for _, layout := range []string{
		time.RFC3339Nano,
		time.RFC3339,
		"2006-01-02 15:04:05.999999-07:00", // anaconda.org files[].upload_time
		"2006-01-02 15:04:05-07:00",
	} {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed.UTC()
		}
	}
	return time.Time{}
}

// newestEligibleVersion returns the greatest plain-numeric release whose publish
// time is at or before cutoff, ignoring pre-releases. A zero cutoff disables the
// age filter. It returns "" when no candidate qualifies.
func newestEligibleVersion(candidates []releaseCandidate, cutoff time.Time) string {
	best := ""
	for _, candidate := range candidates {
		version := strings.TrimSpace(candidate.version)
		if !stableVersionPattern.MatchString(version) {
			continue
		}
		if !cutoff.IsZero() && (candidate.released.IsZero() || candidate.released.After(cutoff)) {
			continue
		}
		if best == "" || compareNumericVersions(version, best) > 0 {
			best = version
		}
	}
	return best
}

func noEligibleReleaseError(source, pkg string, cutoff time.Time) error {
	if cutoff.IsZero() {
		return fmt.Errorf("%s has no stable release for %s", source, pkg)
	}
	return fmt.Errorf("%s has no stable release for %s older than the cooldown window (cutoff %s)",
		source, pkg, cutoff.Format(time.RFC3339))
}

func latestCondaVersion(pkg string, cutoff time.Time) (string, error) {
	encoded := url.PathEscape(pkg)
	data, err := httpGetJSON("https://api.anaconda.org/package/conda-forge/" + encoded)
	if err != nil {
		return "", err
	}
	earliest := map[string]time.Time{}
	if files, ok := data["files"].([]any); ok {
		for _, raw := range files {
			file, ok := raw.(map[string]any)
			if !ok {
				continue
			}
			version := strings.TrimSpace(asString(file["version"]))
			uploaded := parsePublishTime(asString(file["upload_time"]))
			if version == "" || uploaded.IsZero() {
				continue
			}
			if existing, seen := earliest[version]; !seen || uploaded.Before(existing) {
				earliest[version] = uploaded
			}
		}
	}
	var candidates []releaseCandidate
	if rawVersions, ok := data["versions"].([]any); ok {
		for _, item := range rawVersions {
			version := strings.TrimSpace(asString(item))
			if version == "" {
				continue
			}
			candidates = append(candidates, releaseCandidate{version: version, released: earliest[version]})
		}
	}
	if picked := newestEligibleVersion(candidates, cutoff); picked != "" {
		return picked, nil
	}
	return "", noEligibleReleaseError("conda-forge", pkg, cutoff)
}

func asString(value any) string {
	text, _ := value.(string)
	return text
}

// compareNumericVersions compares two dotted numeric versions component by
// component, treating missing trailing components as zero. It returns a
// negative, zero, or positive value when a sorts before, equal to, or after b.
func compareNumericVersions(a, b string) int {
	aParts := strings.Split(a, ".")
	bParts := strings.Split(b, ".")
	limit := max(len(aParts), len(bParts))
	for index := range limit {
		aNumber := 0
		if index < len(aParts) {
			aNumber = parseVersionPart(aParts[index])
		}
		bNumber := 0
		if index < len(bParts) {
			bNumber = parseVersionPart(bParts[index])
		}
		if aNumber != bNumber {
			return aNumber - bNumber
		}
	}
	return 0
}

func latestPyPIVersion(pkg string, cutoff time.Time) (string, error) {
	encoded := url.PathEscape(pkg)
	data, err := httpGetJSON("https://pypi.org/pypi/" + encoded + "/json")
	if err != nil {
		return "", err
	}
	releases, ok := data["releases"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("unable to parse PyPI response for %s", pkg)
	}
	var candidates []releaseCandidate
	for version, raw := range releases {
		files, ok := raw.([]any)
		if !ok || len(files) == 0 {
			continue // removed or artifact-less release
		}
		var earliest time.Time
		hasUsableFile := false
		for _, entry := range files {
			file, ok := entry.(map[string]any)
			if !ok {
				continue
			}
			if isYanked, _ := file["yanked"].(bool); isYanked {
				continue
			}
			hasUsableFile = true
			uploaded := parsePublishTime(asString(file["upload_time_iso_8601"]))
			if uploaded.IsZero() {
				continue
			}
			if earliest.IsZero() || uploaded.Before(earliest) {
				earliest = uploaded
			}
		}
		if !hasUsableFile {
			continue // every file yanked
		}
		candidates = append(candidates, releaseCandidate{version: version, released: earliest})
	}
	if picked := newestEligibleVersion(candidates, cutoff); picked != "" {
		return picked, nil
	}
	return "", noEligibleReleaseError("PyPI", pkg, cutoff)
}

func latestNPMVersion(pkg string, cutoff time.Time) (string, error) {
	encoded := strings.ReplaceAll(url.PathEscape(pkg), "%2F", "/")
	data, err := httpGetJSON("https://registry.npmjs.org/" + encoded)
	if err != nil {
		return "", err
	}
	versions, ok := data["versions"].(map[string]any)
	if !ok {
		return "", fmt.Errorf("unable to parse npm response for %s", pkg)
	}
	published, _ := data["time"].(map[string]any)
	var candidates []releaseCandidate
	for version := range versions {
		candidates = append(candidates, releaseCandidate{
			version:  version,
			released: parsePublishTime(asString(published[version])),
		})
	}
	if picked := newestEligibleVersion(candidates, cutoff); picked != "" {
		return picked, nil
	}
	return "", noEligibleReleaseError("npm", pkg, cutoff)
}

func latestGoModuleVersion(module string, cutoff time.Time) (string, error) {
	encoded := strings.ReplaceAll(url.PathEscape(module), "%2F", "/")
	latest, err := httpGetJSON("https://proxy.golang.org/" + encoded + "/@latest")
	if err != nil {
		return "", err
	}
	latestVersion := asString(latest["Version"])
	latestTime := parsePublishTime(asString(latest["Time"]))
	if latestVersion == "" {
		return "", fmt.Errorf("unable to resolve Go module latest version for %s", module)
	}
	if cutoff.IsZero() || (!latestTime.IsZero() && !latestTime.After(cutoff)) {
		return latestVersion, nil
	}
	// The newest tag is inside the cooldown window; walk the tag list newest
	// first and return the first release old enough.
	body, err := readURLBytes("https://proxy.golang.org/"+encoded+"/@v/list", httpTimeoutSeconds)
	if err != nil {
		return "", err
	}
	tags := strings.Fields(string(body))
	sort.Slice(tags, func(i, j int) bool {
		return compareNumericVersions(
			strings.TrimPrefix(tags[i], "v"),
			strings.TrimPrefix(tags[j], "v"),
		) > 0
	})
	for _, tag := range tags {
		if strings.Contains(tag, "-") { // skip pseudo-versions / pre-releases
			continue
		}
		info, infoErr := httpGetJSON("https://proxy.golang.org/" + encoded + "/@v/" + url.PathEscape(tag) + ".info")
		if infoErr != nil {
			continue
		}
		released := parsePublishTime(asString(info["Time"]))
		if !released.IsZero() && !released.After(cutoff) {
			return tag, nil
		}
	}
	return "", noEligibleReleaseError("Go proxy", module, cutoff)
}

func latestGitHubReleaseTag(repo string, cutoff time.Time) (string, error) {
	if cutoff.IsZero() {
		data, err := httpGetJSON("https://api.github.com/repos/" + repo + "/releases/latest")
		if err != nil {
			return "", err
		}
		tag := asString(data["tag_name"])
		if tag == "" {
			return "", fmt.Errorf("unable to resolve latest GitHub release tag for %s", repo)
		}
		return tag, nil
	}
	// Releases come back newest first. Fast-moving projects (e.g. jdx/mise ships
	// several times a week) can have more than one page of releases inside the
	// cooldown window, so walk pages until an eligible release is found or the
	// history is exhausted.
	const perPage, maxPages = 100, 20
	for page := 1; page <= maxPages; page++ {
		body, err := readURLBytes(fmt.Sprintf(
			"https://api.github.com/repos/%s/releases?per_page=%d&page=%d", repo, perPage, page),
			httpTimeoutSeconds)
		if err != nil {
			return "", err
		}
		var releases []struct {
			TagName     string `json:"tag_name"`
			Draft       bool   `json:"draft"`
			Prerelease  bool   `json:"prerelease"`
			PublishedAt string `json:"published_at"`
		}
		if err := json.Unmarshal(body, &releases); err != nil {
			return "", fmt.Errorf("unable to parse GitHub releases for %s: %w", repo, err)
		}
		if len(releases) == 0 {
			break
		}
		for _, release := range releases {
			if release.Draft || release.Prerelease || release.TagName == "" {
				continue
			}
			published := parsePublishTime(release.PublishedAt)
			if !published.IsZero() && !published.After(cutoff) {
				return release.TagName, nil
			}
		}
		if len(releases) < perPage {
			break
		}
	}
	return "", fmt.Errorf("GitHub repository %s has no published release older than the cooldown window (cutoff %s)",
		repo, cutoff.Format(time.RFC3339))
}

// CollectVersions resolves the newest eligible upstream version for every
// managed tool. cooldownDays skips releases published within that many days so a
// freshly cut (and potentially broken or yanked) release is not pinned
// immediately; pass 0 to disable the cooldown.
func CollectVersions(selectedUpdaters []string, cooldownDays int) (Versions, error) {
	cutoff := cooldownCutoff(cooldownDays)

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
	for _, pkg := range allCondaPackages() {
		v, err := latestCondaVersion(pkg, cutoff)
		if err != nil {
			return Versions{}, err
		}
		conda[pkg] = v
	}

	python := map[string]string{}
	npm := map[string]string{}
	goModules := map[string]string{}
	if needsMise {
		goModuleLookup := map[string]string{
			"github.com/daixiang0/gci":                            "github.com/daixiang0/gci",
			"github.com/golangci/golangci-lint/cmd/golangci-lint": "github.com/golangci/golangci-lint",
		}

		for _, pkg := range []string{"pre-commit", "editorconfig-checker", "yamllint"} {
			v, err := latestPyPIVersion(pkg, cutoff)
			if err != nil {
				return Versions{}, err
			}
			python[pkg] = v
		}

		for _, pkg := range []string{"prettier", "markdownlint-cli"} {
			v, err := latestNPMVersion(pkg, cutoff)
			if err != nil {
				return Versions{}, err
			}
			npm[pkg] = v
		}

		for replacementModule, lookupModule := range goModuleLookup {
			v, err := latestGoModuleVersion(lookupModule, cutoff)
			if err != nil {
				return Versions{}, err
			}
			goModules[replacementModule] = v
		}
	}

	providerURLs := map[string]string{}
	if needsMise {
		miseTag, err := latestGitHubReleaseTag("jdx/mise", cutoff)
		if err != nil {
			return Versions{}, err
		}
		providerURLs["mise:linux:x64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-linux-x64"
		providerURLs["mise:linux:arm64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-linux-arm64"
		providerURLs["mise:macos:x64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-macos-x64"
		providerURLs["mise:macos:arm64"] = "https://github.com/jdx/mise/releases/download/" + miseTag + "/mise-" + miseTag + "-macos-arm64"
	}
	if needsMicromamba {
		micromambaTag, err := latestGitHubReleaseTag("mamba-org/micromamba-releases", cutoff)
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
