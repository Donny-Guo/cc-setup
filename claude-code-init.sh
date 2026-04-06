#!/bin/bash
# ╔════════════════════════════════════════════════════════════╗
# ║  claude-code-init.sh  v4                                   ║
# ║                                                            ║
# ║  Native install only. Pinned version. Zero telemetry.      ║
# ║  Externalized provider config. Tiered permissions.         ║
# ║                                                            ║
# ║  Usage:                                                    ║
# ║    export GLM_API_KEY="your-key"                           ║
# ║    bash claude-code-init.sh                                ║
# ║                                                            ║
# ║  See README.md for full documentation.                     ║
# ╚════════════════════════════════════════════════════════════╝
set -euo pipefail

# ─── Config ──────────────────────────────────────────────────
CC_VERSION="${CC_VERSION:-2.1.81}"
GLM_API_KEY="${GLM_API_KEY:-}"
DEEPSEEK_API_KEY="${DEEPSEEK_API_KEY:-}"
KIMI_API_KEY="${KIMI_API_KEY:-}"
QWEN_API_KEY="${QWEN_API_KEY:-}"
CLAUDE_API_KEY="${CLAUDE_API_KEY:-}"
PREFERRED_THEME="${PREFERRED_THEME:-dark}"

# ─── Helpers ─────────────────────────────────────────────────
RED='\033[0;31m'; GRN='\033[0;32m'; YLW='\033[0;33m'; RST='\033[0m'
ok()   { printf "  ${GRN}✓${RST} %s\n" "$*"; }
warn() { printf "  ${YLW}!${RST} %s\n" "$*"; }
err()  { printf "  ${RED}✗${RST} %s\n" "$*"; }
die()  { err "$*"; exit 1; }

if [[ "${SHELL:-/bin/bash}" == *zsh* ]]; then SHELL_RC="$HOME/.zshrc"
else SHELL_RC="$HOME/.bashrc"; fi
touch "$SHELL_RC"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Code Init v4 — pinned to $CC_VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ═════════════════════════════════════════════════════════════
# [1/8] Preflight
# ═════════════════════════════════════════════════════════════
echo "[1/8] Preflight"
[ -z "$GLM_API_KEY" ] && die "GLM_API_KEY is empty. Export it first."
ok "GLM_API_KEY set (${#GLM_API_KEY} chars)"
command -v curl &>/dev/null || die "curl required"
ok "curl found"
command -v git &>/dev/null && ok "git found" || warn "git not found — Claude Code needs it"
echo ""

# ═════════════════════════════════════════════════════════════
# [2/8] Install native binary
# ═════════════════════════════════════════════════════════════
echo "[2/8] Install Claude Code $CC_VERSION"
curl -fsSL https://claude.ai/install.sh | bash -s -- "$CC_VERSION"
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"

CLAUDE_BIN="$(command -v claude 2>/dev/null || true)"
[ -z "$CLAUDE_BIN" ] && die "claude not found on PATH after install"
ok "installed: $CLAUDE_BIN"

if chmod 555 "$CLAUDE_BIN" 2>/dev/null; then
    ok "binary locked read-only (chmod 555)"
else
    warn "could not chmod binary"
fi
echo ""

# ═════════════════════════════════════════════════════════════
# [3/8] Directories
# ═════════════════════════════════════════════════════════════
echo "[3/8] Directories"
mkdir -p "$HOME/.claude/agents"
mkdir -p "$HOME/.ccm/providers"
ok "~/.claude/ and ~/.ccm/providers/ ready"
echo ""

# ═════════════════════════════════════════════════════════════
# [4/8] Onboarding bypass + API key helper
# ═════════════════════════════════════════════════════════════
echo "[4/8] Onboarding bypass"

CLAUDE_JSON="$HOME/.claude.json"
[ -f "$CLAUDE_JSON" ] && cp "$CLAUDE_JSON" "${CLAUDE_JSON}.bak"

if command -v python3 &>/dev/null; then
    python3 << 'PYEOF'
import json, os
path = os.path.expanduser("~/.claude.json")
try:
    with open(path) as f:
        data = json.load(f)
except Exception:
    data = {}
data["hasCompletedOnboarding"] = True
with open(path, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
    ok "hasCompletedOnboarding → true (merged)"
else
    printf '{\n  "hasCompletedOnboarding": true\n}\n' > "$CLAUDE_JSON"
    ok "hasCompletedOnboarding → true (created)"
fi

cat > "$HOME/.claude/api-key-helper.sh" << 'KEYEOF'
#!/bin/bash
cat "$HOME/.claude/.api-key"
KEYEOF
chmod 700 "$HOME/.claude/api-key-helper.sh"
printf '%s' "$GLM_API_KEY" > "$HOME/.claude/.api-key"
chmod 600 "$HOME/.claude/.api-key"
ok "api-key-helper → reads ~/.claude/.api-key"
echo ""

# ═════════════════════════════════════════════════════════════
# [5/8] Provider files (~/.ccm/providers/*.env)
# ═════════════════════════════════════════════════════════════
echo "[5/8] Provider definitions"
echo ""
echo "  Each provider is a file in ~/.ccm/providers/"
echo "  Add/edit providers without touching any code."
echo ""

# Only write provider files that don't already exist (preserve user edits).
_write_provider() {
    local name="$1" content="$2"
    local path="$HOME/.ccm/providers/${name}.env"
    if [ -f "$path" ]; then
        ok "$name.env exists — keeping"
    else
        printf '%s\n' "$content" > "$path"
        ok "$name.env created"
    fi
}

_write_provider "glm" '# GLM 5.1 (Z.AI)
# Docs: https://open.bigmodel.cn
LABEL="GLM 5.1"
URL_GLOBAL="https://api.z.ai/api/anthropic"
URL_CHINA="https://open.bigmodel.cn/api/anthropic"
MODEL="glm-5.1"
HAIKU="glm-4.5-air"
KEY_VAR="GLM_API_KEY"'

_write_provider "deepseek" '# DeepSeek
# Docs: https://platform.deepseek.com
LABEL="DeepSeek"
URL_GLOBAL="https://api.deepseek.com/anthropic"
URL_CHINA=""
MODEL="deepseek-chat"
HAIKU="deepseek-chat"
KEY_VAR="DEEPSEEK_API_KEY"'

_write_provider "kimi" '# Kimi K2.5 (Moonshot)
# Docs: https://platform.moonshot.cn
LABEL="Kimi K2.5"
URL_GLOBAL="https://api.moonshot.ai/anthropic"
URL_CHINA="https://api.moonshot.cn/anthropic"
MODEL="kimi-k2.5"
HAIKU="kimi-k2.5"
KEY_VAR="KIMI_API_KEY"'

_write_provider "qwen" '# Qwen Coder (Alibaba)
# Docs: https://dashscope.console.aliyun.com
LABEL="Qwen Coder"
URL_GLOBAL="https://coding-intl.dashscope.aliyuncs.com/apps/anthropic"
URL_CHINA="https://coding.dashscope.aliyuncs.com/apps/anthropic"
MODEL="qwen3-coder-plus"
HAIKU="qwen3-coder-plus"
KEY_VAR="QWEN_API_KEY"'

_write_provider "claude" '# Claude (direct Anthropic)
# Uses native auth — clears all provider overrides.
LABEL="Claude (Anthropic)"
DIRECT="true"
KEY_VAR="CLAUDE_API_KEY"'

echo ""

# Write API keys file
KEYS_FILE="$HOME/.ccm/keys"
if [ ! -f "$KEYS_FILE" ]; then
    {
        echo "# Claude Code Switch — API keys (chmod 600)"
        echo "# Edit: ccm config"
        printf 'GLM_API_KEY=%q\n' "$GLM_API_KEY"
        printf 'DEEPSEEK_API_KEY=%q\n' "$DEEPSEEK_API_KEY"
        printf 'KIMI_API_KEY=%q\n' "$KIMI_API_KEY"
        printf 'QWEN_API_KEY=%q\n' "$QWEN_API_KEY"
        printf 'CLAUDE_API_KEY=%q\n' "$CLAUDE_API_KEY"
    } > "$KEYS_FILE"
    chmod 600 "$KEYS_FILE"
    ok "~/.ccm/keys created (chmod 600)"
else
    ok "~/.ccm/keys already exists"
fi
echo ""

# ═════════════════════════════════════════════════════════════
# [6/8] settings.json
# ═════════════════════════════════════════════════════════════
echo "[6/8] Settings"

[ -f "$HOME/.claude/settings.json" ] && cp "$HOME/.claude/settings.json" "$HOME/.claude/settings.json.bak"

cat > "$HOME/.claude/settings.json" << SETTINGSEOF
{
  "\$schema": "https://schemas.anthropic.com/claude-code/settings.json",

  "apiKeyHelper": "$HOME/.claude/api-key-helper.sh",

  "theme": "$PREFERRED_THEME",
  "alwaysThinkingEnabled": true,
  "autoUpdates": false,

  "env": {
    "ANTHROPIC_BASE_URL":                       "https://api.z.ai/api/anthropic",
    "DISABLE_AUTOUPDATER":                      "1",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
    "DISABLE_TELEMETRY":                        "1",
    "CLAUDE_CODE_ENABLE_TELEMETRY":             "0",
    "DISABLE_ERROR_REPORTING":                  "1",
    "DISABLE_BUG_COMMAND":                      "1",
    "OTEL_SDK_DISABLED":                        "true",
    "CLAUDE_CODE_DISABLE_AUTO_MEMORY":          "1",
    "CLAUDE_CODE_DISABLE_BACKGROUND_TASKS":     "1",
    "API_TIMEOUT_MS":                           "300000"
  },

  "models": {
    "default": "glm-5.1",
    "fast":    "glm-4.5-air",
    "smart":   "glm-5.1"
  },

  "permissions": {
    "allow": [
      "Bash(git *)",
      "Bash(npm run *)",
      "Bash(npx *)",
      "Bash(node *)",
      "Bash(cat *)",
      "Bash(ls *)",
      "Bash(find *)",
      "Bash(grep *)"
    ],
    "deny": [
      "Bash(rm -rf /)",
      "Bash(rm -rf ~)",
      "Bash(sudo rm *)",
      "Read(**/.env)"
    ]
  }
}
SETTINGSEOF

ok "model: glm-5.1 → api.z.ai"
ok "telemetry: 8 kill vars set"
ok "auto-update: 3 layers (config + env + chmod)"
echo ""

# ═════════════════════════════════════════════════════════════
# [7/8] Shell functions
# ═════════════════════════════════════════════════════════════
echo "[7/8] Shell functions → $SHELL_RC"

MARKER="# === Claude Code Init v4 ==="
END_MARKER="# === End Claude Code Init v4 ==="

# Also clean up v3 blocks
for M in "# === Claude Code Init v3 ===" "# === Claude Code Init v4 ==="; do
    EM="${M/Init/End Init}"
    if grep -qF "$M" "$SHELL_RC" 2>/dev/null; then
        if [[ "$OSTYPE" == darwin* ]]; then
            sed -i '' "/$M/,/$EM/d" "$SHELL_RC"
        else
            sed -i "/$M/,/$EM/d" "$SHELL_RC"
        fi
    fi
done

cat >> "$SHELL_RC" << 'RCEOF'

# === Claude Code Init v4 ===
export PATH="$HOME/.local/bin:$HOME/.claude/bin:$PATH"
export COLORTERM=truecolor

# ── _ccm_switch: internal — reads provider .env, exports 7 vars ──
_ccm_switch() {
    local provider="$1" region="${2:-global}"
    local pfile="$HOME/.ccm/providers/${provider}.env"

    if [ ! -f "$pfile" ]; then
        printf '✗ Unknown provider: %s\n' "$provider"
        printf '  Run: ccm list\n'
        return 1
    fi

    # Source keys
    [ -f "$HOME/.ccm/keys" ] && source "$HOME/.ccm/keys"

    # Source provider into current scope
    local LABEL="" URL_GLOBAL="" URL_CHINA="" MODEL="" HAIKU="" KEY_VAR="" DIRECT=""
    source "$pfile"

    # Handle "direct" providers (e.g., claude) — clear all overrides
    if [ "$DIRECT" = "true" ]; then
        unset ANTHROPIC_BASE_URL ANTHROPIC_AUTH_TOKEN ANTHROPIC_MODEL 2>/dev/null || true
        unset ANTHROPIC_DEFAULT_OPUS_MODEL ANTHROPIC_DEFAULT_SONNET_MODEL 2>/dev/null || true
        unset ANTHROPIC_DEFAULT_HAIKU_MODEL CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 2>/dev/null || true
        if [ -n "$KEY_VAR" ]; then
            local key=""
            if [ -n "${ZSH_VERSION:-}" ]; then key="${(P)KEY_VAR}"
            else eval "key=\${$KEY_VAR:-}"; fi
            [ -n "$key" ] && export ANTHROPIC_API_KEY="$key"
        fi
        printf '✅ %s\n' "${LABEL:-$provider}"
        return 0
    fi

    # Resolve URL by region
    local url="$URL_GLOBAL"
    if [ "$region" = "china" ]; then
        if [ -n "$URL_CHINA" ]; then url="$URL_CHINA"
        else printf '  ⚠ No china endpoint for %s, using global\n' "$provider"; fi
    fi

    # Resolve API key via indirect expansion (bash/zsh compatible)
    local token=""
    if [ -n "$KEY_VAR" ]; then
        if [ -n "${ZSH_VERSION:-}" ]; then token="${(P)KEY_VAR}"
        else eval "token=\${$KEY_VAR:-}"; fi
    fi

    # Validate key
    if [ -z "$token" ]; then
        printf '✗ %s is empty — run: ccm config\n' "$KEY_VAR"
        return 1
    fi

    # Validate URL
    if [ -z "$url" ]; then
        printf '✗ No URL defined for %s (%s)\n' "$provider" "$region"
        return 1
    fi

    # Export the 7 standard env vars
    export ANTHROPIC_BASE_URL="$url"
    export ANTHROPIC_AUTH_TOKEN="$token"
    export ANTHROPIC_MODEL="${MODEL:-}"
    export ANTHROPIC_DEFAULT_OPUS_MODEL="${MODEL:-}"
    export ANTHROPIC_DEFAULT_SONNET_MODEL="${MODEL:-}"
    export ANTHROPIC_DEFAULT_HAIKU_MODEL="${HAIKU:-$MODEL}"
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
    unset ANTHROPIC_API_KEY 2>/dev/null || true

    printf '✅ %s (%s) → %s\n' "${LABEL:-$provider}" "$region" "$url"
}

# ── ccm: main command ────────────────────────────────────────
ccm() {
    local cmd="${1:-help}"
    case "$cmd" in

        # ── Switch provider ──────────────────────────────
        # ccm <name> → treated as provider if .env exists
        glm|deepseek|kimi|qwen|claude)
            _ccm_switch "$@"
            ;;

        # ── List all providers ───────────────────────────
        list)
            [ -f "$HOME/.ccm/keys" ] && source "$HOME/.ccm/keys"
            printf '\n  %-14s %-22s %s\n' "PROVIDER" "MODEL" "KEY"
            printf '  %-14s %-22s %s\n' "────────" "─────" "───"
            for f in "$HOME/.ccm/providers/"*.env; do
                [ -f "$f" ] || continue
                local LABEL="" MODEL="" KEY_VAR="" DIRECT="" URL_GLOBAL="" URL_CHINA="" HAIKU=""
                source "$f"
                local name; name="$(basename "$f" .env)"
                local key_status="✗ not set"
                if [ -n "$KEY_VAR" ]; then
                    local val=""
                    if [ -n "${ZSH_VERSION:-}" ]; then val="${(P)KEY_VAR}"
                    else eval "val=\${$KEY_VAR:-}"; fi
                    [ -n "$val" ] && key_status="✓ set"
                fi
                [ "$DIRECT" = "true" ] && MODEL="(native)"
                printf '  %-14s %-22s %s\n' "$name" "${MODEL:-?}" "$key_status"
            done
            printf '\n'
            ;;

        # ── Add new provider ─────────────────────────────
        add)
            local name="${2:-}"
            [ -z "$name" ] && { printf 'Usage: ccm add <name>\n'; return 1; }
            local path="$HOME/.ccm/providers/${name}.env"
            if [ -f "$path" ]; then
                printf 'Provider %s already exists. Use: ccm edit %s\n' "$name" "$name"
                return 1
            fi
            cat > "$path" << 'TMPLEOF'
# Provider template — fill in and save.
# Run "ccm list" to verify, then "ccc <name>" to use.

LABEL="My Provider"
URL_GLOBAL="https://api.example.com/anthropic"
URL_CHINA=""
MODEL="model-name"
HAIKU="model-name"
KEY_VAR="MY_PROVIDER_API_KEY"

# Set DIRECT="true" to clear all overrides (like the claude provider).
# DIRECT=""
TMPLEOF
            printf '✓ Created %s\n' "$path"
            printf '  Add your key to ~/.ccm/keys:\n'
            printf '  MY_PROVIDER_API_KEY="sk-..."\n\n'
            "${EDITOR:-vi}" "$path"
            ;;

        # ── Edit provider / keys ─────────────────────────
        edit)
            local name="${2:-}"
            [ -z "$name" ] && { printf 'Usage: ccm edit <name>\n'; return 1; }
            local path="$HOME/.ccm/providers/${name}.env"
            [ ! -f "$path" ] && { printf '✗ Provider %s not found\n' "$name"; return 1; }
            "${EDITOR:-vi}" "$path"
            ;;

        config)
            "${EDITOR:-vi}" "$HOME/.ccm/keys"
            ;;

        # ── Status ───────────────────────────────────────
        status)
            printf '  model:   %s\n' "${ANTHROPIC_MODEL:-<Claude default>}"
            printf '  url:     %s\n' "${ANTHROPIC_BASE_URL:-<api.anthropic.com>}"
            printf '  token:   %s\n' "$([ -n "${ANTHROPIC_AUTH_TOKEN:-}" ] && echo set || echo NOT_SET)"
            printf '  api-key: %s\n' "$([ -n "${ANTHROPIC_API_KEY:-}" ] && echo set || echo not_set)"
            ;;

        # ── Doctor ───────────────────────────────────────
        doctor)
            printf '\n  Checking providers...\n'
            [ -f "$HOME/.ccm/keys" ] && source "$HOME/.ccm/keys"
            local errs=0
            for f in "$HOME/.ccm/providers/"*.env; do
                [ -f "$f" ] || continue
                local LABEL="" URL_GLOBAL="" URL_CHINA="" MODEL="" HAIKU="" KEY_VAR="" DIRECT=""
                source "$f"
                local name; name="$(basename "$f" .env)"
                local issues=""
                [ "$DIRECT" != "true" ] && [ -z "$URL_GLOBAL" ] && issues="${issues} no_url"
                [ "$DIRECT" != "true" ] && [ -z "$MODEL" ] && issues="${issues} no_model"
                if [ -n "$KEY_VAR" ]; then
                    local val=""
                    if [ -n "${ZSH_VERSION:-}" ]; then val="${(P)KEY_VAR}"
                    else eval "val=\${$KEY_VAR:-}"; fi
                    [ -z "$val" ] && issues="${issues} empty_key($KEY_VAR)"
                fi
                if [ -z "$issues" ]; then printf '  ✓ %s\n' "$name"
                else printf '  ✗ %s:%s\n' "$name" "$issues"; errs=$((errs+1)); fi
            done

            printf '\n  Checking files...\n'
            for f in "$HOME/.claude.json" "$HOME/.claude/settings.json" "$HOME/.claude/api-key-helper.sh" "$HOME/.claude/.api-key"; do
                [ -f "$f" ] && printf '  ✓ %s\n' "$f" || { printf '  ✗ MISSING %s\n' "$f"; errs=$((errs+1)); }
            done

            printf '\n  Checking binary...\n'
            local bin; bin="$(command -v claude 2>/dev/null || true)"
            if [ -n "$bin" ]; then
                printf '  ✓ %s\n' "$bin"
                [ ! -w "$bin" ] && printf '  ✓ read-only (update-proof)\n' || printf '  ! writable (updater may overwrite)\n'
            else
                printf '  ✗ claude not on PATH\n'; errs=$((errs+1))
            fi

            printf '\n'
            [ "$errs" -eq 0 ] && printf '  All checks passed.\n\n' || printf '  %d issue(s) found.\n\n' "$errs"
            ;;

        # ── Help ─────────────────────────────────────────
        help|--help|-h|"")
            printf 'ccm — Claude Code model switcher\n\n'
            printf '  ccm <provider> [region]   switch (glm, deepseek, kimi, qwen, claude)\n'
            printf '  ccm list                  show all providers\n'
            printf '  ccm add <name>            create new provider\n'
            printf '  ccm edit <name>           edit provider file\n'
            printf '  ccm config                edit API keys\n'
            printf '  ccm status                show current env\n'
            printf '  ccm doctor                validate everything\n\n'
            ;;

        # ── Unknown → try as provider name ───────────────
        *)
            if [ -f "$HOME/.ccm/providers/${cmd}.env" ]; then
                _ccm_switch "$@"
            else
                printf '✗ Unknown command or provider: %s\n' "$cmd"
                printf '  Run: ccm list  or  ccm help\n'
                return 1
            fi
            ;;
    esac
}

# ── Launch commands: safe by default, "x" suffix = yolo ──────
# cc  = normal (asks permissions)
# ccx = yolo   (--dangerously-skip-permissions)
# ccp = plan   (read-only, no edits)
alias cc="claude"
alias ccx="claude --dangerously-skip-permissions"
alias ccp="claude --permission-mode plan"
alias ccr="claude --continue"
alias ccrs="claude --resume"

# ccc  = switch + launch (safe)
# cccx = switch + launch (yolo)
ccc() {
    [ $# -eq 0 ] && { printf 'ccc <provider> [region]\n'; return 1; }
    local args=()
    while [ $# -gt 0 ]; do args+=("$1"); shift; done
    _ccm_switch "${args[@]}" && claude
}
cccx() {
    [ $# -eq 0 ] && { printf 'cccx <provider> [region]\n'; return 1; }
    local args=()
    while [ $# -gt 0 ]; do args+=("$1"); shift; done
    _ccm_switch "${args[@]}" && claude --dangerously-skip-permissions
}

# ── Version management ───────────────────────────────────────
cc-pin() {
    [ -z "${1:-}" ] && { printf 'Usage: cc-pin <version>\n'; return 1; }
    local bin; bin="$(command -v claude 2>/dev/null || true)"
    [ -n "$bin" ] && chmod 755 "$bin" 2>/dev/null
    curl -fsSL https://claude.ai/install.sh | bash -s -- "$1"
    bin="$(command -v claude 2>/dev/null || true)"
    [ -n "$bin" ] && chmod 555 "$bin" 2>/dev/null
}

# === End Claude Code Init v4 ===
RCEOF

ok "shell functions written"
echo ""

# ═════════════════════════════════════════════════════════════
# [8/8] Validate
# ═════════════════════════════════════════════════════════════
echo "[8/8] Validation"

ERRORS=0

# Files
for f in "$HOME/.claude.json" "$HOME/.claude/settings.json" "$HOME/.claude/api-key-helper.sh" "$HOME/.claude/.api-key" "$HOME/.ccm/keys"; do
    if [ -f "$f" ]; then ok "exists: $f"
    else err "MISSING: $f"; ERRORS=$((ERRORS + 1)); fi
done

# Providers
PCOUNT=$(find "$HOME/.ccm/providers" -name '*.env' 2>/dev/null | wc -l | tr -d ' ')
ok "$PCOUNT provider(s) in ~/.ccm/providers/"

# JSON
if command -v python3 &>/dev/null; then
    for f in "$HOME/.claude/settings.json" "$HOME/.claude.json"; do
        if python3 -c "import json; json.load(open('$(printf '%s' "$f")'))" 2>/dev/null; then
            ok "valid JSON: $f"
        else
            err "INVALID JSON: $f"; ERRORS=$((ERRORS + 1))
        fi
    done
fi

# Critical settings
SF="$HOME/.claude/settings.json"
_chk() { grep -q "$1" "$SF" 2>/dev/null && ok "$2" || warn "$2 — not found"; }
_chk '"autoUpdates": false'                          "autoUpdates: false"
_chk 'DISABLE_AUTOUPDATER'                           "DISABLE_AUTOUPDATER"
_chk 'CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC'      "nonessential traffic blocked"
_chk 'DISABLE_TELEMETRY'                             "telemetry disabled"
_chk 'OTEL_SDK_DISABLED'                             "OpenTelemetry killed"
_chk 'CLAUDE_CODE_DISABLE_AUTO_MEMORY'               "auto-memory disabled"
_chk 'CLAUDE_CODE_DISABLE_BACKGROUND_TASKS'          "background tasks disabled"
_chk 'glm-5.1'                                       "model: glm-5.1"
_chk 'api.z.ai'                                       "base URL: api.z.ai"

# Onboarding
grep -q 'hasCompletedOnboarding' "$HOME/.claude.json" 2>/dev/null \
    && ok "onboarding bypass" || { err "onboarding bypass MISSING"; ERRORS=$((ERRORS + 1)); }

# Key helper
KEY_OUT="$("$HOME/.claude/api-key-helper.sh" 2>/dev/null || true)"
[ -n "$KEY_OUT" ] && ok "api-key-helper returns key (${#KEY_OUT} chars)" \
    || { err "api-key-helper returns EMPTY"; ERRORS=$((ERRORS + 1)); }

# Binary lock
if [ -n "${CLAUDE_BIN:-}" ] && [ ! -w "$CLAUDE_BIN" ]; then
    ok "binary read-only"
elif [ -n "${CLAUDE_BIN:-}" ]; then
    warn "binary writable"
fi

# Shell block
grep -qF "Claude Code Init v4" "$SHELL_RC" 2>/dev/null \
    && ok "v4 block in $SHELL_RC" \
    || { err "v4 block not in $SHELL_RC"; ERRORS=$((ERRORS + 1)); }

echo ""
if [ "$ERRORS" -gt 0 ]; then
    err "$ERRORS error(s) — review above"
else
    ok "all checks passed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Done. Run:  source $SHELL_RC"
echo ""
echo "  ┌──────────────────┬──────────────────────────────────┐"
echo "  │  SAFE (default)  │  YOLO (x suffix)                 │"
echo "  ├──────────────────┼──────────────────────────────────┤"
echo "  │  cc              │  ccx     ← skip all permissions  │"
echo "  │  ccc glm         │  cccx glm                        │"
echo "  │  ccp (plan mode) │                                  │"
echo "  ├──────────────────┼──────────────────────────────────┤"
echo "  │  ccm glm [china] │  switch provider                 │"
echo "  │  ccm list        │  show all providers              │"
echo "  │  ccm add <name>  │  create new provider             │"
echo "  │  ccm config      │  edit API keys                   │"
echo "  │  ccm doctor      │  validate everything             │"
echo "  │  cc-pin 2.1.81   │  pin version (unlock+install+lock)│"
echo "  └──────────────────┴──────────────────────────────────┘"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
