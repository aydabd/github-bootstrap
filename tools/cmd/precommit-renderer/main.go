package main

import (
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

const (
	placeholderExclude = "{{EXCLUDE_BLOCK}}"
	placeholderHooks   = "{{LANGUAGE_HOOKS}}"
)

var supportedLanguages = []string{"golang", "python", "typescript", "java"}

type config struct {
	basePath       string
	snippetsRoot   string
	languagesInput string
	emitLanguages  string
	outputPath     string
	emitDir        string
}

func main() {
	cfg, err := parseFlags()
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(2)
	}
	if err := run(cfg); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func parseFlags() (config, error) {
	var cfg config
	flag.StringVar(&cfg.basePath, "base", "", "Path to agnostic base pre-commit template")
	flag.StringVar(&cfg.snippetsRoot, "snippets-root", "", "Path to templates/languages directory")
	flag.StringVar(&cfg.languagesInput, "languages", "", "Comma-separated language list")
	flag.StringVar(&cfg.emitLanguages, "emit-languages", "", "Optional comma-separated language list used for per-language outputs")
	flag.StringVar(&cfg.outputPath, "output", "", "Output .pre-commit-config.yaml path")
	flag.StringVar(&cfg.emitDir, "emit-language-files-dir", "", "Optional output dir for per-language configs")
	flag.Parse()

	if cfg.basePath == "" || cfg.snippetsRoot == "" || cfg.outputPath == "" {
		return config{}, errors.New("--base, --snippets-root, and --output are required")
	}
	return cfg, nil
}

func run(cfg config) error {
	if strings.TrimSpace(cfg.emitLanguages) != "" && strings.TrimSpace(cfg.emitDir) == "" {
		return errors.New("--emit-languages requires --emit-language-files-dir")
	}

	langs, err := normalizeLanguages(cfg.languagesInput)
	if err != nil {
		return err
	}
	emitLangs := langs
	if strings.TrimSpace(cfg.emitLanguages) != "" {
		emitLangs, err = normalizeLanguages(cfg.emitLanguages)
		if err != nil {
			return err
		}
	}

	content, err := renderConfig(cfg.basePath, cfg.snippetsRoot, langs)
	if err != nil {
		return err
	}
	if err := writeFile(cfg.outputPath, content); err != nil {
		return err
	}

	if cfg.emitDir != "" {
		if err := os.MkdirAll(cfg.emitDir, 0o755); err != nil {
			return fmt.Errorf("create language config dir: %w", err)
		}
		for _, lang := range emitLangs {
			if lang == "agnostic" {
				continue
			}
			single, err := renderConfig(cfg.basePath, cfg.snippetsRoot, []string{lang})
			if err != nil {
				return err
			}
			file := filepath.Join(cfg.emitDir, lang+".yaml")
			if err := writeFile(file, single); err != nil {
				return err
			}
		}
	}

	return nil
}

func normalizeLanguages(input string) ([]string, error) {
	trimmed := strings.TrimSpace(input)
	if trimmed == "" || trimmed == "language-agnostic-only" {
		return []string{"agnostic"}, nil
	}

	if trimmed == "all" {
		return append([]string{}, supportedLanguages...), nil
	}

	raw := strings.Split(trimmed, ",")
	seen := map[string]bool{}
	langs := make([]string, 0, len(raw))
	hasAll := false
	hasAgnostic := false

	for _, item := range raw {
		normalized := normalizeAlias(item)
		if normalized == "" {
			continue
		}
		if normalized == "all" {
			hasAll = true
			continue
		}
		if normalized == "agnostic" {
			hasAgnostic = true
		}
		if !seen[normalized] {
			langs = append(langs, normalized)
			seen[normalized] = true
		}
	}

	if hasAll {
		if hasAgnostic {
			return nil, errors.New("language-agnostic-only cannot be combined with other languages")
		}
		return append([]string{}, supportedLanguages...), nil
	}

	if len(langs) == 0 {
		return []string{"agnostic"}, nil
	}

	for _, lang := range langs {
		if lang == "agnostic" {
			if len(langs) == 1 {
				return langs, nil
			}
			return nil, errors.New("language-agnostic-only cannot be combined with other languages")
		}
	}

	return langs, nil
}

func normalizeAlias(value string) string {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case "language-agnostic-only", "agnostic":
		return "agnostic"
	case "go", "golang":
		return "golang"
	case "python":
		return "python"
	case "typescript", "javascript", "node", "nodejs":
		return "typescript"
	case "java", "kotlin":
		return "java"
	case "all":
		return "all"
	default:
		return ""
	}
}

func renderConfig(basePath, snippetsRoot string, languages []string) (string, error) {
	baseBytes, err := os.ReadFile(basePath)
	if err != nil {
		return "", fmt.Errorf("read base template: %w", err)
	}
	base := string(baseBytes)

	excludeBlock, hooksBlock, err := collectSnippets(snippetsRoot, languages)
	if err != nil {
		return "", err
	}

	rendered := strings.ReplaceAll(base, placeholderExclude, indentBlock(excludeBlock, "    "))
	rendered = strings.ReplaceAll(rendered, placeholderHooks, indentBlock(hooksBlock, "      "))
	return rendered, nil
}

func collectSnippets(snippetsRoot string, languages []string) (string, string, error) {
	excludes := make([]string, 0)
	hooks := make([]string, 0)
	seenExclude := map[string]bool{}

	for _, lang := range languages {
		if lang == "agnostic" {
			continue
		}
		exPath := filepath.Join(snippetsRoot, lang, "pre-commit-snippets", "exclude-block.txt")
		hkPath := filepath.Join(snippetsRoot, lang, "pre-commit-snippets", "language-hooks.txt")

		exData, err := os.ReadFile(exPath)
		if err != nil {
			return "", "", fmt.Errorf("read exclude snippet for %s: %w", lang, err)
		}
		hkData, err := os.ReadFile(hkPath)
		if err != nil {
			return "", "", fmt.Errorf("read hooks snippet for %s: %w", lang, err)
		}

		for _, line := range strings.Split(strings.TrimSuffix(string(exData), "\n"), "\n") {
			line = strings.TrimRight(line, " ")
			if line == "" || seenExclude[line] {
				continue
			}
			seenExclude[line] = true
			excludes = append(excludes, line)
		}
		hooks = append(hooks, strings.TrimSuffix(string(hkData), "\n"))
	}

	excludeBlock := ""
	if len(excludes) > 0 {
		excludeBlock = strings.Join(excludes, "\n") + "\n"
	}

	hooksBlock := ""
	if len(hooks) > 0 {
		hooksBlock = strings.Join(hooks, "\n") + "\n"
	}

	return excludeBlock, hooksBlock, nil
}

func writeFile(path, content string) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return fmt.Errorf("create parent dir for %s: %w", path, err)
	}
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}

func indentBlock(input, prefix string) string {
	if strings.TrimSpace(input) == "" {
		return ""
	}
	trimmed := strings.TrimSuffix(input, "\n")
	lines := strings.Split(trimmed, "\n")
	for i, line := range lines {
		if strings.TrimSpace(line) == "" {
			lines[i] = ""
			continue
		}
		lines[i] = prefix + line
	}
	return strings.Join(lines, "\n") + "\n"
}
