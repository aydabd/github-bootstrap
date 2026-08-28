package toolinglib

import "testing"

func TestClassifyUpdate(t *testing.T) {
	tests := []struct {
		name             string
		oldVersion       string
		newVersion       string
		explicitBreaking bool
		wantType         string
		wantRisk         string
	}{
		{name: "patch", oldVersion: "1.2.3", newVersion: "1.2.4", wantType: "patch", wantRisk: "low"},
		{name: "minor", oldVersion: "1.2.3", newVersion: "1.3.0", wantType: "minor", wantRisk: "medium"},
		{name: "major", oldVersion: "1.2.3", newVersion: "2.0.0", wantType: "major", wantRisk: "high"},
		{name: "prefixed major", oldVersion: "v1.2.3", newVersion: "v2.0.0", wantType: "major", wantRisk: "high"},
		{name: "explicit breaking", oldVersion: "1.2.3", newVersion: "1.2.4", explicitBreaking: true, wantType: "breaking", wantRisk: "high"},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := ClassifyUpdate(tt.oldVersion, tt.newVersion, tt.explicitBreaking)
			if got.UpdateType != tt.wantType || got.Risk != tt.wantRisk {
				t.Fatalf("ClassifyUpdate(%q, %q, %t) = %#v, want type=%q risk=%q", tt.oldVersion, tt.newVersion, tt.explicitBreaking, got, tt.wantType, tt.wantRisk)
			}
		})
	}
}

func TestClassifyUpdateRejectsUnchangedVersion(t *testing.T) {
	got := ClassifyUpdate("1.2.3", "1.2.3", false)
	if got.UpdateType != "unchanged" || got.Risk != "none" {
		t.Fatalf("ClassifyUpdate unchanged = %#v, want unchanged/none", got)
	}
}

func TestClassifyUpdateTreatsRevisionAsUnknown(t *testing.T) {
	got := ClassifyUpdate("abc123", "def456", false)
	if got.UpdateType != "unknown" || got.Risk != "unknown" {
		t.Fatalf("ClassifyUpdate revision = %#v, want unknown/unknown", got)
	}
}
