package toolinglib

import "os"

const (
	EnvGitHubTokenPrimary  = "GH_TOKEN"
	EnvGitHubTokenFallback = "GITHUB_TOKEN"
	EnvLogLevel            = "TOOLING_UPDATER_LOG_LEVEL"
)

func FirstNonEmptyEnv(names ...string) string {
	for _, name := range names {
		if value := os.Getenv(name); value != "" {
			return value
		}
	}
	return ""
}
