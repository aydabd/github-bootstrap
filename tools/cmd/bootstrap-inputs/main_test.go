package main

import (
	"reflect"
	"strings"
	"testing"
)

func TestParseFlags(t *testing.T) {
	cfg, err := parseFlags([]string{"--mode", "normalize", "--languages", "python,go"})
	if err != nil {
		t.Fatalf("parseFlags failed: %v", err)
	}
	if cfg.mode != "normalize" || cfg.languages != "python,go" {
		t.Fatalf("unexpected parse result: %+v", cfg)
	}
}

func TestParseFlagsInvalidMode(t *testing.T) {
	_, err := parseFlags([]string{"--mode", "other", "--languages", "python"})
	if err == nil {
		t.Fatal("expected mode error, got nil")
	}
}

func TestRunNormalize(t *testing.T) {
	result, err := run(config{mode: "normalize", languages: "go,node,kotlin"})
	if err != nil {
		t.Fatalf("run failed: %v", err)
	}
	if !result.Valid {
		t.Fatal("expected valid result")
	}
	wantLanguages := []string{"golang", "typescript", "java"}
	if !reflect.DeepEqual(result.Languages, wantLanguages) {
		t.Fatalf("languages mismatch: got %v want %v", result.Languages, wantLanguages)
	}
	if result.RootLanguage != "golang" {
		t.Fatalf("unexpected root language: %s", result.RootLanguage)
	}
	if result.ReleaseType != "go" {
		t.Fatalf("unexpected release type: %s", result.ReleaseType)
	}
}

func TestRunValidateRuntimePins(t *testing.T) {
	_, err := run(config{
		mode:          "validate",
		languages:     "python",
		pythonVersion: "3",
		nodeVersion:   "24",
		goVersion:     "1.26",
		javaVersion:   "25",
	})
	if err == nil {
		t.Fatal("expected runtime pin error, got nil")
	}
	if !strings.Contains(err.Error(), "python_version") {
		t.Fatalf("unexpected runtime validation error: %v", err)
	}
}
