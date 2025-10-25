# Testing Your Repository Bootstrap

This repository includes an automated testing workflow that validates the repository creation process.

## How to Test

1. **Navigate to Actions tab** in your GitHub repository
2. **Select "Test Repository Creation"** workflow
3. **Click "Run workflow"**
4. **Configure the test parameters:**
   - `test_repo_name`: Base name for the test repository (will be prefixed with `test-` and timestamped)
   - `primary_language`: Language to test super-linter configuration for
   - `cleanup_after_test`: Whether to automatically delete the test repository
   - `wait_time_minutes`: How long to wait before cleanup (gives you time to inspect results)

## What the Test Does

### Repository Creation Validation
- ✅ Creates a new test repository using your bootstrap template
- ✅ Validates all required files are present:
  - `.github/workflows/super-linter.yml`
  - `.github/CODEOWNERS`
  - `.github/dependabot.yml`
  - `.super-linter.env`
  - `.editorconfig`, `.gitignore`, `.gitattributes`
  - `README.md`, `LICENSE`, `Makefile`

### Super-Linter Configuration Validation
- ✅ Verifies language-specific linter configuration
- ✅ Triggers super-linter workflow to test actual functionality
- ✅ Ensures the configuration matches your selected primary language

### Automatic Cleanup
- 🗑️ Optionally deletes the test repository after validation
- ⏱️ Configurable wait time to inspect results before cleanup

## Manual Testing

You can also manually test by:

1. Running the "Create Bootstrap Repository" workflow
2. Inspecting the created repository
3. Running the "Delete repository" workflow for cleanup

## Example Test Scenarios

- **Multi-language project**: Test with `primary_language: multi-language`
- **Single language**: Test with specific languages like `python`, `javascript`, etc.
- **Configuration validation**: Set `cleanup_after_test: false` to manually inspect the results

## Troubleshooting

If tests fail:

1. Check the workflow logs for detailed error messages
2. Verify your `GH_PAT` secret has the necessary permissions:
   - `repo` (full repository access)
   - `workflow` (manage workflows)
   - `delete_repo` (for cleanup)
3. Ensure your token has admin access to the organization/account

## Required Secrets

Make sure your repository has a secret named `GH_PAT` with a personal access token that includes:
- Repository administration permissions
- Workflow permissions
- Delete repository permissions (for cleanup)