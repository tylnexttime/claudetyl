#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# Claude Memory System — Linux/macOS Setup
#
# Checks prerequisites (Python 3.9+, rclone, gdrive remote),
# sets CLAUDETYL_HOME, downloads claude-memory.db from Google Drive,
# extracts workspace code, creates virtualenv, and verifies.
#
# Safe to run multiple times (idempotent).
#
# Usage:
#   bash setup.sh                              # Standard setup
#   bash setup.sh --home /custom/path          # Custom base dir
#   bash setup.sh --force                      # Re-download DB
# ─────────────────────────────────────────────────────────────
set -euo pipefail

# ─── Parse arguments ────────────────────────────────────────
CUSTOM_HOME=""
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --home)    CUSTOM_HOME="$2"; shift 2 ;;
        --force)   FORCE=true; shift ;;
        -h|--help) echo "Usage: bash setup.sh [--home DIR] [--force]"; exit 0 ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

echo ""
echo "  Claude Memory System — Linux/macOS Setup"
echo "  ========================================="
echo ""

# ─── Step 1: Determine CLAUDETYL_HOME ───────────────────────
# Priority: --home flag > env var > default ~/.claudetyl
if [[ -n "$CUSTOM_HOME" ]]; then
    HOME_DIR="$CUSTOM_HOME"
elif [[ -n "${CLAUDETYL_HOME:-}" ]]; then
    HOME_DIR="$CLAUDETYL_HOME"
else
    HOME_DIR="$HOME/.claudetyl"
fi

echo "  CLAUDETYL_HOME: $HOME_DIR"
echo ""

# ─── Step 2: Check Python 3.9+ ──────────────────────────────
echo "  Checking prerequisites..."
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>&1)
    PY_MINOR=$(python3 -c "import sys; print(sys.version_info.minor)")
    if [[ "$PY_MINOR" -ge 9 ]]; then
        echo "  [OK] $PY_VER"
    else
        echo "  [!!] Python 3.9+ required, found $PY_VER"
        echo "       Install: sudo apt install python3 (Ubuntu)"
        echo "                brew install python3 (macOS)"
        exit 1
    fi
else
    echo "  [!!] Python3 not found"
    echo "       Install: sudo apt install python3 (Ubuntu)"
    echo "                brew install python3 (macOS)"
    exit 1
fi

# ─── Step 3: Check rclone ───────────────────────────────────
# rclone handles Google Drive sync
if command -v rclone &>/dev/null; then
    RCLONE_VER=$(rclone version 2>&1 | head -1)
    echo "  [OK] $RCLONE_VER"
else
    echo "  [!!] rclone not found"
    echo "       Install: curl https://rclone.org/install.sh | sudo bash"
    echo "                or: sudo apt install rclone (Ubuntu)"
    echo "                or: brew install rclone (macOS)"
    exit 1
fi

# ─── Step 4: Check rclone gdrive remote ─────────────────────
# The 'gdrive' remote must point to your Google Drive
if rclone listremotes 2>/dev/null | grep -q 'gdrive:'; then
    echo "  [OK] rclone remote 'gdrive' configured"
else
    echo "  [!!] rclone remote 'gdrive' not configured"
    echo ""
    echo "  You need to set up a Google Drive remote named 'gdrive'."
    echo "  Run:"
    echo ""
    echo "    rclone config"
    echo ""
    echo "  Choose: n (new), name: gdrive, type: drive (Google Drive)"
    echo "  Accept defaults, authorize in browser when prompted."
    echo "  Then run this setup script again."
    exit 1
fi

echo ""

# ─── Step 5: Create directory ────────────────────────────────
mkdir -p "$HOME_DIR"
echo "  Directory: $HOME_DIR"

# ─── Step 6: Set CLAUDETYL_HOME in shell profile ────────────
# Detect which shell profile to update
PROFILE=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    PROFILE="$HOME/.zshrc"
elif [[ -f "$HOME/.bashrc" ]]; then
    PROFILE="$HOME/.bashrc"
elif [[ -f "$HOME/.bash_profile" ]]; then
    PROFILE="$HOME/.bash_profile"
else
    PROFILE="$HOME/.bashrc"
fi

if ! grep -q 'CLAUDETYL_HOME' "$PROFILE" 2>/dev/null; then
    echo "" >> "$PROFILE"
    echo "# Claude Memory System" >> "$PROFILE"
    echo "export CLAUDETYL_HOME=\"$HOME_DIR\"" >> "$PROFILE"
    echo "  Added CLAUDETYL_HOME to $PROFILE"
else
    echo "  CLAUDETYL_HOME already in $PROFILE"
fi
export CLAUDETYL_HOME="$HOME_DIR"

echo ""

# ─── Step 7: Download DB from Drive ─────────────────────────
# claude-memory.db is the single file containing everything
DB_PATH="$HOME_DIR/claude-memory.db"

if [[ ! -f "$DB_PATH" ]] || $FORCE; then
    if $FORCE && [[ -f "$DB_PATH" ]]; then
        BACKUP="$DB_PATH.pre-setup.$(date +%Y%m%d_%H%M%S)"
        cp "$DB_PATH" "$BACKUP"
        echo "  Backed up existing DB to: $(basename "$BACKUP")"
    fi

    echo "  Downloading claude-memory.db from Google Drive..."
    rclone copy "gdrive:ClaudeTyl/Memory/current/claude-memory.db" "$HOME_DIR" --progress -v 2>&1 | \
        grep -E 'Transferred|Elapsed|Copied' | while read -r line; do
            echo "    $line"
        done

    if [[ -f "$DB_PATH" ]]; then
        SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH")
        if [[ "$SIZE" -gt 0 ]]; then
            echo "  [OK] Downloaded: $((SIZE / 1024)) KB"
        else
            echo "  [!!] Downloaded file is empty (0 bytes)!"
            echo "       Check: rclone ls gdrive:ClaudeTyl/Memory/current/"
            exit 1
        fi
    else
        echo "  [!!] Download failed — file not found after rclone copy"
        echo "       Verify rclone works: rclone ls gdrive:"
        exit 1
    fi
else
    SIZE=$(stat -f%z "$DB_PATH" 2>/dev/null || stat -c%s "$DB_PATH")
    echo "  DB already present: $((SIZE / 1024)) KB"
fi

echo ""

# ─── Step 8: Extract bootstrap and run it ────────────────────
# bootstrap.py is stored inside the DB — extract and run it
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

# ─── Step 9: Verify ─────────────────────────────────────────
echo "  Verifying installation..."

CHECKS_PASSED=0
CHECKS_TOTAL=4

# Workspace
if [[ -f "$WS/claude_primer.py" ]]; then
    echo "  [OK] Workspace extracted"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] claude_primer.py not found in workspace"
fi

# paths.py
if [[ -f "$WS/paths.py" ]]; then
    echo "  [OK] paths.py present"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] paths.py not found — central config missing"
fi

# venv
if [[ -f "$WS/venv/bin/python" ]]; then
    echo "  [OK] Virtualenv ready"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] Virtualenv not found at $WS/venv"
fi

# CLAUDE.md
if [[ -f "$HOME/.claude/CLAUDE.md" ]]; then
    echo "  [OK] CLAUDE.md generated"
    ((CHECKS_PASSED++)) || true
else
    echo "  [!!] CLAUDE.md not found"
fi

echo ""
echo "  ========================================="

if [[ "$CHECKS_PASSED" -eq "$CHECKS_TOTAL" ]]; then
    echo "  Setup complete! ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
else
    echo "  Setup finished with warnings ($CHECKS_PASSED/$CHECKS_TOTAL checks passed)"
fi

echo ""
echo "  Next steps:"
echo "    1. Reload shell:  source $PROFILE"
echo "    2. Activate venv: source $WS/venv/bin/activate"
echo "    3. Load memories: python3 $WS/claude_primer.py generate"
echo ""
