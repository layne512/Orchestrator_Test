# New Mac Setup Guide — Aperant Orchestrator Shakedown

Complete installation sequence for a fresh Mac to run the orchestrator shakedown test.

**Goal:** end up with a Mac that can run `claude` in this repo's directory and dispatch the orchestrator agent.

**Time estimate:** 30-45 minutes mostly waiting on downloads.

---

## Phase 0 — Prerequisites

You need:
- macOS 13+ (any modern Mac)
- Internet connection
- A GitHub account (your personal one, not write-access to project repos)
- A claude.com account with Claude Code access enabled

---

## Phase 1 — System tools (Xcode CLI + Homebrew)

```bash
# 1. Xcode Command Line Tools (provides git + compilers)
xcode-select --install
# A popup appears — click "Install"
# Wait ~5 min; verify when done:
xcode-select -p
# expected: /Library/Developer/CommandLineTools or similar

# 2. Homebrew (package manager for everything else)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Follow the post-install instructions — you'll need to add brew to your PATH
# (the installer prints the exact command for your shell; usually 2 lines to paste)

# Verify
brew --version
# expected: Homebrew 4.x.x
```

---

## Phase 2 — Git + GitHub CLI

```bash
# 1. Verify git (came with Xcode CLI tools)
git --version
# expected: git version 2.x.x

# 2. Configure git identity
git config --global user.name "Marshall"
git config --global user.email "your-test-email@example.com"

# 3. Install gh CLI
brew install gh

# 4. Authenticate gh
gh auth login
# Pick: GitHub.com → HTTPS → "Login with a web browser"
# A code appears; press Enter; browser opens; paste the code
# Use your PERSONAL account; you only need read access for the test repo
```

---

## Phase 3 — Node.js + Claude Code CLI

```bash
# 1. Node.js (Claude Code CLI requires it)
brew install node
node --version
# expected: v20.x or v22.x or v24.x
npm --version

# 2. Claude Code CLI
npm install -g @anthropic-ai/claude-code
# verify
claude --version
# expected: claude-code 1.x.x or similar

# 3. Authenticate Claude Code
claude
# A first-run flow opens a browser for OAuth.
# After auth completes, type /exit to close the session.
```

---

## Phase 4 — superpowers plugin (required for orchestrator)

The orchestrator spawns subagents that use:
- `superpowers:code-reviewer` (for AI review of every PR)
- `superpowers:debugging` (used by failure-analyst and spec-analyst)

```bash
# 1. Open a fresh Claude Code session
claude

# 2. Inside the session, install the superpowers plugin
# (the exact commands depend on your Claude Code version; current pattern:)
/plugin marketplace add anthropics/claude-code-plugins
/plugin install superpowers

# 3. Verify it loaded
/plugin list
# expected: superpowers shown as installed

# 4. Exit
/exit
```

If the plugin commands don't work in your version, check https://docs.claude.com/code/plugins for current install instructions. The orchestrator has a fallback (uses general-purpose subagent) if superpowers isn't available, but quality drops.

---

## Phase 5 — Aperant install (ONLY for iteration 2)

**Skip this phase for iteration 1.** Iteration 1 (protocol mechanics test) doesn't use aperant — the orchestrator runs directly via Claude Code's Agent tool dispatching.

For iteration 2, install aperant per your existing setup notes. We'll resync on aperant config when iteration 1 passes.

---

## Phase 6 — Clone this test repo + run the orchestrator

```bash
# 1. Clone
gh repo clone layne512/aperant_orchestrator_testing ~/aperant_orchestrator_testing
cd ~/aperant_orchestrator_testing

# 2. Cut the wave-staging branch (where shakedown work happens)
git checkout -b sandbox-staging-T1

# 3. Verify preflight passes
bash preflight.sh --wave=T1 --baseline
# expected: 3 checks pass + baseline file written

# 4. Open Claude Code in this directory
claude
```

### First trigger prompt

Inside the Claude Code session that just opened, paste this:

```
Read ORCHESTRATOR.md and run one shakedown cycle.

Start with SHAKEDOWN-01 since no work is currently in flight.

Follow ORCHESTRATOR.md exactly. Dispatch the executor subagent, AI-review,
sequential-merge with integration test, and log to ORCHESTRATOR_LOG.md.
Exit cleanly after one cycle.
```

### What to capture and send back

After the orchestrator finishes the cycle, run these in your terminal and paste the output back:

```bash
echo "=== STATE/completed.json ===" && cat STATE/completed.json
echo "=== STATE/running.json ===" && cat STATE/running.json
echo "=== STATE/pending_review.json ===" && cat STATE/pending_review.json
echo "=== MARKERS/SHAKEDOWN-01.txt ===" && cat MARKERS/SHAKEDOWN-01.txt
echo "=== PR_SIMULATIONS/SHAKEDOWN-01.json ===" && cat PR_SIMULATIONS/SHAKEDOWN-01.json
echo "=== git log ===" && git log --oneline -5 sandbox-staging-T1
echo "=== git tag ===" && git tag -l 'task-merged-T1-*'
echo "=== ORCHESTRATOR_LOG.md (tail) ===" && tail -40 ORCHESTRATOR_LOG.md
```

These 8 outputs let us diagnose every part of the cycle.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `xcode-select --install` says "command line tools already installed" | Skip; you're good |
| `brew` not found after install | Run `eval "$(/opt/homebrew/bin/brew shellenv)"` and add it to `~/.zshrc` |
| `gh auth login` browser doesn't open | Use `gh auth login --web` and copy URL manually |
| `npm install -g` fails with permission error | Don't `sudo`; instead run `npm config set prefix '~/.npm-global'` and add `~/.npm-global/bin` to PATH |
| `claude` not found after npm install | Make sure `$(npm config get prefix)/bin` is in PATH |
| Plugin commands don't work | Check claude.com/code/docs for current plugin install method; orchestrator has fallbacks |
| Preflight fails with `python3` not found | Install: `brew install python` |
| Preflight fails on `[50_branch]` | Make sure you cut `sandbox-staging-T1` (Phase 6 step 2) |

---

## Cleanup when done

After all 9 shakedowns pass and we're confident in the protocol:

```bash
# Remove the test repo locally
rm -rf ~/aperant_orchestrator_testing

# Archive or delete the GitHub repo
gh repo archive layne512/aperant_orchestrator_testing
# or
gh repo delete layne512/aperant_orchestrator_testing --yes
```
