# Claude Code Init v4

Zero-login, zero-telemetry Claude Code setup with externalized provider config and tiered permissions.

## Prerequisites

- macOS 13+ or Linux (Ubuntu 20.04+, Debian 10+) — Windows: use WSL2
- `curl` and `git` installed
- A GLM API key from [open.bigmodel.cn](https://open.bigmodel.cn) or [z.ai](https://z.ai)

## Quick Start

```bash
export GLM_API_KEY="your-key"
bash claude-code-init.sh
source ~/.zshrc     # or ~/.bashrc

ccc glm             # switch to GLM + launch (safe mode)
cccx glm            # switch to GLM + launch (yolo mode)
```

Pin a different version or add other providers:

```bash
CC_VERSION=2.2.0 GLM_API_KEY="..." DEEPSEEK_API_KEY="..." bash claude-code-init.sh
```

---

## Permission Tiers

Default is **safe**. Append `x` to opt into danger.

| Command | Mode | What it does |
|---|---|---|
| `cc` | safe | Launch, asks permission for each tool |
| `ccx` | yolo | Launch, skips ALL permission prompts |
| `ccp` | plan | Read-only — Claude can analyze but not edit |
| `ccc glm` | safe | Switch to GLM + launch |
| `cccx glm` | yolo | Switch to GLM + launch (skip perms) |
| `ccr` | — | Resume last session |
| `ccrs` | — | Resume with session picker |

Use `cc` and `ccc` when exploring unfamiliar code. Use `ccx` and `cccx` on your own trusted projects where permission prompts slow you down.

---

## Provider Management

Providers are plain files in `~/.ccm/providers/`. No code to edit — add, change, or remove a file.

### File format

```bash
# ~/.ccm/providers/glm.env
LABEL="GLM 5.1"
URL_GLOBAL="https://api.z.ai/api/anthropic"
URL_CHINA="https://open.bigmodel.cn/api/anthropic"
MODEL="glm-5.1"
HAIKU="glm-4.5-air"
KEY_VAR="GLM_API_KEY"
```

| Field | Required | Description |
|---|---|---|
| `LABEL` | yes | Display name shown when switching |
| `URL_GLOBAL` | yes | Default API endpoint |
| `URL_CHINA` | no | China endpoint — used with `ccm <name> china` |
| `MODEL` | yes | Model ID sent as opus + sonnet defaults |
| `HAIKU` | no | Fast model ID — defaults to MODEL if omitted |
| `KEY_VAR` | yes | Variable name in `~/.ccm/keys` that holds the API key |
| `DIRECT` | no | Set to `"true"` for providers that use native auth (clears all overrides) |

### Commands

```bash
ccm list              # show all providers + key status
ccm add my-llm        # create provider from template, open in editor
ccm edit glm          # edit existing provider
ccm config            # edit API keys (~/.ccm/keys)
ccm status            # show current active provider
ccm doctor            # validate all providers, keys, and files
```

### Adding a new provider

```bash
ccm add my-llm
```

This creates `~/.ccm/providers/my-llm.env` with a template and opens your editor. Fill in the fields, then add your key:

```bash
ccm config
# Add: MY_PROVIDER_API_KEY="sk-..."
```

Test it:

```bash
ccm my-llm            # switch
ccm status            # verify
ccc my-llm            # switch + launch
```

### Updating a model

When GLM releases 6.0, you don't touch any code:

```bash
ccm edit glm
# Change MODEL="glm-5.1" → MODEL="glm-6.0"
# Save and exit
ccc glm               # uses the new model immediately
```

### API keys

Keys live in `~/.ccm/keys` (chmod 600), separate from provider definitions:

```bash
# ~/.ccm/keys
GLM_API_KEY="your-key"
DEEPSEEK_API_KEY="sk-..."
KIMI_API_KEY=""
```

Provider files reference keys by variable name (`KEY_VAR="GLM_API_KEY"`). This way you can have multiple providers sharing one key, or one provider per key.

---

## What Each Step Does

### [1/8] Preflight

Checks `GLM_API_KEY` is set, `curl` exists, `git` is available.

### [2/8] Install

```bash
curl -fsSL https://claude.ai/install.sh | bash -s -- 2.1.81
```

Downloads the native binary, then `chmod 555` to lock it read-only. The auto-updater can't overwrite a read-only file.

### [3/8] Directories

Creates `~/.claude/` and `~/.ccm/providers/`.

### [4/8] Onboarding bypass

Writes two keys to `~/.claude.json`:

- `hasCompletedOnboarding: true` — bypasses the browser login flow.
- `theme: "dark"` — terminal UI theme. **Note:** theme lives in `~/.claude.json`, not `~/.claude/settings.json`. Putting it in settings.json triggers a schema validation error because theme is a runtime preference, not a documented settings field.

Uses python3 for safe JSON merge if available (preserves any existing OAuth tokens or session state). Falls back to overwrite if python3 isn't installed.

Then creates `api-key-helper.sh` — an official Claude Code feature. When `settings.json` points to this script, Claude Code calls it for the API key instead of running OAuth. No browser. No Anthropic contact.

The actual API key is stored in `~/.claude/.api-key` (chmod 600) and the helper just `cat`s it. This avoids shell escaping issues with special characters in keys.

### [5/8] Provider files

Creates `~/.ccm/providers/*.env` for the 5 default providers (glm, deepseek, kimi, qwen, claude). Only writes files that don't already exist — your edits are preserved on re-run.

### [6/8] Settings

Writes `~/.claude/settings.json` validated against the official schema at `https://json.schemastore.org/claude-code-settings.json`. Contains `apiKeyHelper`, `model`, `env` (telemetry kills), and `permissions`. Theme is **not** here — it lives in `~/.claude.json` (see step 4).

**Telemetry kill chain** (all in the `env` block):

| Variable | Blocks |
|---|---|
| `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` | Statsig, Sentry, `/bug` — primary kill switch |
| `DISABLE_TELEMETRY=1` | General telemetry |
| `CLAUDE_CODE_ENABLE_TELEMETRY=0` | Explicit opt-out |
| `DISABLE_ERROR_REPORTING=1` | Sentry crash reports |
| `DISABLE_BUG_COMMAND=1` | `/bug` data submission |
| `OTEL_SDK_DISABLED=true` | OpenTelemetry SDK (traces, metrics, logs) |
| `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1` | Auto-memory writes + prompt injection |
| `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS=1` | Background agents (autoDream, team memory sync) |

**Auto-update: two layers**

| Layer | Mechanism |
|---|---|
| `DISABLE_AUTOUPDATER=1` | Process env var (only valid disable method per schema) |
| `chmod 555` on binary | Filesystem hard block |

Note: there is no `autoUpdates` field in the official schema. The schema only has `autoUpdatesChannel` (`"stable"` or `"latest"`) which controls *which* version gets installed, not whether updates run. The only documented way to fully disable updates is `DISABLE_AUTOUPDATER=1`. The chmod adds a filesystem-level hard block as a second layer.

> Do NOT set `OTEL_METRICS_EXPORTER=none` — it crashes Claude Code. `OTEL_SDK_DISABLED=true` is the safe alternative.

> Side effect: disabling telemetry also disables GrowthBook feature flags. This blocks some Anthropic-subscription features (Opus 4.6 1M context). Does not affect GLM or other third-party providers.

### [7/8] Shell functions

Appends the `ccm`, `ccc`, `cccx`, and alias block to your shell rc. Re-running the script replaces the old block (also cleans up v3 blocks).

### [8/8] Validation

Checks every file, validates JSON, verifies critical settings, tests the api-key-helper, confirms the binary is read-only, and counts provider files.

---

## How Settings Are Loaded

Claude Code merges settings from multiple sources (higher wins):

```
1. Plugin defaults                              (lowest)
2. ~/.claude/settings.json                      ← init script writes here
3. .claude/settings.json         (project)
4. .claude/settings.local.json   (local)
5. Managed policy settings                      (highest)
```

**Shell environment variables** (set via `ccm` or `export`) override the `env` block in all settings files. This is how `ccm` works — it exports vars that trump the config.

The `env` block in `settings.json` is read at startup and injected into Claude Code's process. If the same variable is already in your shell, the shell version wins.

---

## File Map

```
~/.claude.json                        Onboarding flag
~/.claude/settings.json               Main config (theme, model, telemetry, perms)
~/.claude/api-key-helper.sh           Returns API key → skips login
~/.claude/.api-key                    Raw API key (chmod 600)
~/.ccm/keys                          API keys for all providers (chmod 600)
~/.ccm/providers/glm.env             Provider: GLM 5.1
~/.ccm/providers/deepseek.env        Provider: DeepSeek
~/.ccm/providers/kimi.env            Provider: Kimi
~/.ccm/providers/qwen.env            Provider: Qwen
~/.ccm/providers/claude.env          Provider: direct Anthropic
~/.zshrc or ~/.bashrc                Shell functions block
```

---

## Verify No Anthropic Connections

After `ccc glm` or `cccx glm`:

```bash
# macOS
lsof -i -n -P | grep claude

# Linux
ss -tnp | grep claude
```

You should see connections to Z.AI / your provider. You should NOT see `anthropic.com`, `statsig.com`, `sentry.io`, or `growthbook.io`.

---

## Troubleshooting

**"Settings Error: $schema Invalid value" on launch** — your `settings.json` references the wrong schema URL. The correct one is `https://json.schemastore.org/claude-code-settings.json`. The script v4.1+ uses the right one. If you're upgrading from an older version, re-run the script to regenerate.

**"Missing API key" on launch** — the api-key-helper chain is broken.

```bash
cat ~/.claude/settings.json | grep apiKeyHelper   # path correct?
~/.claude/api-key-helper.sh                        # prints your key?
cat ~/.claude/.api-key                              # raw key present?
```

**Claude Code updated itself** — binary was overwritten.

```bash
cc-pin 2.1.81              # reinstalls + re-locks
```

**`ccm` says "Unknown provider"** — the .env file doesn't exist.

```bash
ccm list                   # see what's available
ls ~/.ccm/providers/       # check files
ccm add my-provider        # create one
```

**`ccm` says key is empty** — key not in `~/.ccm/keys`.

```bash
ccm config                 # opens keys file in editor
ccm doctor                 # validates all providers + keys
```

**"No conversations found" on resume** — sessions are directory-bound. `cd` to the project where you started the session.

**Dark mode washed out over SSH** — script sets `COLORTERM=truecolor`. If still dull on remote, add to the remote's shell config too.

**Project overrides your settings** — check for project-level config:

```bash
cat .claude/settings.json
cat .claude/settings.local.json
```

These override `~/.claude/settings.json` for that project.

**Update to a newer version**

```bash
cc-pin 2.2.0               # unlocks binary, installs, re-locks
```

**Switch to direct Anthropic**

```bash
ccm claude
cc                          # or ccx
# Run /login inside Claude Code to authenticate
```
