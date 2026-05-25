# Plan: Clarify GitHub App architecture for reusable workflow consumers

## TL;DR

Your assumption is **partially correct** but there's a nuance. External consumers DO bring their own GitHub App — the bootstrap repo holds zero credentials. However, GitHub App **installation tokens** can ONLY create repos under **organizations**, not personal user accounts. This is a GitHub API constraint, not a design flaw.

## Architecture Validation

### What's correct in your thinking

- Any org/user can create their own GitHub App with the right permissions
- They install the App on their target org(s)
- They store `BOOTSTRAP_APP_PRIVATE_KEY` and `BOOTSTRAP_APP_ID` in their own launcher repo
- They call `aydabd/github-bootstrap/.github/workflows/create-repository.yml@main` via `workflow_call`
- The bootstrap repo is entirely credential-agnostic — it just receives and uses whatever the caller passes

### The GitHub API constraint that limits this

| Target owner type     | GitHub App installation token                                      | PAT / User access token |
| --------------------- | ------------------------------------------------------------------ | ----------------------- |
| Organization          | Works (`POST /orgs/{org}/repos`)                                   | Works                   |
| Personal user account | **Does NOT work** (`POST /user/repos` rejects installation tokens) | Works                   |

The endpoint `POST /user/repos` only accepts:

- GitHub App **user access tokens** (OAuth flow with user interaction)
- Fine-grained **personal access tokens**

It explicitly does NOT support GitHub App **installation access tokens** (server-to-server).

This is why the workflow has the `Validate owner type vs auth mode` guard:

```yaml
if [ "$AUTH_MODE" = "app" ] && [ "$OWNER_TYPE" = "User" ]; then
echo "::error::GitHub App installation tokens cannot create repositories under a personal user account"
exit 1
fi
```

### What consumers need

| Scenario                                       | Auth method                                               |
| ---------------------------------------------- | --------------------------------------------------------- |
| Create repos under their **org** (most common) | GitHub App (recommended) — short-lived, scoped, auditable |
| Create repos under a **personal account**      | PAT (fine-grained recommended) — `GH_PAT` secret          |

## Steps — Improve consumer experience

1. **Update README "Authentication" section** — clearly explain the two paths (App for orgs, PAT for personal) with a decision matrix
   - `README.md` — new "Authentication Guide" sub-section under Setup
   - Reference the GitHub docs constraint explicitly

2. **Update launcher examples** — add inline comments explaining when to use App vs PAT
   - `examples/launcher-actions.yml` — add comment block near `app_id` input
   - `examples/launcher-terraform.yml` — same

3. **Improve error message in workflows** — make the `Validate owner type` error more actionable
   - `.github/workflows/create-repository.yml` line ~288
   - `.github/workflows/terraform-create-repository.yml` equivalent
   - Suggest "Use gh_token/GH_PAT for personal accounts" in the error

4. **(Optional) Consider supporting GitHub App user access tokens** — this would allow Apps to work for personal repos too, but requires an OAuth web flow, which is far more complex and likely out of scope for a CI workflow

## Relevant files

- `README.md` — authentication guidance section
- `examples/launcher-actions.yml` — consumer template with auth config
- `examples/launcher-terraform.yml` — same
- `.github/actions/resolve-gh-token/action.yml` — token resolution logic
- `.github/workflows/create-repository.yml` — `Validate owner type vs auth mode` step (~line 288)
- `.github/workflows/terraform-create-repository.yml` — same step

## Verification

1. Run the launcher with `auth_mode=app` targeting an org → should succeed
2. Run the launcher with `auth_mode=app` targeting a user → should fail with improved error message
3. Run the launcher with `auth_mode=pat` targeting a user → should succeed
4. README reads clearly for a first-time consumer

## Decisions

- The current architecture (caller brings own App) is **correct and secure** — no change needed
- The App-vs-User guard is **correct per GitHub API docs** — keep it
- Scope: documentation improvements + better error messages only (no architectural change)
- Excluded: GitHub App user access tokens (OAuth flow) — too complex for CI automation

## Further Considerations

1. **Should we remove the App-vs-User guard and just let GitHub API return 403?** — No, keep it. A clear, actionable error message is much better than a cryptic API failure. Our guard tells the user exactly what to do (use PAT).
2. **Should we support both App AND PAT simultaneously (fallback)?** — Already supported. `resolve-gh-token` tries App first; if App creds aren't provided, it falls through to PAT. A consumer could provide both and the workflow picks App for orgs automatically.
