package runner

import (
	"fmt"
	"path/filepath"
	"sort"
	"strings"

	"github-bootstrap/tools/internal/toolingupdater/updaters"
	"github-bootstrap/tools/pkg/toolinglib"
)

type Config struct {
	Root         string
	Scope        string
	UpdatersRaw  string
	DryRun       bool
	VerifyLayout bool
	VerifyOnly   bool
}

type updaterEntry struct {
	needsVersions bool
	run           func(root string, scope string, write bool, versions *toolinglib.Versions) ([]string, error)
}

var registry = map[string]updaterEntry{
	"micromamba": {
		needsVersions: true,
		run: func(root string, scope string, write bool, versions *toolinglib.Versions) ([]string, error) {
			if versions == nil {
				return nil, fmt.Errorf("micromamba updater requires version data")
			}
			return updaters.RunMicromamba(root, scope, *versions, write)
		},
	},
	"mise": {
		needsVersions: true,
		run: func(root string, scope string, write bool, versions *toolinglib.Versions) ([]string, error) {
			if versions == nil {
				return nil, fmt.Errorf("mise updater requires version data")
			}
			return updaters.RunMise(root, scope, *versions, write)
		},
	},
	"system": {
		needsVersions: false,
		run: func(_ string, _ string, _ bool, _ *toolinglib.Versions) ([]string, error) {
			return updaters.RunSystem()
		},
	},
	"pre-commit": {
		needsVersions: false,
		run: func(root string, scope string, write bool, _ *toolinglib.Versions) ([]string, error) {
			return updaters.RunPreCommit(root, scope, write)
		},
	},
}

func parseUpdaters(raw string) ([]string, error) {
	if strings.TrimSpace(raw) == "all" {
		return []string{"micromamba", "mise", "system", "pre-commit"}, nil
	}
	parts := strings.Split(raw, ",")
	selected := make([]string, 0, len(parts))
	seen := map[string]bool{}
	for _, part := range parts {
		item := strings.TrimSpace(part)
		if item == "" {
			continue
		}
		if _, ok := registry[item]; !ok {
			return nil, fmt.Errorf("unknown updater: %s", item)
		}
		if !seen[item] {
			selected = append(selected, item)
			seen[item] = true
		}
	}
	if len(selected) == 0 {
		return nil, fmt.Errorf("no updaters selected")
	}
	return selected, nil
}

func Run(cfg Config) ([]string, error) {
	if cfg.VerifyLayout || cfg.VerifyOnly {
		if err := toolinglib.VerifyWorkspaceLayout(cfg.Root); err != nil {
			return nil, err
		}
	}
	if cfg.VerifyOnly {
		return []string{}, nil
	}

	selected, err := parseUpdaters(cfg.UpdatersRaw)
	if err != nil {
		return nil, err
	}

	needsVersions := false
	for _, updaterName := range selected {
		if registry[updaterName].needsVersions {
			needsVersions = true
			break
		}
	}

	var versions *toolinglib.Versions
	if needsVersions {
		resolved, err := toolinglib.CollectVersions()
		if err != nil {
			return nil, err
		}
		versions = &resolved
	}

	changedSet := map[string]bool{}
	for _, updaterName := range selected {
		entry := registry[updaterName]
		paths, err := entry.run(cfg.Root, cfg.Scope, !cfg.DryRun, versions)
		if err != nil {
			return nil, err
		}
		for _, p := range paths {
			rel, relErr := filepath.Rel(cfg.Root, p)
			if relErr == nil {
				changedSet[rel] = true
				continue
			}
			changedSet[p] = true
		}
	}

	ordered := make([]string, 0, len(changedSet))
	for p := range changedSet {
		ordered = append(ordered, p)
	}
	sort.Strings(ordered)
	return ordered, nil
}
