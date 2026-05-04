# Orchestrator Test — Comprehensive Install Guide

End-to-end setup for running the orchestrator shakedown test on a fresh Mac. Read top to bottom; commands are copy-paste safe.

**Estimated time:** 45-90 min (mostly downloads + compilations)
**Prerequisites:** macOS 12.7+ on Apple Silicon or Intel; Claude Pro/Max subscription; GitHub account
**Output:** A working installation ready to run all 11 shakedown scenarios

---

## Phase 0 — Identify your machine

```bash
uname -m            # arm64 = Apple Silicon, x86_64 = Intel
sw_vers             # macOS version
```

Note these — install commands branch on chip type below. macOS 12.7+ should work for everything except possibly Aperant v2.7.6 (we have a fallback if it fails).

---

## Phase 1 — System tools (Xcode CLI + Homebrew)

```bash
# Xcode CLI tools (provides git + compilers; ~5 min download)
xcode-select --install
# A popup appears; click "Install" and wait

# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# At the end, brew prints commands to add itself to your PATH; run them
# Typically:  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
#             eval "$(/opt/homebrew/bin/brew shellenv)"

# Verify
git --version       # came with Xcode CLI tools
brew --version      # confirm Homebrew on PATH
```

**Troubleshooting:**
- If brew install hangs: it may be compiling Go from source (normal on macOS 12). Check Activity Monitor for `make` / `cc` / `clang` processes — if active, just wait.
- If Xcode license error: `sudo xcodebuild -license accept`

---

## Phase 2 — Git identity + GitHub CLI

```bash
# Git identity (will be attached to commits made by orchestrator/executors)
git config --global user.name "Marshall"
git config --global user.email "your-email@example.com"

# GitHub CLI
brew install gh

# Authenticate (opens browser for OAuth)
gh auth login
# Choose: GitHub.com → HTTPS → "Login with a web browser"
# Use a personal account; you only need read access to layne512/Orchestrator_Test

# Verify
gh auth status
```

---

## Phase 3 — Node + Claude Code CLI

```bash
# Node (Claude Code requires it)
brew install node
node --version       # expect v20+ or v22+
npm --version

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
claude --version

# First launch — OAuth flow
claude
# Inside the session: walk through OAuth to your Claude account, then /exit
```

---

## Phase 4 — superpowers plugin

The orchestrator's `failure-analyst` and `spec-analyst` subagents prefer (but don't strictly require) the `superpowers:debugging` skill, and `code-reviewer` prefers `superpowers:code-reviewer`.

```bash
claude
# Inside the session, run:
#   /plugin marketplace add anthropics/claude-code-plugins
#   /plugin install superpowers
#   /exit
```

**If the plugin commands above don't work** (Claude Code's plugin system may have shifted commands), check https://docs.claude.com/code/plugins for the current install method. The orchestrator has fallbacks for missing plugins — it's preferred, not blocking.

**Verify:** in a fresh `claude` session, type `/plugin list` (or whichever command lists installed plugins). superpowers should appear.

---

## Phase 5 — Aperant (the desktop app, formerly "Auto-Claude")

Aperant is a desktop GUI for managing autonomous coding tasks. Install from https://github.com/AndyMik90/Aperant.

### For Apple Silicon (arm64):

```bash
cd ~/Downloads
curl -L -o Aperant.dmg \
  https://github.com/AndyMik90/Aperant/releases/download/v2.7.6/Auto-Claude-2.7.6-darwin-arm64.dmg
hdiutil attach Aperant.dmg
cp -R "/Volumes/Auto-Claude 2.7.6/Auto-Claude.app" /Applications/
hdiutil detach "/Volumes/Auto-Claude 2.7.6"
rm Aperant.dmg
open -a "Auto-Claude"
```

### For Intel (x86_64):

```bash
cd ~/Downloads
curl -L -o Aperant.dmg \
  https://github.com/AndyMik90/Aperant/releases/download/v2.7.6/Auto-Claude-2.7.6-darwin-x64.dmg
hdiutil attach Aperant.dmg
cp -R "/Volumes/Auto-Claude 2.7.6/Auto-Claude.app" /Applications/
hdiutil detach "/Volumes/Auto-Claude 2.7.6"
rm Aperant.dmg
open -a "Auto-Claude"
```

### If macOS Gatekeeper blocks ("cannot be opened because the developer cannot be verified"):

```bash
xattr -dr com.apple.quarantine "/Applications/Auto-Claude.app"
open -a "Auto-Claude"
```

### If v2.7.6 fails on macOS 12 (requires macOS 13+):

Fall back to v2.7.0 (released Dec 2025, more permissive):

```bash
# Apple Silicon
cd ~/Downloads
curl -L -o Aperant.dmg \
  https://github.com/AndyMik90/Aperant/releases/download/v2.7.0/Auto-Claude-2.7.0-darwin-arm64.dmg

# Intel
cd ~/Downloads
curl -L -o Aperant.dmg \
  https://github.com/AndyMik90/Aperant/releases/download/v2.7.0/Auto-Claude-2.7.0-darwin-x64.dmg

# Then same hdiutil/cp/open as above
```

**Note:** Aperant is OPTIONAL for iteration 1. The orchestrator can run via Claude Code CLI alone (`claude` in terminal). Aperant's role is to provide a Kanban-style UI for triggering and monitoring task runs. If Aperant install fails, you can still run the shakedown — see Phase 7 alternative trigger.

---

## Phase 6 — Clone the test repo

```bash
mkdir -p ~/Documents
cd ~/Documents
gh repo clone layne512/Orchestrator_Test ./Orchestrator_Test
cd Orchestrator_Test

# Cut the wave-staging branch
git checkout -b sandbox-staging-T1

# Verify preflight passes
bash preflight.sh --wave=T1 --baseline
# Expected: all 3 checks pass (filesystem OK, branch OK, JSON OK)
```

If preflight fails, paste the output back to whoever provided this guide. Don't proceed.

---

## Phase 7 — Trigger the orchestrator

Three ways to trigger, in order of preference:

### Option A — Via Aperant (recommended once Aperant is installed)

1. Open Aperant.app
2. On first launch: OAuth to your Claude account
3. Add the project: point Aperant at `~/Documents/Orchestrator_Test`
4. Create a new task with this prompt:

```
Read ORCHESTRATOR.md and run shakedown cycles continuously until wave T1 is complete or progress stalls.
Follow ORCHESTRATOR.md exactly. Loop within this session per its multi-cycle rule.
Update STATE/*.json + ORCHESTRATOR_LOG.md every cycle.
Exit cleanly when wave T1 is complete OR you've had 2 consecutive cycles with no progress.
```

5. Hit "Start" or "Run" (depends on Aperant version)
6. Watch the Kanban as the orchestrator dispatches each shakedown

### Option B — Via /loop in Claude Code (auto-fire every 5 min)

```bash
cd ~/Documents/Orchestrator_Test
claude
# Inside the session:
#   /loop 5m Read ORCHESTRATOR.md and run one shakedown cycle. Start with the highest-priority eligible task.
```

The orchestrator runs once every 5 minutes. To stop, type `/loop stop` or close the session.

### Option C — Manual single trigger (most observable)

```bash
cd ~/Documents/Orchestrator_Test
claude
# Inside the session, paste:
```

```
Read ORCHESTRATOR.md and run shakedown cycles continuously until wave T1 is complete or 2 consecutive cycles produce no progress.

Follow ORCHESTRATOR.md exactly. Use its multi-cycle in-session loop per Step 8.
Dispatch executor subagents, AI-review their work via superpowers:code-reviewer (or general-purpose if not installed),
sequential-merge with integration test gate, heal stuck tasks via the two-report double-blind protocol,
log to ORCHESTRATOR_LOG.md every cycle.

Exit cleanly with the summary template at the end of ORCHESTRATOR.md.
```

---

## Phase 8 — What to expect during the run

The orchestrator runs 11 shakedown scenarios. Each is designed to exercise a specific path:

| # | What happens | Expected duration |
|---|---|---|
| 01 | Happy path — succeeds | 5 min |
| 02 | Stuck heal protocol — designed failure on missing file | 10 min |
| 03 | Pattern match (existing P-002) — designed failure on env var | 8 min |
| 04 | Pattern match (new) — designed novel failure; failure-analyst spawns | 15 min |
| 05 | Integration test fail — auto-revert + INTEGRATION_FAILURES log | 12 min |
| 06 | Parallel preflight inheritance | 20 min |
| 07 | Corruption recovery (Phase 1 only on first run) | 15 min |
| 08 | Wave-QA gate — fires after others done | 5 min |
| 09 | Spec-induced stuck — spec-analyst spawns | 12 min |
| 10 | Nested missing structure — STEP 0 self-heal mkdir -p | 10 min |
| 11 | Double-blind diagnostic — Report 1 vs Report 2 differ | 12 min |

**Total wall-clock if everything works first try: ~2 hours.**
**Realistic with iteration: ~3-4 hours.**

Most "designed failures" are scenarios where the executor INTENTIONALLY fails to verify the orchestrator's heal/revert/analyst path. Don't be alarmed when shakedowns fail — that's the point.

---

## Phase 9 — Verify the results

After the orchestrator session ends (or you stop /loop), run this verification block:

```bash
cd ~/Documents/Orchestrator_Test

echo "=== STATE/completed.json ==="
cat STATE/completed.json

echo "=== STATE/stuck.json ==="
cat STATE/stuck.json

echo "=== Markers written ==="
ls MARKERS/

echo "=== PR simulations ==="
ls PR_SIMULATIONS/

echo "=== Stuck reports (should have 2 per stuck task) ==="
ls STUCK_STATE/

echo "=== Failure patterns (look for new P-005 from SHAKEDOWN-04) ==="
grep -c '## Pattern P-' FAILURE_PATTERNS.md

echo "=== Spec lessons (look for L-001 from SHAKEDOWN-09) ==="
grep -c '## Lesson L-' SPEC_LESSONS.md

echo "=== Integration failures (look for SHAKEDOWN-05) ==="
ls INTEGRATION_FAILURES/

echo "=== Git log (squash merges + reverts) ==="
git log --oneline -20

echo "=== Tags (task-merged-, failed-merge-, wave-T1-complete-) ==="
git tag -l 'task-merged-*' 'failed-merge-*' 'wave-T1-*'

echo "=== Orchestrator log (last 100 lines) ==="
tail -100 ORCHESTRATOR_LOG.md
```

Paste the full output back to whoever is helping you analyze this. They can verify each shakedown's expected behavior occurred.

---

## Phase 10 — When something goes wrong

The orchestrator might:
- Fail to dispatch a task (preflight broken; check `preflight.sh --full`)
- Get stuck reading reports in wrong order (re-read ORCHESTRATOR.md Step 6.A/6.B)
- Miss a wave-complete signal (check SHAKEDOWN-08 dependencies — orchestrator may not have all 10 prereqs in completed.json)
- Skip a shakedown silently (check ORCHESTRATOR_LOG.md for ordering decisions logged in Step 4)

For each issue:
1. Capture the orchestrator's chat output
2. Capture the verification block output (Phase 9)
3. Send both to whoever is helping you
4. They can either patch ORCHESTRATOR.md (push to GH) or instruct you on a manual fix

---

## Phase 11 — Cleanup when done

```bash
cd ~
rm -rf Documents/Orchestrator_Test

# Optional: delete or archive the GH repo
gh repo archive layne512/Orchestrator_Test
# or:
gh repo delete layne512/Orchestrator_Test --yes
```

The shakedown infrastructure is throwaway. Once the protocol is validated, the real PeptideOS MVP work happens in `peptide-website` repo per the production design spec.

---

## Quick-reference setup (TL;DR if you've installed Mac dev tools before)

```bash
# Install
xcode-select --install && \
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
brew install gh node && \
gh auth login && \
npm install -g @anthropic-ai/claude-code && \
claude  # OAuth, /exit

# In a fresh claude session: /plugin install superpowers, /exit

# Aperant arm64 (or substitute -x64 for Intel)
cd ~/Downloads && \
curl -L -o Aperant.dmg https://github.com/AndyMik90/Aperant/releases/download/v2.7.6/Auto-Claude-2.7.6-darwin-arm64.dmg && \
hdiutil attach Aperant.dmg && \
cp -R "/Volumes/Auto-Claude 2.7.6/Auto-Claude.app" /Applications/ && \
hdiutil detach "/Volumes/Auto-Claude 2.7.6" && \
rm Aperant.dmg

# Clone + branch
mkdir -p ~/Documents && cd ~/Documents && \
gh repo clone layne512/Orchestrator_Test ./Orchestrator_Test && \
cd Orchestrator_Test && \
git checkout -b sandbox-staging-T1 && \
bash preflight.sh --wave=T1 --baseline

# Trigger via Claude Code (or Aperant — same prompt)
claude
# inside: paste the trigger prompt from Phase 7 Option C
```
