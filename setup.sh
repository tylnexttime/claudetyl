#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# ClaudeTyl — Setup Script (Linux/macOS)
#
# Sets up Claude's persistent memory system:
# 1. Check Python 3.9+
# 2. Set CLAUDETYL_HOME environment variable
# 3. Copy template DB to get started immediately
# 4. Extract and run bootstrap (workspace, venv, CLAUDE.md)
# 5. Check/guide rclone + Google Drive sync setup
# 6. Verify everything works
#
# Safe to run multiple times (idempotent).
#
# Usage:
#   bash setup-local.sh                     # Standard setup
#   bash setup-local.sh --home /custom/path # Custom base dir
#   bash setup-local.sh --skip-sync         # Skip rclone setup
# ─────────────────────────────────────────────────────────────
set -euo pipefail

CUSTOM_HOME=""
SKIP_SYNC=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --home)       CUSTOM_HOME="$2"; shift 2 ;;
        --skip-sync)  SKIP_SYNC=true; shift ;;
        -h|--help)    echo "Usage: bash setup-local.sh [--home DIR] [--skip-sync]"; exit 0 ;;
        *)            echo "Unknown option: $1"; exit 1 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DB="$SCRIPT_DIR/claude-memory-template.db"

echo ""
echo "  ClaudeTyl — Memory System Setup"
echo "  ================================"
echo ""

# ─── Verify template DB exists ────────────────────────────────
if [[ ! -f "$TEMPLATE_DB" ]]; then
    echo "  [!!] claude-memory-template.db not found in repo"
    echo "       Make sure you're running this from the cloned repo directory."
    exit 1
fi

# ─── Step 1: Determine CLAUDETYL_HOME ────────────────────────
if [[ -n "$CUSTOM_HOME" ]]; then
    HOME_DIR="$CUSTOM_HOME"
elif [[ -n "${CLAUDETYL_HOME:-}" ]]; then
    HOME_DIR="$CLAUDETYL_HOME"
else
    HOME_DIR="$HOME/.claudetyl"
fi

echo "  CLAUDETYL_HOME: $HOME_DIR"
echo ""

# ─── Step 2: Check Python 3.9+ ───────────────────────────────
echo "  Checking prerequisites..."
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>&1)
    PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$PY_MINOR" -ge 9 ]]; then
        echo "  [OK] $PY_VER"
    else
        echo "  [!!] Python 3.9+ required, found $PY_VER"
        exit 1
    fi
else
    echo "  [!!] Python3 not found"
    echo "       Install: sudo apt install python3 (Ubuntu) or brew install python3 (macOS)"
    exit 1
fi

echo ""

# ─── Step 3: Create directory ─────────────────────────────────
mkdir -p "$HOME_DIR"

# ─── Step 4: Set CLAUDETYL_HOME in shell profile ─────────────
PROFILE=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    PROFILE="$HOME/.bashrc"
else
    PROFILE="$HOME/.bashrc"
fi

if ! grep -q 'CLAUDETYL_HOME' "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# ClaudeTyl Memory System" >> "$PROFILE"
    echo "export CLAUDETYL_HOME=\"$HOME_DIR\"" >> "$PROFILE"
    echo "  Added CLAUDETYL_HOME to $PROFILE"
else
    echo "  CLAUDETYL_HOME already in $PROFILE"
fi
export CLAUDETYL_HOME="$HOME_DIR"

# ─── Step 5: Copy template DB ────────────────────────────────
DB_PATH="$HOME_DIR/claude-memory.db"

if [[ ! -f "$DB_PATH" ]]; then
    cp "$TEMPLATE_DB" "$DB_PATH"
    SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH")
    echo "  [OK] Template DB copied: $((SIZE / 1024)) KB"
else
    SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH")
    echo "  [i] DB already exists: $((SIZE / 1024)) KB (keeping existing)"
fi

echo ""

# ─── Step 6: Extract bootstrap and run it ─────────────────────
echo "  Extracting and running bootstrap..."

WS="$HOME_DIR/workspace"
BOOTSTRAP_TEMP="$HOME_DIR/_bootstrap_temp.py"

python3 -c "
import sqlite3, sys
db = '$DB_PATH'
try:
    c = sqlite3.connect(db)
    r = c.execute(\"SELECT source_code FROM code_modules WHERE module_name='bootstrap'\").fetchone()
    if not r:
        print('ERROR: bootstrap module not found in DB')
        sys.exit(1)
    with open('$BOOTSTRAP_TEMP', 'w', encoding='utf-8') as f:
        f.write(r[0])
    c.close()
    print('  Extracted bootstrap.py')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
"

if [[ ! -f "$BOOTSTRAP_TEMP" ]]; then
    echo "  [!!] Failed to extract bootstrap.py"
    exit 1
fi

python3 "$BOOTSTRAP_TEMP" --target="$WS"
rm -f "$BOOTSTRAP_TEMP"

echo ""

# ─── Step 7: Set up rclone + Google Drive sync ───────────────
if ! $SKIP_SYNC; then
    echo "  Setting up Google Drive sync..."
    echo ""
    echo "  Claude's memory can sync to Google Drive so it persists across machines."
    echo "  This requires rclone (a free, open-source cloud sync tool)."
    echo ""

    HAS_RCLONE=false
    if command -v rclone &>/dev/null; then
        RCLONE_VER=$(rclone version 2>&1 | head -1)
        echo "  [OK] $RCLONE_VER"
        HAS_RCLONE=true
    else
        echo "  [--] rclone not installed"
        echo ""
        echo "  To install rclone:"
        echo "    curl https://rclone.org/install.sh | sudo bash   (Linux)"
        echo "    brew install rclone                               (macOS)"
        echo ""
        echo "  After installing, run this setup again or configure manually:"
        echo "    rclone config    (create a remote named 'gdrive', type: Google Drive)"
        echo ""
    fi

    if $HAS_RCLONE; then
        if rclone listremotes 2>/dev/null | grep -q 'gdrive:'; then
            echo "  [OK] rclone remote 'gdrive' configured"
            echo ""
            echo "  Drive sync is ready. Claude can use these commands:"
            echo "    python3 claude_drive_sync.py push   # Upload DB to Drive"
            echo "    python3 claude_drive_sync.py pull   # Download DB from Drive"
        else
            echo "  [--] rclone installed but 'gdrive' remote not configured"
            echo ""
            echo "  To set up Google Drive sync:"
            echo "    1. Run: rclone config"
            echo "    2. Choose: n (new remote)"
            echo "    3. Name:  gdrive"
            echo "    4. Type:  drive (Google Drive)"
            echo "    5. Accept defaults, authorize in browser when prompted"
            echo ""
            echo "  After configuring, Claude can sync automatically."
        fi
    fi

    echo ""
else
    echo "  Skipped Drive sync setup (--skip-sync)"
    echo ""
fi

# ─── Step 8: Verify ──────────────────────────────────────────
echo "  Verifying installation..."

CHECKS_PASSED=0
CHECKS_TOTAL=3

if [[ -f "$WS/claude_primer.py" ]]; then
    echo "  [OK] Workspace extracted"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] claude_primer.py not found in workspace"
fi

if [[ -f "$WS/paths.py" ]]; then
    echo "  [OK] paths.py present"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] paths.py not found"
fi

if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    echo "  [OK] CLAUDE.md generated"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] CLAUDE.md not found"
fi

echo ""
echo "  ================================"

if [[ "$CHECKS_PASSED" -eq "$CHECKS_TOTAL" ]]; then
    echo "  Setup complete! ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
else
    echo "  Setup finished with warnings ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
fi

echo ""
echo "  Next steps:"
echo "    1. Reload shell:  source $PROFILE"
echo "    2. Open Claude Code in any project directory"
echo "    3. Claude will load its memories automatically via CLAUDE.md"
echo ""
