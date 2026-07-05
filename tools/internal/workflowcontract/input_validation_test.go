package workflowcontract

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

var creationWorkflows = []string{
	".github/workflows/create-repository.yml",
	".github/workflows/terraform-create-repository.yml",
}

func TestValidateBootstrapInputsContract(t *testing.T) {
	tests := []struct {
		name       string
		env        map[string]string
		wantErr    bool
		wantStderr string
	}{
		{
			name: "language agnostic only",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "language-agnostic-only",
			}),
		},
		{
			name: "supported aliases",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "go,node,nodejs,kotlin",
			}),
		},
		{
			name: "all languages",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "all",
			}),
		},
		{
			name: "invalid env manager",
			env: validInputEnv(map[string]string{
				"ENV_MANAGER": "conda",
			}),
			wantErr:    true,
			wantStderr: "Invalid env_manager 'conda'",
		},
		{
			name: "unknown language token",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "python,rust",
			}),
			wantErr:    true,
			wantStderr: "Unknown language token 'rust'",
		},
		{
			name: "language agnostic cannot combine",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "language-agnostic-only,go",
			}),
			wantErr:    true,
			wantStderr: "language-agnostic-only' cannot be combined",
		},
		{
			name: "languages cannot contain spaces",
			env: validInputEnv(map[string]string{
				"LANGUAGES": "go, python",
			}),
			wantErr:    true,
			wantStderr: "Invalid languages input 'go, python'",
		},
		{
			name: "invalid python version",
			env: validInputEnv(map[string]string{
				"PYTHON_VERSION": "3",
			}),
			wantErr:    true,
			wantStderr: "Invalid python_version '3'",
		},
		{
			name: "invalid node version",
			env: validInputEnv(map[string]string{
				"NODE_VERSION": "24.1",
			}),
			wantErr:    true,
			wantStderr: "Invalid node_version '24.1'",
		},
		{
			name: "invalid go version",
			env: validInputEnv(map[string]string{
				"GO_VERSION": "1",
			}),
			wantErr:    true,
			wantStderr: "Invalid go_version '1'",
		},
		{
			name: "invalid java version",
			env: validInputEnv(map[string]string{
				"JAVA_VERSION": "25.0",
			}),
			wantErr:    true,
			wantStderr: "Invalid java_version '25.0'",
		},
	}

	repoRoot := findRepoRoot(t)
	for _, workflow := range creationWorkflows {
		workflow := workflow
		script := extractNamedRunScript(t, filepath.Join(repoRoot, workflow), "Validate bootstrap inputs")
		for _, tt := range tests {
			t.Run(workflow+"/"+tt.name, func(t *testing.T) {
				stdout, stderr, err := runValidationScript(t, script, tt.env)
				combinedOutput := stdout + stderr
				if tt.wantErr {
					if err == nil {
						t.Fatalf("expected script to fail, stdout=%q stderr=%q", stdout, stderr)
					}
					if !strings.Contains(combinedOutput, tt.wantStderr) {
						t.Fatalf("output mismatch: got %q want substring %q", combinedOutput, tt.wantStderr)
					}
					return
				}
				if err != nil {
					t.Fatalf("script failed unexpectedly: %v stdout=%q stderr=%q", err, stdout, stderr)
				}
				for _, wantOutput := range []string{
					"languages=" + tt.env["LANGUAGES"],
					"env_manager=" + tt.env["ENV_MANAGER"],
					"python_version=" + tt.env["PYTHON_VERSION"],
					"node_version=" + tt.env["NODE_VERSION"],
					"go_version=" + tt.env["GO_VERSION"],
					"java_version=" + tt.env["JAVA_VERSION"],
				} {
					if !strings.Contains(stdout, wantOutput) {
						t.Fatalf("stdout missing %q: %q", wantOutput, stdout)
					}
				}
			})
		}
	}
}

func validInputEnv(overrides map[string]string) map[string]string {
	env := map[string]string{
		"LANGUAGES":      "python",
		"ENV_MANAGER":    "micromamba",
		"PYTHON_VERSION": "3.13",
		"NODE_VERSION":   "24",
		"GO_VERSION":     "1.26",
		"JAVA_VERSION":   "25",
	}
	for key, value := range overrides {
		env[key] = value
	}
	return env
}

func runValidationScript(t *testing.T, script string, env map[string]string) (string, string, error) {
	t.Helper()

	outputFile := filepath.Join(t.TempDir(), "github-output")
	command := exec.Command("bash", "-euo", "pipefail", "-c", script)
	command.Env = append(os.Environ(), "GITHUB_OUTPUT="+outputFile)
	for key, value := range env {
		command.Env = append(command.Env, key+"="+value)
	}

	var stdout, stderr strings.Builder
	command.Stdout = &stdout
	command.Stderr = &stderr
	err := command.Run()

	outputData, readErr := os.ReadFile(outputFile)
	if readErr == nil {
		stdout.Write(outputData)
	}
	return stdout.String(), stderr.String(), err
}

func extractNamedRunScript(t *testing.T, path, stepName string) string {
	t.Helper()

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read workflow: %v", err)
	}
	lines := strings.Split(string(data), "\n")

	stepMarker := "      - name: " + stepName
	for index, line := range lines {
		if line != stepMarker {
			continue
		}
		for runIndex := index + 1; runIndex < len(lines); runIndex++ {
			if strings.TrimSpace(lines[runIndex]) != "run: |" {
				continue
			}
			var scriptLines []string
			for scriptIndex := runIndex + 1; scriptIndex < len(lines); scriptIndex++ {
				line := lines[scriptIndex]
				if strings.HasPrefix(line, "      - name: ") {
					break
				}
				if strings.HasPrefix(line, "          ") {
					scriptLines = append(scriptLines, strings.TrimPrefix(line, "          "))
				} else if strings.TrimSpace(line) == "" {
					scriptLines = append(scriptLines, "")
				}
			}
			if len(scriptLines) == 0 {
				t.Fatalf("run script for %q is empty in %s", stepName, path)
			}
			return strings.Join(scriptLines, "\n")
		}
	}
	t.Fatalf("step %q not found in %s", stepName, path)
	return ""
}

func findRepoRoot(t *testing.T) string {
	t.Helper()

	dir, err := os.Getwd()
	if err != nil {
		t.Fatalf("get working directory: %v", err)
	}
	for {
		if _, err := os.Stat(filepath.Join(dir, ".github", "workflows")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			t.Fatal("repository root not found")
		}
		dir = parent
	}
}
