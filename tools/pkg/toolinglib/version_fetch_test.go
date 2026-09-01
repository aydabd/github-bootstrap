package toolinglib

import "testing"

func TestLatestStableVersion(t *testing.T) {
	tests := []struct {
		name     string
		versions []string
		want     string
	}{
		{
			name:     "ignores pre-releases and picks the newest stable",
			versions: []string{"3.14.6", "3.15.0a7", "3.15.0b4", "3.15.0rc1", "3.14.7", "3.13.15"},
			want:     "3.14.7",
		},
		{
			name:     "compares components numerically not lexically",
			versions: []string{"1.2.9", "1.2.10", "1.10.0"},
			want:     "1.10.0",
		},
		{
			name:     "handles differing component counts",
			versions: []string{"1.15", "1.15.9", "1.9.9"},
			want:     "1.15.9",
		},
		{
			name:     "returns empty when every version is a pre-release",
			versions: []string{"3.15.0a1", "3.15.0rc2"},
			want:     "",
		},
		{
			name:     "returns empty for no versions",
			versions: nil,
			want:     "",
		},
	}

	for _, testCase := range tests {
		t.Run(testCase.name, func(t *testing.T) {
			got := latestStableVersion(testCase.versions)
			if got != testCase.want {
				t.Fatalf("latestStableVersion(%v) = %q, want %q", testCase.versions, got, testCase.want)
			}
		})
	}
}

func TestCompareNumericVersions(t *testing.T) {
	tests := []struct {
		a    string
		b    string
		sign int
	}{
		{a: "3.14.7", b: "3.14.6", sign: 1},
		{a: "3.14.6", b: "3.14.7", sign: -1},
		{a: "3.14.6", b: "3.14.6", sign: 0},
		{a: "1.2.10", b: "1.2.9", sign: 1},
		{a: "1.15", b: "1.15.0", sign: 0},
		{a: "2.0", b: "1.99.99", sign: 1},
	}

	for _, testCase := range tests {
		result := compareNumericVersions(testCase.a, testCase.b)
		switch {
		case testCase.sign == 0 && result != 0:
			t.Fatalf("compareNumericVersions(%q, %q) = %d, want 0", testCase.a, testCase.b, result)
		case testCase.sign < 0 && result >= 0:
			t.Fatalf("compareNumericVersions(%q, %q) = %d, want < 0", testCase.a, testCase.b, result)
		case testCase.sign > 0 && result <= 0:
			t.Fatalf("compareNumericVersions(%q, %q) = %d, want > 0", testCase.a, testCase.b, result)
		}
	}
}

func TestStableVersionPatternRejectsPreReleases(t *testing.T) {
	stable := []string{"3", "3.14", "3.14.7", "1.15.9", "0.11.0"}
	for _, version := range stable {
		if !stableVersionPattern.MatchString(version) {
			t.Errorf("expected %q to be treated as stable", version)
		}
	}

	preRelease := []string{"3.15.0rc1", "3.15.0a7", "3.15.0b4", "1.2.3-dev", "v1.2.3", "1.2.3+meta"}
	for _, version := range preRelease {
		if stableVersionPattern.MatchString(version) {
			t.Errorf("expected %q to be treated as a pre-release", version)
		}
	}
}
