#Requires -Version 5.1
<#
.SYNOPSIS
    Bootstrap Claude's memory system on Windows.

.DESCRIPTION
    Checks prerequisites (Python, rclone, gdrive remote), sets CLAUDETYL_HOME
    environment variable, downloads claude-memory.db from Google Drive if needed,
    extracts workspace code from the DB, creates a virtualenv, and verifies.

    Safe to run multiple times (idempotent).

.PARAMETER ClaudeTylHome
    Override the base directory. Defaults to C:\dev\.claudetyl if username has
    spaces, otherwise $env:USERPROFILE\.claudetyl.

.PARAMETER Force
    Re-download DB even if it already exists locally.

.PARAMETER SkipVenv
    Skip virtualenv creation (useful for re-runs).

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -ClaudeTylHome "D:\my-claude"
    .\setup.ps1 -Force
#>

param(
    [string]$ClaudeTylHome = $null,
    [switch]$Force,
    [switch]$SkipVenv
)

$ErrorActionPreference = 'Stop'

Write-Host ""
Write-Host "  Claude Memory System - Windows Setup" -ForegroundColor Cyan
Write-Host "  =====================================" -ForegroundColor Cyan
Write-Host ""

# ─── Step 1: Determine CLAUDETYL_HOME ───────────────────────
# Priority: parameter > env var > auto-detect
if ($ClaudeTylHome) {
    $home_dir = $ClaudeTylHome
} elseif ($env:CLAUDETYL_HOME) {
    $home_dir = $env:CLAUDETYL_HOME
} elseif ($env:USERPROFILE -match ' ') {
    # Username has spaces (e.g. "Krystof Tyl") — rclone fails silently
    # with spaces in paths, so we use C:\dev\.claudetyl instead
    $home_dir = 'C:\dev\.claudetyl'
    Write-Host "  [i] Username has spaces, using $home_dir" -ForegroundColor Yellow
} else {
    $home_dir = Join-Path $env:USERPROFILE '.claudetyl'
}

Write-Host "  CLAUDETYL_HOME: $home_dir"
Write-Host ""

# ─── Step 2: Check Python ───────────────────────────────────
# We need Python 3.9+ for the memory system
Write-Host "  Checking prerequisites..." -ForegroundColor Gray
try {
    $pyver = & python --version 2>&1
    if ($pyver -match 'Python (\d+\.\d+)') {
        $ver = [version]$Matches[1]
        if ($ver -ge [version]"3.9") {
            Write-Host "  [OK] $pyver" -ForegroundColor Green
        } else {
            Write-Host "  [!!] Python 3.9+ required, found $pyver" -ForegroundColor Red
            Write-Host "       Install: winget install Python.Python.3" -ForegroundColor Yellow
            exit 1
        }
    }
} catch {
    Write-Host "  [!!] Python not found" -ForegroundColor Red
    Write-Host "       Install: winget install Python.Python.3" -ForegroundColor Yellow
    Write-Host "       Then reopen this terminal and run setup again." -ForegroundColor Yellow
    exit 1
}

# ─── Step 3: Check rclone ───────────────────────────────────
# rclone handles Google Drive sync
try {
    $rclone_ver = & rclone version 2>&1 | Select-Object -First 1
    Write-Host "  [OK] $rclone_ver" -ForegroundColor Green
} catch {
    Write-Host "  [!!] rclone not found" -ForegroundColor Red
    Write-Host "       Install: winget install Rclone.Rclone" -ForegroundColor Yellow
    Write-Host "       Then reopen this terminal and run setup again." -ForegroundColor Yellow
    exit 1
}

# ─── Step 4: Check rclone gdrive remote ─────────────────────
# The 'gdrive' remote must be configured to point at your Google Drive
$remotes = & rclone listremotes 2>&1
if ($remotes -match 'gdrive:') {
    Write-Host "  [OK] rclone remote 'gdrive' configured" -ForegroundColor Green
} else {
    Write-Host "  [!!] rclone remote 'gdrive' not configured" -ForegroundColor Red
    Write-Host ""
    Write-Host "  You need to set up a Google Drive remote named 'gdrive'." -ForegroundColor Yellow
    Write-Host "  Run this in your terminal:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    rclone config" -ForegroundColor White
    Write-Host ""
    Write-Host "  Choose: n (new), name: gdrive, type: drive (Google Drive)" -ForegroundColor Gray
    Write-Host "  Accept defaults, authorize in browser when prompted." -ForegroundColor Gray
    Write-Host "  Then run this setup script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# ─── Step 5: Create directory ────────────────────────────────
if (-not (Test-Path $home_dir)) {
    # Ensure parent exists (e.g. C:\dev)
    $parent = Split-Path $home_dir -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $home_dir -Force | Out-Null
    Write-Host "  Created: $home_dir" -ForegroundColor Green
} else {
    Write-Host "  Directory exists: $home_dir" -ForegroundColor Gray
}

# ─── Step 6: Set CLAUDETYL_HOME env var (User scope) ────────
# This persists across terminal restarts
$current = [Environment]::GetEnvironmentVariable('CLAUDETYL_HOME', 'User')
if ($current -ne $home_dir) {
    [Environment]::SetEnvironmentVariable('CLAUDETYL_HOME', $home_dir, 'User')
    $env:CLAUDETYL_HOME = $home_dir
    Write-Host "  Set CLAUDETYL_HOME = $home_dir (User scope)" -ForegroundColor Green
    Write-Host "  (takes effect in new terminals)" -ForegroundColor Gray
} else {
    Write-Host "  CLAUDETYL_HOME already set correctly" -ForegroundColor Gray
}

Write-Host ""

# ─── Step 7: Download DB from Drive ─────────────────────────
# claude-memory.db is the single file containing everything
$db_path = Join-Path $home_dir 'claude-memory.db'

if ((-not (Test-Path $db_path)) -or $Force) {
    if ($Force -and (Test-Path $db_path)) {
        # Back up existing before overwriting
        $backup = "$db_path.pre-setup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $db_path $backup
        Write-Host "  Backed up existing DB to: $(Split-Path $backup -Leaf)" -ForegroundColor Gray
    }

    Write-Host "  Downloading claude-memory.db from Google Drive..." -ForegroundColor Cyan
    & rclone copy "gdrive:ClaudeTyl/Memory/current/claude-memory.db" $home_dir --progress -v 2>&1 | ForEach-Object {
        if ($_ -match 'Transferred|Elapsed|Copied') {
            Write-Host "    $_" -ForegroundColor Gray
        }
    }

    if (Test-Path $db_path) {
        $size = (Get-Item $db_path).Length
        if ($size -gt 0) {
            Write-Host "  [OK] Downloaded: $([math]::Round($size/1024, 1)) KB" -ForegroundColor Green
        } else {
            Write-Host "  [!!] Downloaded file is empty (0 bytes)!" -ForegroundColor Red
            Write-Host "       This usually means rclone found nothing at the remote path." -ForegroundColor Yellow
            Write-Host "       Check: rclone ls gdrive:ClaudeTyl/Memory/current/" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "  [!!] Download failed — file not found after rclone copy" -ForegroundColor Red
        Write-Host "       Verify rclone works: rclone ls gdrive:" -ForegroundColor Yellow
        exit 1
    }
} else {
    $size = (Get-Item $db_path).Length
    Write-Host "  DB already present: $([math]::Round($size/1024, 1)) KB" -ForegroundColor Gray
}

Write-Host ""

# ─── Step 8: Extract bootstrap and run it ────────────────────
# bootstrap.py is stored inside the DB — we extract and run it
Write-Host "  Extracting and running bootstrap..." -ForegroundColor Cyan

$ws = Join-Path $home_dir 'workspace'
$bootstrap_temp = Join-Path $home_dir '_bootstrap_temp.py'

# Extract bootstrap.py from the DB using Python's sqlite3 (avoids encoding issues)
& python -c @"
import sqlite3, sys
db = r'$($db_path -replace "'", "''")'
try:
    c = sqlite3.connect(db)
    r = c.execute("SELECT source_code FROM code_modules WHERE module_name='bootstrap'").fetchone()
    if not r:
        print('ERROR: bootstrap module not found in DB')
        sys.exit(1)
    with open(r'$($bootstrap_temp -replace "'", "''")','w', encoding='utf-8') as f:
        f.write(r[0])
    c.close()
    print('  Extracted bootstrap.py')
except Exception as e:
    print(f'ERROR: {e}')
    sys.exit(1)
"@

if (-not (Test-Path $bootstrap_temp)) {
    Write-Host "  [!!] Failed to extract bootstrap.py" -ForegroundColor Red
    exit 1
}

# Run bootstrap with target directory
& python $bootstrap_temp --target="$ws"

# Clean up temp file
Remove-Item $bootstrap_temp -ErrorAction SilentlyContinue

Write-Host ""

# ─── Step 9: Verify ─────────────────────────────────────────
Write-Host "  Verifying installation..." -ForegroundColor Cyan

$checks_passed = 0
$checks_total = 4

# Check workspace exists
$primer = Join-Path $ws 'claude_primer.py'
if (Test-Path $primer) {
    Write-Host "  [OK] Workspace extracted" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] claude_primer.py not found in workspace" -ForegroundColor Red
}

# Check paths.py exists
$paths_py = Join-Path $ws 'paths.py'
if (Test-Path $paths_py) {
    Write-Host "  [OK] paths.py present" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] paths.py not found — central config missing" -ForegroundColor Red
}

# Check venv exists
$venv_python = Join-Path $ws 'venv\Scripts\python.exe'
if (Test-Path $venv_python) {
    Write-Host "  [OK] Virtualenv ready" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] Virtualenv not found at $ws\venv" -ForegroundColor Yellow
    Write-Host "       Run: python -m venv $ws\venv" -ForegroundColor Gray
}

# Check CLAUDE.md exists
$claude_md = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (Test-Path $claude_md) {
    Write-Host "  [OK] CLAUDE.md generated" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] CLAUDE.md not found at $claude_md" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  =====================================" -ForegroundColor Cyan

if ($checks_passed -eq $checks_total) {
    Write-Host "  Setup complete! ($checks_passed/$checks_total checks passed)" -ForegroundColor Green
} else {
    Write-Host "  Setup finished with warnings ($checks_passed/$checks_total checks passed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open a NEW terminal (to pick up CLAUDETYL_HOME)" -ForegroundColor Gray
Write-Host "    2. Activate venv:  $ws\venv\Scripts\activate" -ForegroundColor Gray
Write-Host "    3. Load memories:  python $ws\claude_primer.py generate" -ForegroundColor Gray
Write-Host ""
