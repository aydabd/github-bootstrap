package toolinglib

import (
	"testing"
	"time"
)

func rc(version string, released time.Time) releaseCandidate {
	return releaseCandidate{version: version, released: released}
}

func TestNewestEligibleVersion_NoCutoff(t *testing.T) {
	tests := []struct {
		name       string
		candidates []releaseCandidate
		want       string
	}{
		{
			name:       "ignores pre-releases and picks the newest stable",
			candidates: []releaseCandidate{rc("3.14.6", time.Time{}), rc("3.15.0a7", time.Time{}), rc("3.15.0b4", time.Time{}), rc("3.15.0rc1", time.Time{}), rc("3.14.7", time.Time{}), rc("3.13.15", time.Time{})},
			want:       "3.14.7",
		},
		{
			name:       "compares components numerically not lexically",
			candidates: []releaseCandidate{rc("1.2.9", time.Time{}), rc("1.2.10", time.Time{}), rc("1.10.0", time.Time{})},
			want:       "1.10.0",
		},
		{
			name:       "handles differing component counts",
			candidates: []releaseCandidate{rc("1.15", time.Time{}), rc("1.15.9", time.Time{}), rc("1.9.9", time.Time{})},
			want:       "1.15.9",
		},
		{
			name:       "returns empty when every candidate is a pre-release",
			candidates: []releaseCandidate{rc("3.15.0a1", time.Time{}), rc("3.15.0rc2", time.Time{})},
			want:       "",
		},
		{
			name:       "returns empty for no candidates",
			candidates: nil,
			want:       "",
		},
	}

	for _, testCase := range tests {
		t.Run(testCase.name, func(t *testing.T) {
			if got := newestEligibleVersion(testCase.candidates, time.Time{}); got != testCase.want {
				t.Fatalf("newestEligibleVersion(...) = %q, want %q", got, testCase.want)
			}
		})
	}
}

func TestNewestEligibleVersion_Cooldown(t *testing.T) {
	now := time.Now().UTC()
	cutoff := now.AddDate(0, 0, -14)
	old := now.AddDate(0, 0, -40)
	recent := now.AddDate(0, 0, -3)

	candidates := []releaseCandidate{
		rc("1.2.0", old),
		rc("1.3.0", old),
		rc("1.4.0", recent), // inside the cooldown window
		rc("1.5.0rc1", old), // pre-release, always skipped
	}

	if got := newestEligibleVersion(candidates, cutoff); got != "1.3.0" {
		t.Fatalf("cooldown filter = %q, want 1.3.0 (1.4.0 too recent)", got)
	}

	// Exactly on the cutoff still counts as eligible.
	onCutoff := []releaseCandidate{rc("2.0.0", cutoff)}
	if got := newestEligibleVersion(onCutoff, cutoff); got != "2.0.0" {
		t.Fatalf("release exactly on cutoff = %q, want 2.0.0", got)
	}

	// A stable candidate with an unknown publish time is skipped under cooldown.
	unknown := []releaseCandidate{rc("3.0.0", time.Time{}), rc("2.9.0", old)}
	if got := newestEligibleVersion(unknown, cutoff); got != "2.9.0" {
		t.Fatalf("unknown publish time under cooldown = %q, want 2.9.0", got)
	}

	// Without a cooldown, publish times are irrelevant.
	if got := newestEligibleVersion(candidates, time.Time{}); got != "1.4.0" {
		t.Fatalf("no cooldown = %q, want 1.4.0", got)
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

func TestParsePublishTime(t *testing.T) {
	cases := map[string]bool{
		"2026-08-10T22:07:16.942290Z":      true,  // PyPI upload_time_iso_8601
		"2026-07-14T22:02:03.567Z":         true,  // npm time
		"2026-08-28 20:31:20.099000+00:00": true,  // anaconda files[].upload_time
		"2026-02-28T08:10:00Z":             true,  // Go proxy Time
		"":                                 false, // empty
		"not-a-timestamp":                  false, // garbage
	}
	for value, wantParsed := range cases {
		got := parsePublishTime(value)
		if wantParsed && got.IsZero() {
			t.Errorf("parsePublishTime(%q) returned zero, expected a time", value)
		}
		if !wantParsed && !got.IsZero() {
			t.Errorf("parsePublishTime(%q) = %v, expected zero", value, got)
		}
	}
}

func TestCooldownCutoff(t *testing.T) {
	if !cooldownCutoff(0).IsZero() {
		t.Error("cooldownCutoff(0) should be the zero time (disabled)")
	}
	if !cooldownCutoff(-5).IsZero() {
		t.Error("cooldownCutoff(-5) should be the zero time (disabled)")
	}
	got := cooldownCutoff(14)
	if got.IsZero() {
		t.Fatal("cooldownCutoff(14) should be a real time")
	}
	age := time.Since(got)
	if age < 13*24*time.Hour || age > 15*24*time.Hour {
		t.Errorf("cooldownCutoff(14) is %v ago, expected ~14 days", age)
	}
}
