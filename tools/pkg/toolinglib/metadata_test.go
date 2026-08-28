package toolinglib

import "testing"

func TestExtractPinsSupportsEnvironmentAndTOML(t *testing.T) {
	content := "dependencies:\n  - pre-commit=4.6.1\n[tools]\nterraform = \"1.0.0\"\n\"python -m pip install yamllint==1.38.0\"\n\"npm install -g prettier@3.9.6\"\n\"go install example.com/tool@v1.2.3\"\nmise linux x64 https://github.com/jdx/mise/releases/download/v1.2.3/mise-v1.2.3-linux-x64 sha\n"
	pins := extractPins(content)
	if pins["pre-commit"] != "4.6.1" || pins["terraform"] != "1.0.0" || pins["yamllint"] != "1.38.0" || pins["prettier"] != "3.9.6" || pins["example.com/tool"] != "v1.2.3" || pins["mise:linux:x64"] != "v1.2.3" {
		t.Fatalf("extractPins() = %#v", pins)
	}
}

func TestCollectPinChangesDeduplicatesFiles(t *testing.T) {
	byKey := map[string]*UpdateMetadata{}
	collectPinChanges(byKey, "environment.yml", "  - go-shfmt=3.12.0\n", "  - go-shfmt=3.13.0\n")
	collectPinChanges(byKey, "templates/go/environment.yml", "  - go-shfmt=3.12.0\n", "  - go-shfmt=3.13.0\n")
	if len(byKey) != 1 {
		t.Fatalf("expected one deduplicated update, got %d", len(byKey))
	}
	for _, update := range byKey {
		if update.UpdateType != "minor" || len(update.Files) != 2 {
			t.Fatalf("unexpected update: %#v", update)
		}
	}
}
