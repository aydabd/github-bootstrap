package toolinglib

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"slices"
	"strings"
)

type UpdateMetadata struct {
	Package    string   `json:"package"`
	OldVersion string   `json:"old_version"`
	NewVersion string   `json:"new_version"`
	UpdateType string   `json:"update_type"`
	Risk       string   `json:"risk"`
	Files      []string `json:"files"`
}

type UpdateMetadataDocument struct {
	SchemaVersion int              `json:"schema_version"`
	Updates       []UpdateMetadata `json:"updates"`
}

var (
	envPinPattern          = regexp.MustCompile(`^\s*-\s*([A-Za-z0-9_.-]+)=([^\s#]+)`)
	tomlPinPattern         = regexp.MustCompile(`^\s*([A-Za-z0-9_.-]+)\s*=\s*"([^"]+)"\s*$`)
	pipPinPattern          = regexp.MustCompile(`([A-Za-z0-9_.-]+)==([0-9][A-Za-z0-9_.-]*)`)
	npmPinPattern          = regexp.MustCompile(`([A-Za-z0-9_.-]+)@([0-9][A-Za-z0-9_.-]*)`)
	goPinPattern           = regexp.MustCompile(`([A-Za-z0-9_./-]+)@(v?[0-9][A-Za-z0-9_.-]*)`)
	providerPinPattern     = regexp.MustCompile(`^(mise|micromamba)\s+(linux|macos)\s+(x64|arm64)\s+(\S+)\s+\S+\s*$`)
	providerVersionPattern = regexp.MustCompile(`/download/(v?[0-9][^/]+)/`)
	repoPattern            = regexp.MustCompile(`^\s*-\s*repo:\s*(\S+)\s*$`)
	revPattern             = regexp.MustCompile(`^\s*rev:\s*(\S+)\s*$`)
)

// WriteUpdateMetadata compares changed files with HEAD and writes stable JSON
// metadata. It is intentionally based on the checked-out diff, so it describes
// exactly what will be committed rather than only what a remote lookup planned.
func WriteUpdateMetadata(root string, changed []string, outputPath string, explicitBreaking bool) error {
	metadata, err := CollectUpdateMetadata(root, changed, explicitBreaking)
	if err != nil {
		return err
	}
	if existing, readErr := readUpdateMetadata(outputPath); readErr == nil {
		metadata = mergeMetadata(existing.Updates, metadata)
	} else if !os.IsNotExist(readErr) {
		return fmt.Errorf("read existing update metadata: %w", readErr)
	}
	payload, err := json.MarshalIndent(UpdateMetadataDocument{SchemaVersion: 1, Updates: metadata}, "", "  ")
	if err != nil {
		return err
	}
	payload = append(payload, '\n')
	if err := os.WriteFile(outputPath, payload, 0o600); err != nil {
		return fmt.Errorf("write update metadata: %w", err)
	}
	return nil
}

func CollectUpdateMetadata(root string, changed []string, explicitBreaking bool) ([]UpdateMetadata, error) {
	byKey := map[string]*UpdateMetadata{}
	for _, absolutePath := range changed {
		relativePath := absolutePath
		if filepath.IsAbs(absolutePath) {
			relativePath, err = filepath.Rel(root, absolutePath)
			if err != nil {
				return nil, err
			}
		}
		absolutePath = filepath.Join(root, relativePath)
		oldContent, err := gitShowHead(root, relativePath)
		if err != nil {
			return nil, err
		}
		newContent, err := os.ReadFile(absolutePath)
		if err != nil {
			return nil, err
		}
		collectPinChanges(byKey, relativePath, oldContent, string(newContent), explicitBreaking)
	}
	result := make([]UpdateMetadata, 0, len(byKey))
	for _, item := range byKey {
		result = append(result, *item)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Package != result[j].Package {
			return result[i].Package < result[j].Package
		}
		if result[i].OldVersion != result[j].OldVersion {
			return result[i].OldVersion < result[j].OldVersion
		}
		if result[i].NewVersion != result[j].NewVersion {
			return result[i].NewVersion < result[j].NewVersion
		}
		return strings.Join(result[i].Files, "\x00") < strings.Join(result[j].Files, "\x00")
	})
	for index := range result {
		sort.Strings(result[index].Files)
	}
	return result, nil
}

func readUpdateMetadata(path string) (UpdateMetadataDocument, error) {
	payload, err := os.ReadFile(path)
	if err != nil {
		return UpdateMetadataDocument{}, err
	}
	var document UpdateMetadataDocument
	if err := json.Unmarshal(payload, &document); err != nil {
		return UpdateMetadataDocument{}, err
	}
	if document.SchemaVersion != 1 {
		return UpdateMetadataDocument{}, fmt.Errorf("unsupported metadata schema version: %d", document.SchemaVersion)
	}
	return document, nil
}

func mergeMetadata(existing []UpdateMetadata, current []UpdateMetadata) []UpdateMetadata {
	merged := map[string]UpdateMetadata{}
	for _, update := range append(existing, current...) {
		key := update.Package + "\x00" + update.OldVersion + "\x00" + update.NewVersion
		previous, ok := merged[key]
		if !ok {
			merged[key] = update
			continue
		}
		files := append(previous.Files, update.Files...)
		sort.Strings(files)
		files = slices.Compact(files)
		previous.Files = files
		merged[key] = previous
	}
	result := make([]UpdateMetadata, 0, len(merged))
	for _, update := range merged {
		result = append(result, update)
	}
	sort.Slice(result, func(i, j int) bool {
		if result[i].Package != result[j].Package {
			return result[i].Package < result[j].Package
		}
		if result[i].OldVersion != result[j].OldVersion {
			return result[i].OldVersion < result[j].OldVersion
		}
		return result[i].NewVersion < result[j].NewVersion
	})
	return result
}

func gitShowHead(root string, path string) (string, error) {
	command := exec.Command("git", "-C", root, "show", "HEAD:"+path)
	output, err := command.Output()
	if err != nil {
		return "", fmt.Errorf("read HEAD version of %s: %w", path, err)
	}
	return string(output), nil
}

func collectPinChanges(byKey map[string]*UpdateMetadata, path string, oldContent string, newContent string, explicitBreaking bool) {
	oldPins := extractPins(oldContent)
	newPins := extractPins(newContent)
	for packageName, oldVersion := range oldPins {
		newVersion, ok := newPins[packageName]
		if !ok || oldVersion == newVersion {
			continue
		}
		classification := ClassifyUpdate(oldVersion, newVersion, explicitBreaking)
		key := packageName + "\x00" + oldVersion + "\x00" + newVersion
		if existing, ok := byKey[key]; ok {
			existing.Files = append(existing.Files, path)
			continue
		}
		byKey[key] = &UpdateMetadata{
			Package: packageName, OldVersion: oldVersion, NewVersion: newVersion,
			UpdateType: classification.UpdateType, Risk: classification.Risk, Files: []string{path},
		}
	}
}

func extractPins(content string) map[string]string {
	pins := map[string]string{}
	scanner := bufio.NewScanner(strings.NewReader(content))
	var currentRepo string
	for scanner.Scan() {
		line := scanner.Text()
		if match := envPinPattern.FindStringSubmatch(line); match != nil {
			pins[match[1]] = match[2]
			continue
		}
		if match := tomlPinPattern.FindStringSubmatch(line); match != nil {
			pins[match[1]] = match[2]
			continue
		}
		if match := repoPattern.FindStringSubmatch(line); match != nil {
			currentRepo = match[1]
			continue
		}
		if match := revPattern.FindStringSubmatch(line); match != nil && currentRepo != "" {
			pins[currentRepo] = match[1]
			continue
		}
		if match := providerPinPattern.FindStringSubmatch(line); match != nil {
			version := match[4]
			if versionMatch := providerVersionPattern.FindStringSubmatch(version); versionMatch != nil {
				version = versionMatch[1]
			}
			pins[match[1]+":"+match[2]+":"+match[3]] = version
			continue
		}
		for _, match := range pipPinPattern.FindAllStringSubmatch(line, -1) {
			pins[match[1]] = match[2]
		}
		for _, match := range npmPinPattern.FindAllStringSubmatch(line, -1) {
			pins[match[1]] = match[2]
		}
		for _, match := range goPinPattern.FindAllStringSubmatch(line, -1) {
			pins[match[1]] = match[2]
		}
	}
	return pins
}
