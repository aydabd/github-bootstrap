package toolinglib

import "regexp"

type UpdateClassification struct {
	UpdateType string `json:"update_type"`
	Risk       string `json:"risk"`
}

var numericVersionPattern = regexp.MustCompile(`^[vV]?([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?(?:[-+].*)?$`)

// ClassifyUpdate classifies a version or opaque revision change deterministically.
// An explicit breaking marker always takes precedence over the version numbers.
func ClassifyUpdate(oldVersion string, newVersion string, explicitBreaking bool) UpdateClassification {
	if oldVersion == newVersion {
		return UpdateClassification{UpdateType: "unchanged", Risk: "none"}
	}
	if explicitBreaking {
		return UpdateClassification{UpdateType: "breaking", Risk: "high"}
	}
	oldMatch := numericVersionPattern.FindStringSubmatch(oldVersion)
	newMatch := numericVersionPattern.FindStringSubmatch(newVersion)
	if oldMatch == nil || newMatch == nil {
		return UpdateClassification{UpdateType: "unknown", Risk: "unknown"}
	}
	for index := 1; index <= 3; index++ {
		oldNumber := parseVersionPart(oldMatch[index])
		newNumber := parseVersionPart(newMatch[index])
		if oldNumber == newNumber {
			continue
		}
		switch index {
		case 1:
			return UpdateClassification{UpdateType: "major", Risk: "high"}
		case 2:
			return UpdateClassification{UpdateType: "minor", Risk: "medium"}
		default:
			return UpdateClassification{UpdateType: "patch", Risk: "low"}
		}
	}
	return UpdateClassification{UpdateType: "unknown", Risk: "unknown"}
}

func parseVersionPart(value string) int {
	if value == "" {
		return 0
	}
	result := 0
	for _, digit := range value {
		result = result*10 + int(digit-'0')
	}
	return result
}
