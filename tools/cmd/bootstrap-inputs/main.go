package main

import (
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"

	"github-bootstrap/tools/pkg/bootstrapinputs"
)

type config struct {
	mode          string
	languages     string
	pythonVersion string
	nodeVersion   string
	goVersion     string
	javaVersion   string
}

type output struct {
	Mode         string   `json:"mode"`
	LanguagesRaw string   `json:"languages_raw,omitempty"`
	Languages    []string `json:"languages,omitempty"`
	RootLanguage string   `json:"root_language,omitempty"`
	ReleaseType  string   `json:"release_type,omitempty"`
	CodeQL       []string `json:"codeql_languages,omitempty"`
	Valid        bool     `json:"valid"`
	Message      string   `json:"message,omitempty"`
}

func main() {
	cfg, err := parseFlags(os.Args[1:])
	if err != nil {
		writeError(err)
		os.Exit(2)
	}
	result, err := run(cfg)
	if err != nil {
		writeError(err)
		os.Exit(1)
	}
	if err := json.NewEncoder(os.Stdout).Encode(result); err != nil {
		writeError(err)
		os.Exit(1)
	}
}

func parseFlags(args []string) (config, error) {
	fs := flag.NewFlagSet("bootstrap-inputs", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	fs.Usage = func() {}

	cfg := config{}
	fs.StringVar(&cfg.mode, "mode", "normalize", "mode: normalize or validate")
	fs.StringVar(&cfg.languages, "languages", "", "comma-separated languages")
	fs.StringVar(&cfg.pythonVersion, "python-version", "", "python runtime version")
	fs.StringVar(&cfg.nodeVersion, "node-version", "", "node runtime version")
	fs.StringVar(&cfg.goVersion, "go-version", "", "go runtime version")
	fs.StringVar(&cfg.javaVersion, "java-version", "", "java runtime version")

	if err := fs.Parse(args); err != nil {
		return config{}, err
	}
	if cfg.mode != "normalize" && cfg.mode != "validate" {
		return config{}, fmt.Errorf("unsupported mode %q", cfg.mode)
	}
	if cfg.languages == "" {
		return config{}, errors.New("--languages is required")
	}
	if cfg.mode == "validate" && (cfg.pythonVersion == "" || cfg.nodeVersion == "" || cfg.goVersion == "" || cfg.javaVersion == "") {
		return config{}, errors.New("--python-version, --node-version, --go-version, and --java-version are required in validate mode")
	}
	return cfg, nil
}

func run(cfg config) (output, error) {
	langs, err := bootstrapinputs.NormalizeLanguagesStrict(cfg.languages)
	if err != nil {
		return output{}, err
	}

	result := output{
		Mode:         cfg.mode,
		LanguagesRaw: cfg.languages,
		Languages:    langs,
		RootLanguage: bootstrapinputs.RootLanguageDir(cfg.languages),
		ReleaseType:  bootstrapinputs.ReleaseTypeForFirstToken(cfg.languages),
		CodeQL:       bootstrapinputs.CodeQLLanguages(cfg.languages),
		Valid:        true,
		Message:      "ok",
	}

	if cfg.mode == "validate" {
		if err := bootstrapinputs.ValidateRuntimePins(
			cfg.pythonVersion,
			cfg.nodeVersion,
			cfg.goVersion,
			cfg.javaVersion,
		); err != nil {
			return output{}, err
		}
	}

	return result, nil
}

func writeError(err error) {
	_ = json.NewEncoder(os.Stderr).Encode(output{
		Mode:    "error",
		Valid:   false,
		Message: err.Error(),
	})
}
