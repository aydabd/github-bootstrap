package bootstrapinputs

import (
	"errors"
	"fmt"
	"regexp"
	"sort"
	"strings"
)

var (
	pythonVersionPattern = regexp.MustCompile(`^[0-9]+(\.[0-9]+){1,2}$`)
	nodeVersionPattern   = regexp.MustCompile(`^[0-9]+$`)
	goVersionPattern     = regexp.MustCompile(`^[0-9]+(\.[0-9]+){1,2}$`)
	javaVersionPattern   = regexp.MustCompile(`^[0-9]+$`)
)

var canonicalLanguages = []string{"golang", "python", "typescript", "java"}

var codeQLAllLanguages = []string{
	"javascript-typescript",
	"python",
	"java-kotlin",
	"csharp",
	"go",
	"ruby",
	"cpp",
}

var codeQLLanguageMap = map[string]string{
	"javascript": "javascript-typescript",
	"typescript": "javascript-typescript",
	"node":       "javascript-typescript",
	"nodejs":     "javascript-typescript",
	"python":     "python",
	"java":       "java-kotlin",
	"kotlin":     "java-kotlin",
	"go":         "go",
	"golang":     "go",
	"csharp":     "csharp",
	"cpp":        "cpp",
	"ruby":       "ruby",
}

func NormalizeLanguagesStrict(input string) ([]string, error) {
	return normalizeLanguages(input, true)
}

func NormalizeLanguagesPermissive(input string) ([]string, error) {
	return normalizeLanguages(input, false)
}

func normalizeLanguages(input string, strictUnknown bool) ([]string, error) {
	trimmed := strings.TrimSpace(input)
	if strings.EqualFold(trimmed, "language-agnostic-only") || strings.EqualFold(trimmed, "agnostic") {
		return []string{"agnostic"}, nil
	}
	if trimmed == "" {
		if strictUnknown {
			return nil, fmt.Errorf("no valid language tokens in %q", input)
		}
		return []string{"agnostic"}, nil
	}

	parts := strings.Split(trimmed, ",")
	seen := map[string]bool{}
	result := make([]string, 0, len(parts))
	hasAgnostic := false
	hasAll := false

	for _, part := range parts {
		canonical, err := canonicalToken(part)
		if err != nil {
			if strictUnknown {
				return nil, err
			}
			continue
		}
		if canonical == "all" {
			hasAll = true
			continue
		}
		if canonical == "agnostic" {
			hasAgnostic = true
		}
		if !seen[canonical] {
			seen[canonical] = true
			result = append(result, canonical)
		}
	}

	if hasAll {
		if hasAgnostic {
			return nil, fmt.Errorf("language-agnostic-only cannot be combined with other languages")
		}
		return append([]string{}, canonicalLanguages...), nil
	}

	if len(result) == 0 {
		if strictUnknown {
			return nil, fmt.Errorf("no valid language tokens in %q", input)
		}
		return []string{"agnostic"}, nil
	}

	if hasAgnostic && len(result) > 1 {
		return nil, fmt.Errorf("language-agnostic-only cannot be combined with other languages")
	}

	return result, nil
}

func canonicalToken(raw string) (string, error) {
	token := strings.ToLower(strings.TrimSpace(raw))
	switch token {
	case "":
		return "", fmt.Errorf("unknown language token %q", raw)
	case "language-agnostic-only", "agnostic":
		return "agnostic", nil
	case "all":
		return "all", nil
	case "go", "golang":
		return "golang", nil
	case "python":
		return "python", nil
	case "typescript", "javascript", "node", "nodejs":
		return "typescript", nil
	case "java", "kotlin":
		return "java", nil
	default:
		return "", fmt.Errorf("unknown language token %q", token)
	}
}

func RootLanguageDir(languagesInput string) string {
	first := strings.ToLower(strings.TrimSpace(strings.Split(languagesInput, ",")[0]))
	switch first {
	case "all", "language-agnostic-only", "agnostic":
		return "agnostic"
	case "python":
		return "python"
	case "go", "golang":
		return "golang"
	case "typescript", "javascript", "node", "nodejs":
		return "typescript"
	case "java", "kotlin":
		return "java"
	default:
		return "agnostic"
	}
}

func ReleaseTypeForFirstToken(languagesInput string) string {
	first := strings.ToLower(strings.TrimSpace(strings.Split(languagesInput, ",")[0]))
	switch first {
	case "javascript", "typescript", "node", "nodejs":
		return "node"
	case "python":
		return "python"
	case "go", "golang":
		return "go"
	case "rust":
		return "rust"
	case "java", "kotlin":
		return "java"
	case "ruby":
		return "ruby"
	case "php":
		return "php"
	case "terraform":
		return "terraform-module"
	default:
		return "simple"
	}
}

func CodeQLLanguages(languagesInput string) []string {
	trimmed := strings.ToLower(strings.TrimSpace(languagesInput))
	if trimmed == "all" {
		return append([]string{}, codeQLAllLanguages...)
	}
	if trimmed == "language-agnostic-only" || trimmed == "agnostic" || trimmed == "" {
		return nil
	}

	parts := strings.Split(trimmed, ",")
	seen := map[string]bool{}
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		mapped, ok := codeQLLanguageMap[strings.TrimSpace(part)]
		if !ok || seen[mapped] {
			continue
		}
		seen[mapped] = true
		result = append(result, mapped)
	}
	return result
}

func ValidateRuntimePins(pythonVersion, nodeVersion, goVersion, javaVersion string) error {
	problems := make([]string, 0, 4)
	if !pythonVersionPattern.MatchString(strings.TrimSpace(pythonVersion)) {
		problems = append(problems, fmt.Sprintf("invalid python_version %q", pythonVersion))
	}
	if !nodeVersionPattern.MatchString(strings.TrimSpace(nodeVersion)) {
		problems = append(problems, fmt.Sprintf("invalid node_version %q", nodeVersion))
	}
	if !goVersionPattern.MatchString(strings.TrimSpace(goVersion)) {
		problems = append(problems, fmt.Sprintf("invalid go_version %q", goVersion))
	}
	if !javaVersionPattern.MatchString(strings.TrimSpace(javaVersion)) {
		problems = append(problems, fmt.Sprintf("invalid java_version %q", javaVersion))
	}
	if len(problems) == 0 {
		return nil
	}
	sort.Strings(problems)
	return errors.New(strings.Join(problems, "; "))
}
