package main

import (
	"flag"
	"fmt"
	"log/slog"
	"os"
	"strings"

	"github-bootstrap/tools/internal/toolingupdater/runner"
	"github-bootstrap/tools/pkg/toolinglib"
)

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
	flag.Parse()

	logger.Info("tooling updater started", "scope", *scope, "updaters", *updatersRaw, "dry_run", *dryRun, "verify_only", *verifyOnly)

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
