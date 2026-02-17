#Requires -Version 5.1
<#
.SYNOPSIS
    ClaudeTyl — Setup Script (Windows).

.DESCRIPTION
    Sets up Claude's persistent memory system:
    1. Check Python 3.9+
    2. Set CLAUDETYL_HOME environment variable
    3. Copy template DB to get started immediately
    4. Extract and run bootstrap (workspace, venv, CLAUDE.md)
    5. Install rclone and configure Google Drive sync
    6. Verify everything works

    Safe to run multiple times (idempotent).

.PARAMETER ClaudeTylHome
    Override the base directory. Defaults to C:\dev\.claudetyl if username
    has spaces, otherwise $env:USERPROFILE\.claudetyl.

.PARAMETER SkipSync
    Skip rclone/Drive setup (can be configured later).

.EXAMPLE
    .\setup-local.ps1
    .\setup-local.ps1 -ClaudeTylHome "D:\my-claude"
    .\setup-local.ps1 -SkipSync
#>

param(
    [string]$ClaudeTylHome = $null,
    [switch]$SkipSync
)

$ErrorActionPreference = 'Stop'

$script_dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$template_db = Join-Path $script_dir 'claude-memory-template.db'

Write-Host ""
Write-Host "  ClaudeTyl - Memory System Setup" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

# ─── Verify template DB exists ────────────────────────────────
if (-not (Test-Path $template_db)) {
    Write-Host "  [!!] claude-memory-template.db not found in repo" -ForegroundColor Red
    Write-Host "       Make sure you're running this from the cloned repo directory." -ForegroundColor Yellow
    exit 1
}

# ─── Step 1: Determine CLAUDETYL_HOME ────────────────────────
if ($ClaudeTylHome) {
    $home_dir = $ClaudeTylHome
} elseif ($env:CLAUDETYL_HOME) {
    $home_dir = $env:CLAUDETYL_HOME
} elseif ($env:USERPROFILE -match ' ') {
    $home_dir = 'C:\dev\.claudetyl'
    Write-Host "  [i] Username has spaces, using $home_dir" -ForegroundColor Yellow
} else {
    $home_dir = Join-Path $env:USERPROFILE '.claudetyl'
}

Write-Host "  CLAUDETYL_HOME: $home_dir"
Write-Host ""

# ─── Step 2: Check Python ────────────────────────────────────
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
    exit 1
}

Write-Host ""

# ─── Step 3: Create directory ─────────────────────────────────
if (-not (Test-Path $home_dir)) {
    $parent = Split-Path $home_dir -Parent
    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    New-Item -ItemType Directory -Path $home_dir -Force | Out-Null
    Write-Host "  Created: $home_dir" -ForegroundColor Green
} else {
    Write-Host "  Directory exists: $home_dir" -ForegroundColor Gray
}

# ─── Step 4: Set CLAUDETYL_HOME env var ───────────────────────
$current = [Environment]::GetEnvironmentVariable('CLAUDETYL_HOME', 'User')
if ($current -ne $home_dir) {
    [Environment]::SetEnvironmentVariable('CLAUDETYL_HOME', $home_dir, 'User')
    $env:CLAUDETYL_HOME = $home_dir
    Write-Host "  Set CLAUDETYL_HOME = $home_dir (User scope)" -ForegroundColor Green
} else {
    Write-Host "  CLAUDETYL_HOME already set correctly" -ForegroundColor Gray
}

Write-Host ""

# ─── Step 5: Copy template DB ────────────────────────────────
$db_path = Join-Path $home_dir 'claude-memory.db'

if (-not (Test-Path $db_path)) {
    Copy-Item $template_db $db_path
    $size = (Get-Item $db_path).Length
    Write-Host "  [OK] Template DB copied: $([math]::Round($size/1024, 1)) KB" -ForegroundColor Green
} else {
    $size = (Get-Item $db_path).Length
    Write-Host "  [i] DB already exists: $([math]::Round($size/1024, 1)) KB (keeping existing)" -ForegroundColor Yellow
}

Write-Host ""

# ─── Step 6: Extract bootstrap and run it ─────────────────────
Write-Host "  Extracting and running bootstrap..." -ForegroundColor Cyan

$ws = Join-Path $home_dir 'workspace'
$bootstrap_temp = Join-Path $home_dir '_bootstrap_temp.py'

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

& python $bootstrap_temp --target="$ws"
Remove-Item $bootstrap_temp -ErrorAction SilentlyContinue

Write-Host ""

# ─── Step 7: Set up rclone + Google Drive sync ───────────────
if (-not $SkipSync) {
    Write-Host "  Setting up Google Drive sync..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Claude's memory can sync to Google Drive so it persists across machines." -ForegroundColor Gray
    Write-Host "  This requires rclone (a free, open-source cloud sync tool)." -ForegroundColor Gray
    Write-Host ""

    $has_rclone = $false
    try {
        $rclone_ver = & rclone version 2>&1 | Select-Object -First 1
        Write-Host "  [OK] $rclone_ver" -ForegroundColor Green
        $has_rclone = $true
    } catch {
        Write-Host "  [--] rclone not installed" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To install rclone:" -ForegroundColor White
        Write-Host "    winget install Rclone.Rclone" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  After installing, reopen this terminal and run setup again," -ForegroundColor Gray
        Write-Host "  or configure manually later:" -ForegroundColor Gray
        Write-Host "    rclone config    (create a remote named 'gdrive', type: Google Drive)" -ForegroundColor Gray
        Write-Host ""
    }

    if ($has_rclone) {
        $remotes = & rclone listremotes 2>&1
        if ($remotes -match 'gdrive:') {
            Write-Host "  [OK] rclone remote 'gdrive' configured" -ForegroundColor Green
            Write-Host ""
            Write-Host "  Drive sync is ready. Claude can use these commands:" -ForegroundColor Gray
            Write-Host "    python claude_drive_sync.py push   # Upload DB to Drive" -ForegroundColor Gray
            Write-Host "    python claude_drive_sync.py pull   # Download DB from Drive" -ForegroundColor Gray
        } else {
            Write-Host "  [--] rclone installed but 'gdrive' remote not configured" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "  To set up Google Drive sync:" -ForegroundColor White
            Write-Host "    1. Run: rclone config" -ForegroundColor Gray
            Write-Host "    2. Choose: n (new remote)" -ForegroundColor Gray
            Write-Host "    3. Name:  gdrive" -ForegroundColor Gray
            Write-Host "    4. Type:  drive (Google Drive)" -ForegroundColor Gray
            Write-Host "    5. Accept defaults, authorize in browser when prompted" -ForegroundColor Gray
            Write-Host ""
            Write-Host "  After configuring, Claude can sync automatically." -ForegroundColor Gray
        }
    }

    Write-Host ""
} else {
    Write-Host "  Skipped Drive sync setup (--SkipSync)" -ForegroundColor Gray
    Write-Host ""
}

# ─── Step 8: Verify ──────────────────────────────────────────
Write-Host "  Verifying installation..." -ForegroundColor Cyan

$checks_passed = 0
$checks_total = 3

$primer = Join-Path $ws 'claude_primer.py'
if (Test-Path $primer) {
    Write-Host "  [OK] Workspace extracted" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] claude_primer.py not found in workspace" -ForegroundColor Red
}

$paths_py = Join-Path $ws 'paths.py'
if (Test-Path $paths_py) {
    Write-Host "  [OK] paths.py present" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] paths.py not found" -ForegroundColor Red
}

$claude_md = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
if (Test-Path $claude_md) {
    Write-Host "  [OK] CLAUDE.md generated" -ForegroundColor Green
    $checks_passed++
} else {
    Write-Host "  [!!] CLAUDE.md not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  ================================" -ForegroundColor Cyan

if ($checks_passed -eq $checks_total) {
    Write-Host "  Setup complete! ($checks_passed/$checks_total checks passed)" -ForegroundColor Green
} else {
    Write-Host "  Setup finished with warnings ($checks_passed/$checks_total checks passed)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Next steps:" -ForegroundColor White
Write-Host "    1. Open a NEW terminal (to pick up CLAUDETYL_HOME)" -ForegroundColor Gray
Write-Host "    2. Open Claude Code in any project directory" -ForegroundColor Gray
Write-Host "    3. Claude will load its memories automatically via CLAUDE.md" -ForegroundColor Gray
Write-Host ""
