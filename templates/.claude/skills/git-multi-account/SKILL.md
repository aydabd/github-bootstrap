---
name: git-multi-account
description: Complete guide for setting up isolated Work & Personal Git identities, SSH keys, GPG/SSH signatures, and GitHub CLI (gh) authentication based on folder paths.
---

# Multi-Account Git & GitHub Isolation Guide

This guide establishes complete isolation between multiple GitHub accounts (e.g., **Work** and **Personal**) on a single machine. Context switching is 100% automated based on your active terminal directory—no manual config editing required after cloning repositories.

---

## 📁 1. Directory Structure

Group your repositories into dedicated parent folders:

```text
~/git/
├── work-internal/     <-- Work / Enterprise repositories
└── personal/          <-- Personal & Open Source repositories

```

---

## 🔑 2. SSH Keys & `~/.ssh/config`

### Step A: Generate Dedicated SSH Keys

```bash
# Work SSH Key
ssh-keygen -t ed25519 -C "<YOUR_WORK_EMAIL>" -f ~/.ssh/id_ed25519_github_work

# Personal SSH Key
ssh-keygen -t ed25519 -C "<YOUR_PERSONAL_EMAIL>" -f ~/.ssh/id_ed25519_github_personal

```

Add the corresponding public keys (`.pub`) to their respective GitHub accounts under **Settings → SSH and GPG keys**.

### Step B: Configure `~/.ssh/config`

Position the `Match` block **first** and use `IdentityAgent none` to prevent local SSH agents from overriding folder-based key selection:

```ini
# ~/.ssh/config

# 1. WORK MATCH (Evaluated first)
Match host github.com exec "test \"${PWD#*/git/work-internal}\" != \"$PWD\""
     HostName github.com
     User git
     IdentityFile ~/.ssh/id_ed25519_github_work
     IdentitiesOnly yes
     IdentityAgent none

# 2. PERSONAL / FALLBACK (Evaluated if Match above doesn't trigger)
Host github.com
     HostName github.com
     User git
     IdentityFile ~/.ssh/id_ed25519_github_personal
     IdentitiesOnly yes
     IdentityAgent none

```

---

## ⚙️ 3. Global & Scoped Git Configurations

### Step A: Global Configuration (`~/.gitconfig`)

Enforce security best practices (SSH signing, DCO sign-offs, safe force-pushes) and route identity profiles dynamically via `includeIf`:

```ini
[user]
    # Fallback name (Emails are injected via includeIf files)
    name = <YOUR_NAME>

[core]
    autoSetupRemote = true
    filemode = true
    autocrlf = input

[init]
    defaultBranch = main

[push]
    default = simple
    followTags = true

[fetch]
    prune = true
    pruneTags = true

[rebase]
    autoSquash = true
    autoStash = true

[gpg]
    format = ssh

[commit]
    # Enforce SSH signature and DCO (Signed-off-by) globally
    gpgsign = true
    signoff = true

[color]
    ui = auto

[merge]
    log = true
    conflictstyle = zdiff3

[diff]
    colorMoved = default

[alias]
    co = checkout
    br = branch
    ci = commit
    st = status
    last = log -1 HEAD
    unstage = reset HEAD --
    pf = push --force-with-lease
    lol = log --graph --decorate --pretty=oneline --abbrev-commit
    lola = log --graph --decorate --pretty=oneline --abbrev-commit --all
    ri = rebase -i origin/main

[credential "[https://github.com](https://github.com)"]
    helper =
    helper = !/opt/homebrew/bin/gh auth git-credential

[credential "[https://gist.github.com](https://gist.github.com)"]
    helper =
    helper = !/opt/homebrew/bin/gh auth git-credential

# Work Profile Route
[includeIf "gitdir:~/git/work-internal/"]
    path = ~/.gitconfig-work

# Personal Profile Route
[includeIf "gitdir:~/git/personal/"]
    path = ~/.gitconfig-personal

```

### Step B: Work Git Profile (`~/.gitconfig-work`)

```ini
[user]
    name = <YOUR_NAME>
    email = <YOUR_WORK_EMAIL>
    signingkey = ~/.ssh/id_ed25519_github_work.pub

```

### Step C: Personal Git Profile (`~/.gitconfig-personal`)

```ini
[user]
    name = <YOUR_NAME>
    email = <YOUR_PERSONAL_EMAIL>
    signingkey = ~/.ssh/id_ed25519_github_personal.pub

```

---

## 💻 4. GitHub CLI (`gh`) Account Auto-Switching

Handle GitHub CLI authentication dynamically using a Zsh directory hook (`chpwd`) without 3rd-party binaries.

### Step A: Authenticate Both Accounts in `gh`

```bash
# Log in to both accounts sequentially
gh auth login --hostname github.com

```

### Step B: Add Zsh Hook Function

Save this file as `$ZSH_CUSTOM/github-functions.zsh` (for Oh-My-Zsh) or append to `~/.zshrc`:

```zsh
# $ZSH_CUSTOM/github-functions.zsh

# Automatically switch GitHub CLI (gh) auth token based on current directory
_gh_account_switch_user() {
  local current_dir="${PWD:A}"
  local target_work="${HOME:A}/git/work-internal"
  local target_personal="${HOME:A}/git/personal"

  case "$current_dir" in
    "$target_work"* )
      export GH_TOKEN="$(gh auth token --user <YOUR_WORK_GITHUB_HANDLE> 2>/dev/null)"
      ;;
    "$target_personal"* )
      export GH_TOKEN="$(gh auth token --user <YOUR_PERSONAL_GITHUB_HANDLE> 2>/dev/null)"
      ;;
    * )
      export GH_TOKEN="$(gh auth token --user <YOUR_PERSONAL_GITHUB_HANDLE> 2>/dev/null)"
      ;;
  esac
}

# Register the hook to execute on directory change (cd)
autoload -U add-zsh-hook
add-zsh-hook chpwd _gh_account_switch_user

# Execute immediately on terminal launch
_gh_account_switch_user

```

---

## 🧪 5. Verification Commands

Run these checks inside any repository to confirm that your environment is correctly isolated:

```zsh
# 1. Test Active SSH Key
ssh -T git@github.com

# 2. Test Resolved Git Email & Signing Key
git config user.email
git config user.signingkey

# 3. Test Active GitHub CLI User
gh api user --jq .login

```

---

## 📊 Summary Matrix

| Context | Directory Path | SSH Key Used | Git Email | `gh` Active User |
| --- | --- | --- | --- | --- |
| **Work** | `~/git/work-internal/` | `id_ed25519_github_work` | `<YOUR_WORK_EMAIL>` | `<YOUR_WORK_GITHUB_HANDLE>` |
| **Personal** | `~/git/personal/` | `id_ed25519_github_personal` | `<YOUR_PERSONAL_EMAIL>` | `<YOUR_PERSONAL_GITHUB_HANDLE>` |

