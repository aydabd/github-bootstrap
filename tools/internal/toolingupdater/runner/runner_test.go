package runner

import (
	"testing"
)

func TestRun_InvalidScope(t *testing.T) {
	_, err := Run(Config{
		Root:        t.TempDir(),
		Scope:       "invalid",
		UpdatersRaw: "pre-commit",
	})
	if err == nil {
		t.Fatal("expected error for invalid scope, got nil")
	}
}

func TestParseUpdaters_All(t *testing.T) {
	got, err := parseUpdaters("all")
	if err != nil {
		t.Fatalf("parseUpdaters(all) returned error: %v", err)
	}
	if len(got) != 4 {
		t.Fatalf("expected 4 updaters, got %d: %v", len(got), got)
	}
}

func TestParseUpdaters_Single(t *testing.T) {
	got, err := parseUpdaters("pre-commit")
	if err != nil {
		t.Fatalf("parseUpdaters(pre-commit) returned error: %v", err)
	}
	if len(got) != 1 || got[0] != "pre-commit" {
		t.Fatalf("expected [pre-commit], got %v", got)
	}
}

func TestParseUpdaters_Dedup(t *testing.T) {
	got, err := parseUpdaters("pre-commit,pre-commit")
	if err != nil {
		t.Fatalf("parseUpdaters dedup returned error: %v", err)
	}
	if len(got) != 1 {
		t.Fatalf("expected 1 entry after dedup, got %d: %v", len(got), got)
	}
}

func TestParseUpdaters_Unknown(t *testing.T) {
	_, err := parseUpdaters("bogus-updater")
	if err == nil {
		t.Fatal("expected error for unknown updater, got nil")
	}
}

func TestParseUpdaters_Empty(t *testing.T) {
	_, err := parseUpdaters("  ")
	if err == nil {
		t.Fatal("expected error for empty updater list, got nil")
	}
}
