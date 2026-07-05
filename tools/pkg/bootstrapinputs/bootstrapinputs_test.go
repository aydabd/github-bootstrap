package bootstrapinputs

import (
	"reflect"
	"strings"
	"testing"
)

func TestNormalizeLanguagesStrict(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		want    []string
		wantErr bool
	}{
		{name: "empty strict fails", input: "", wantErr: true},
		{name: "blank strict fails", input: "   ", wantErr: true},
		{name: "agnostic explicit", input: "language-agnostic-only", want: []string{"agnostic"}},
		{name: "alias mapping", input: "go,node,nodejs,kotlin", want: []string{"golang", "typescript", "java"}},
		{name: "all", input: "all", want: []string{"golang", "python", "typescript", "java"}},
		{name: "all mixed", input: "python,all", want: []string{"golang", "python", "typescript", "java"}},
		{name: "unknown token fails", input: "python,rust", wantErr: true},
		{name: "agnostic with others fails", input: "agnostic,go", wantErr: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := NormalizeLanguagesStrict(tt.input)
			if tt.wantErr {
				if err == nil {
					t.Fatal("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("NormalizeLanguagesStrict failed: %v", err)
			}
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("NormalizeLanguagesStrict mismatch: got %v want %v", got, tt.want)
			}
		})
	}
}

func TestNormalizeLanguagesPermissive(t *testing.T) {
	got, err := NormalizeLanguagesPermissive("unknown")
	if err != nil {
		t.Fatalf("NormalizeLanguagesPermissive failed: %v", err)
	}
	want := []string{"agnostic"}
	if !reflect.DeepEqual(got, want) {
		t.Fatalf("NormalizeLanguagesPermissive mismatch: got %v want %v", got, want)
	}
}

func TestRootLanguageDir(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{input: "all", want: "agnostic"},
		{input: "language-agnostic-only", want: "agnostic"},
		{input: "python,go", want: "python"},
		{input: "go,python", want: "golang"},
		{input: "node", want: "typescript"},
		{input: "kotlin", want: "java"},
		{input: "unknown", want: "agnostic"},
	}
	for _, tt := range tests {
		if got := RootLanguageDir(tt.input); got != tt.want {
			t.Fatalf("RootLanguageDir(%q) mismatch: got %q want %q", tt.input, got, tt.want)
		}
	}
}

func TestReleaseTypeForFirstToken(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{input: "typescript", want: "node"},
		{input: "node", want: "node"},
		{input: "nodejs", want: "node"},
		{input: "python", want: "python"},
		{input: "go", want: "go"},
		{input: "golang", want: "go"},
		{input: "kotlin", want: "java"},
		{input: "terraform", want: "terraform-module"},
		{input: "all", want: "simple"},
		{input: "language-agnostic-only", want: "simple"},
	}
	for _, tt := range tests {
		if got := ReleaseTypeForFirstToken(tt.input); got != tt.want {
			t.Fatalf("ReleaseTypeForFirstToken(%q) mismatch: got %q want %q", tt.input, got, tt.want)
		}
	}
}

func TestCodeQLLanguages(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  []string
	}{
		{name: "agnostic none", input: "language-agnostic-only", want: nil},
		{name: "all", input: "all", want: []string{"javascript-typescript", "python", "java-kotlin", "csharp", "go", "ruby", "cpp"}},
		{name: "golang alias", input: "golang", want: []string{"go"}},
		{name: "node alias", input: "node,nodejs,typescript", want: []string{"javascript-typescript"}},
		{name: "dedupe alias", input: "javascript,typescript,go", want: []string{"javascript-typescript", "go"}},
		{name: "unsupported removed", input: "python,rust", want: []string{"python"}},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := CodeQLLanguages(tt.input)
			if !reflect.DeepEqual(got, tt.want) {
				t.Fatalf("CodeQLLanguages mismatch: got %v want %v", got, tt.want)
			}
		})
	}
}

func TestValidateRuntimePins(t *testing.T) {
	if err := ValidateRuntimePins("3.13", "24", "1.26", "25"); err != nil {
		t.Fatalf("expected valid runtime pins, got %v", err)
	}

	err := ValidateRuntimePins("3", "24.1", "1", "25.0")
	if err == nil {
		t.Fatal("expected runtime validation error, got nil")
	}
	for _, want := range []string{"python_version", "node_version", "go_version", "java_version"} {
		if !strings.Contains(err.Error(), want) {
			t.Fatalf("missing expected key %q in error: %v", want, err)
		}
	}
}
