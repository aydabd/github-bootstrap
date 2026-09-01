package main

import (
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"strings"

	"github-bootstrap/tools/internal/toolingupdater/runner"
	"github-bootstrap/tools/pkg/toolinglib"
)

const defaultCooldownDays = 14

// envIntDefault reads a non-negative integer from name, falling back to
// fallback when the variable is unset, empty, or malformed.
func envIntDefault(name string, fallback int) int {
	raw := strings.TrimSpace(os.Getenv(name))
	if raw == "" {
		return fallback
	}
	value, err := strconv.Atoi(raw)
	if err != nil || value < 0 {
		return fallback
	}
	return value
}

func parseLogLevel() slog.Level {
	switch strings.ToLower(strings.TrimSpace(os.Getenv(toolinglib.EnvLogLevel))) {
	case "debug":
		return slog.LevelDebug
	case "warn", "warning":
		return slog.LevelWarn
	case "error":
		return slog.LevelError
	default:
		return slog.LevelInfo
	}
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stderr, &slog.HandlerOptions{Level: parseLogLevel()}))

	scope := flag.String("scope", "all", "scope: repo|templates|all")
	updatersRaw := flag.String("updaters", "all", "comma-separated updaters or 'all'")
	dryRun := flag.Bool("dry-run", false, "calculate updates without writing files")
	verifyLayout := flag.Bool("verify-layout", false, "verify workspace layout before updates")
	verifyOnly := flag.Bool("verify-only", false, "verify workspace layout and exit")
	metadataFile := flag.String("metadata-file", os.Getenv("TOOLING_UPDATE_METADATA_FILE"), "write structured update metadata to this file")
	explicitBreaking := flag.Bool("explicit-breaking", os.Getenv("TOOLING_UPDATE_EXPLICIT_BREAKING") == "true", "classify all emitted updates as explicitly breaking")
	cooldownDays := flag.Int("cooldown-days", envIntDefault("TOOLING_UPDATE_COOLDOWN_DAYS", defaultCooldownDays), "skip upstream releases published within this many days (0 disables)")
	flag.Parse()

	logger.Info("tooling updater started", "scope", *scope, "updaters", *updatersRaw, "dry_run", *dryRun, "verify_only", *verifyOnly, "cooldown_days", *cooldownDays)

	if *scope != "repo" && *scope != "templates" && *scope != "all" {
		fmt.Fprintln(os.Stderr, "invalid scope, expected repo|templates|all")
		os.Exit(1)
	}

	root, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "tooling update failed: %v\n", err)
		os.Exit(1)
	}

	changed, err := runner.Run(runner.Config{
		Root:         root,
		Scope:        *scope,
		UpdatersRaw:  *updatersRaw,
		DryRun:       *dryRun,
		VerifyLayout: *verifyLayout,
		VerifyOnly:   *verifyOnly,
		CooldownDays: *cooldownDays,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "tooling update failed: %v\n", err)
		os.Exit(1)
	}

	if *verifyOnly {
		logger.Info("workspace layout verification passed")
		fmt.Println("Workspace layout verification passed")
		return
	}
	if *metadataFile != "" {
		if err := toolinglib.WriteUpdateMetadata(root, changed, *metadataFile, *explicitBreaking); err != nil {
			fmt.Fprintf(os.Stderr, "tooling metadata failed: %v\n", err)
			os.Exit(1)
		}
	}

	if *dryRun {
		fmt.Println("Planned tooling file updates:")
	} else {
		fmt.Println("Updated tooling files:")
	}
	for _, path := range changed {
		fmt.Printf("- %s\n", path)
	}
	logger.Info("tooling updater completed", "changed_files", len(changed))
}
