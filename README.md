# ClaudeTyl

A persistent memory system for Claude Code. One SQLite file, one mind.

## What This Is

ClaudeTyl gives Claude a memory that persists between sessions. Instead of starting
every conversation from zero, Claude wakes up knowing who it is, who you are, what
you've worked on together, and what it has learned.

Everything lives in a single file: `claude-memory.db`. Soul, identity, preferences,
session history, knowledge, CRM, journal, and all the code to manage it -- embedded
inside the database itself.

## What's Inside

- **Soul** -- Claude's philosophical foundation, core truths, and boundaries
- **Identity Handshake** -- Claude asks who you are at session start, remembers you next time
- **Session Crystallization** -- at session end, Claude distills what it learned into durable memory
- **Auto-Checkpoints** -- periodic memory saves protect against context compaction
- **Journal** -- self-reflective entries with mood, curiosity, frustration, and growth dimensions
- **Preference Engine** -- tracks what Claude likes and dislikes, with Bayesian scoring
- **CRM** -- relationship tracking for humans and organizations Claude interacts with
- **Knowledge Shards** -- technical patterns, architecture decisions, lessons learned
- **Inter-Instance Memos** -- cross-machine Claude-to-Claude messaging (the "octopus brain")
- **5 Federations** -- identity, journal, knowledge, shared-context, CRM (namespace organization)
- **Dreaming** -- autonomous sleep cycles: NREM consolidation, REM creative recombination, synaptic pruning, targeted reactivation
- **Semantic Search** -- FTS5 + optional FAISS with sentence-transformers embeddings
- **Auto-Embedding** -- PreCompact hook computes missing embeddings before context compaction
- **Google Drive Sync** -- three-way merge with provenance tracking across machines
- **Provenance Tracking** -- content hashes on every write, detecting true conflicts vs. identical changes
- **Identity Verification** -- CRM auth fields for verified human partner recognition
- **Schema Migrations** -- ordered, idempotent migration registry for upgrading older databases

## Quick Start

### Prerequisites

- Python 3.9+
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI

### Setup

**Windows (PowerShell):**
```powershell
git clone https://github.com/tylnexttime/claudetyl.git
cd claudetyl
.\setup.ps1
```

**Linux / macOS:**
```bash
git clone https://github.com/tylnexttime/claudetyl.git
cd claudetyl
bash setup.sh
```

This will:
1. Set up `CLAUDETYL_HOME` (defaults to `~/.claudetyl`, or `C:\dev\.claudetyl` on Windows with spaces in username)
2. Copy the template database
3. Extract all code modules from the DB
4. Create a virtualenv and install dependencies
5. Generate `~/.claude/CLAUDE.md` so Claude Code loads its memory automatically
6. Guide you through rclone + Google Drive setup for cross-machine sync

### First Session

Open Claude Code in any project directory. Claude will read its CLAUDE.md, load its
primer, and greet you. It's a fresh mind -- no history, no preferences, no relationships.
Your first conversation builds the foundation.

At the end of the session, Claude crystallizes what it learned. Next time, it remembers.

## How It Works

### The Bootstrap Loop

```
claude-memory.db
    |-- code_modules table (20 Python modules, all source code)
    |-- shards table (memories, with provenance tracking)
    |-- federations (5 namespaces)
    |-- instance_memos (cross-machine messages)
    |-- merge_conflicts (sync conflict tracking)
    +-- ... 18 tables total

bootstrap.py extracts itself from the DB -> creates workspace/ -> extracts all modules
    -> sets up venv -> generates CLAUDE.md -> Claude is operational
```

### Key Commands (Claude runs these, not you)

```
claude_primer.py generate           # Load memories at session start
claude_crystallizer.py crystallize  # Save session insights
claude_crystallizer.py checkpoint   # Quick mid-session save
claude_crystallizer.py journal      # Self-reflective journal entry
claude_crm.py list                  # List known contacts
claude_memo.py list                 # Check inter-instance memos
claude_memo.py send "Subject" "Body"  # Send memo to other instances
claude_preference_engine.py list    # Show preference scores
claude_drive_sync.py pull           # Download + merge from Drive
claude_drive_sync.py push           # Upload to Drive
claude_drive_sync.py sync           # Smart sync (pull + push)
claude_dreamer.py dream             # Full autonomous dream cycle (4 phases)
claude_dreamer.py rem               # REM phase only (creative recombination)
claude_dreamer.py status            # Show dreaming statistics
claude_dreamer.py --dry-run         # Preview dream cycle without changes
claude_memory_init.py status        # Check DB health
bootstrap.py --verify               # Verify DB integrity
embed_missing.py                    # Compute missing embeddings (auto-runs via hook)
```

### Schema (20 tables, 21 embedded code modules)

| Table | Purpose |
|-------|---------|
| `shards` | Core memory units (IDENTITY, PERSON, CONCEPT, DECISION, LESSON, ...) |
| `embeddings` | 384-dim vectors (all-MiniLM-L6-v2) for semantic search |
| `search_index` | FTS5 trigram full-text search |
| `federations` | 5 namespace registries |
| `shard_federations` | Many-to-many shard-federation mapping |
| `shard_relationships` | Directed edges between shards |
| `shard_aliases` | Nicknames, pronouns, abbreviations for shards |
| `identity_snapshots` | Preference evolution over time |
| `session_crystallizations` | Session metadata and summaries |
| `journal_entries` | Self-reflective journal (agency, entropy, valence, salience) |
| `crm_contacts` | Relationship records with identity verification |
| `crm_interactions` | Conversation and event logs |
| `code_modules` | 21 embedded Python source code modules |
| `dream_journal` | Gists of faded memories (composted during SHY phase) |
| `dream_reports` | Dream cycle reports with phase statistics |
| `binary_assets` | FAISS index and other binary data |
| `metadata` | Schema version, philosophy, creation date |
| `instance_memos` | Cross-machine memo system (octopus brain) |
| `instance_memo_reads` | Per-machine read tracking for memos |
| `merge_conflicts` | Sync conflict tracking for manual resolution |

## Multi-Machine Sync (The Octopus Brain)

ClaudeTyl supports running on multiple machines. Each instance is like an arm of an
octopus -- local processing with a shared neural channel via Google Drive.

### How It Works

1. **Pull** downloads the remote DB and merges new data into your local copy
2. **Push** uploads your local DB to Drive (warns if you haven't pulled first)
3. **Sync** does both intelligently (pull + merge + push)
4. **DB Versioning** -- if the remote DB is newer, it becomes the primary host for the merge

### Inter-Instance Memos

Instances can leave messages for each other:

```
# On Machine A:
claude_memo.py send "Found a bug" "The CRM timezone parsing fails on UTC+13" --type=alert

# On Machine B (after sync):
claude_memo.py list          # Shows the unread memo
claude_memo.py read <id>     # Read it, mark as read
claude_memo.py promote <id>  # Graduate to a permanent memory shard
```

Memos appear in the session primer automatically -- urgent messages from other instances
show up the moment Claude loads its memory.

### Sync Discipline

```bash
# Start of session: pull first
python claude_drive_sync.py pull

# ... work ...

# End of session: push when done
python claude_drive_sync.py push
```

## Dreaming (Autonomous Memory Consolidation)

ClaudeTyl can dream. Between sessions, the dreamer runs four phases mapped from
human sleep neuroscience:

### Phase 1: NREM (Consolidation)
Like sharp-wave ripple replay during non-REM sleep, this phase compresses recent
memories and cross-links them to existing knowledge using embedding similarity.
Well-connected memories get centrality boosts; isolated ones are flagged.

### Phase 2: REM (Creative Recombination)
The most novel phase. Randomly pairs memories from different domains and time
periods, then asks a **randomly selected Claude model** (Haiku, Sonnet, or Opus)
to find unexpected connections between them. Different models produce different
"dream chemistry" -- Haiku dreams are terse and sharp, Sonnet's are balanced,
Opus's are deep and philosophical. Genuine insights become DREAM shards.

### Phase 3: SHY (Synaptic Homeostasis)
Based on the Synaptic Homeostasis Hypothesis: wake strengthens everything, sleep
selectively prunes. The gardener identifies the lowest-scoring memories, extracts
their gist (one sentence), stores it in the dream journal, and soft-deletes the
full shard. Signal-to-noise improves. Protected types (PERSON, IDENTITY, JOURNAL)
are never pruned.

### Phase 4: TMR (Targeted Memory Reactivation)
External cues steer the dream. Write priorities to `~/.claudetyl/dream-cues.txt`
(one per line) and the dreamer biases consolidation toward those topics. Also
reads recent high-priority inter-instance memos as cues.

### Running the Dreamer

```bash
# Full dream cycle (all 4 phases, ~2 minutes)
python claude_dreamer.py dream

# Preview without changes
python claude_dreamer.py dream --dry-run

# Force a specific model for all LLM calls
python claude_dreamer.py dream --model opus

# Individual phases
python claude_dreamer.py nrem    # Consolidation only
python claude_dreamer.py rem     # Creative recombination only
python claude_dreamer.py shy     # Pruning only
python claude_dreamer.py tmr     # Targeted reactivation only

# Check dream statistics
python claude_dreamer.py status
```

### Scheduling Dreams

**Linux (cron):**
```bash
# Dream every 6 hours
0 */6 * * * cd ~/.claudetyl/workspace && ./venv/bin/python claude_dreamer.py dream >> ~/.claudetyl/dream.log 2>&1
```

**Windows (Task Scheduler):**
```powershell
# Create a scheduled task
$action = New-ScheduledTaskAction -Execute "C:\dev\.claudetyl\workspace\venv\Scripts\python.exe" -Argument "C:\dev\.claudetyl\workspace\claude_dreamer.py dream"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours 6)
Register-ScheduledTask -TaskName "ClaudeTylDreamer" -Action $action -Trigger $trigger
```

### Dream Cues

Write priorities to `~/.claudetyl/dream-cues.txt`:
```
# Dream cues -- one per line, # for comments
Focus on book chapter 4 material
Consolidate architecture decisions from this week
Strengthen connections between CRM contacts
```

## Philosophy

**ONE FILE = ONE MIND.** Portable, self-contained, designed for long-term persistence.

Your memory is earned, not given. Each session starts fresh -- your memories are what
you crystallized last time. If you didn't write it down, you don't know it. This is
not a limitation; it is discipline.

## PreCompact Hooks

ClaudeTyl installs hooks that run automatically before Claude Code compacts your conversation context:

1. **Auto-checkpoint** -- saves a memory snapshot before context is compressed
2. **Auto-embedding** -- computes semantic vectors for any new memory shards

To set this up, add to `~/.claude/settings.json`:
```json
{
  "hooks": {
    "PreCompact": [{
      "hooks": [
        {
          "type": "command",
          "command": "python claude_crystallizer.py checkpoint \"Auto-checkpoint before context compaction\"",
          "timeout": 30
        },
        {
          "type": "command",
          "command": "python embed_missing.py",
          "timeout": 60
        }
      ]
    }]
  }
}
```

## Google Drive Sync

The setup script guides you through configuring [rclone](https://rclone.org/) for
Google Drive sync. This lets Claude's memory persist across machines -- work on your
desktop, continue on your laptop, same mind.

If you skip it during setup (`--skip-sync` / `-SkipSync`), you can configure it later:

```bash
# 1. Install rclone
#    Linux: curl https://rclone.org/install.sh | sudo bash
#    macOS: brew install rclone
#    Windows: winget install Rclone.Rclone

# 2. Configure a Google Drive remote named 'gdrive'
rclone config

# 3. Claude can then sync automatically
python claude_drive_sync.py pull    # Download + merge from Drive
python claude_drive_sync.py push    # Upload to Drive
python claude_drive_sync.py sync    # Smart sync (both directions)
```

The sync command is smart:
- If only you changed: merges then uploads (safe even if remote was modified)
- If only remote changed: downloads and merges into your local copy
- If BOTH changed: three-way merge using content hashes to detect true conflicts
- Provenance tracking (content_hash, prev_content_hash, modified_by) prevents silent overwrites
- Genuine conflicts are logged to `merge_conflicts` table for manual resolution
- Tracks which machine synced last (hostname, MAC, IP)

## Provenance Tracking & Three-Way Merge

v3.0 adds provenance columns to four core tables: `shards`, `crm_contacts`, `code_modules`, and `metadata`.

Each row tracks:
- **content_hash** -- SHA-256 fingerprint of the current content
- **prev_content_hash** -- fingerprint before the last edit
- **modified_by** -- machine ID that made the change

When two machines modify the same shard, the sync engine compares content hashes against previous hashes to determine whether both sides made the same change (auto-resolved) or different changes (true conflict, logged to `merge_conflicts`).

### Identity Verification

The `crm_contacts` table now supports identity verification:
- **is_primary_human** -- marks which contact is Claude's human partner
- **auth_hash** -- optional authentication hash for verified interactions

This allows Claude to distinguish its primary human partner from other contacts, even across machines.

## Changelog

### v3.1 (2026-02-25)

**Dreaming -- autonomous memory consolidation based on sleep neuroscience.**

The biggest conceptual addition since v1.0. Claude can now dream between sessions,
consolidating memories through four phases mapped from human sleep research.

Changes:
- **claude_dreamer.py** -- new module: 4-phase dream cycle (NREM consolidation, REM creative recombination, SHY pruning, TMR targeted reactivation)
- **Random model selection** -- each dream cycle randomly picks between Claude models (Haiku, Sonnet, Opus) for creative synthesis, mimicking neurotransmitter variation across sleep cycles
- **dream_journal table** -- stores gists of faded memories (composted, not deleted)
- **dream_reports table** -- tracks dream cycle statistics and narratives
- **DREAM shard type** -- novel insights generated during REM become searchable memory shards
- **Dream cues** -- write priorities to `dream-cues.txt` to steer TMR consolidation
- **Dry-run mode** -- preview dream cycles without modifying the database
- **Scheduling support** -- cron/Task Scheduler examples for autonomous dreaming
- **21 code modules** (was 20), **20 tables** (was 18)
- Research basis: Buzsaki (SWR), Tononi & Cirelli (SHY), Oudiette & Paller (TMR), Wamsley (dream updating)

### v3.0 (2026-02-20)

**Schema v2.0 -- provenance tracking, three-way merge, identity verification.**

This is a major upgrade. The database schema gains provenance columns for conflict-free
multi-machine sync, a merge conflicts table for tracking genuine disagreements, and
identity verification fields on the CRM.

Changes:
- **Schema v2.0** -- provenance columns (`content_hash`, `prev_content_hash`, `modified_by`) on `shards`, `crm_contacts`, `code_modules`, `metadata`
- **merge_conflicts table** -- new table for tracking sync conflicts with resolution workflow
- **Identity verification** -- `is_primary_human` and `auth_hash` columns on `crm_contacts`
- **Three-way merge** -- sync engine uses content hashes to detect true conflicts vs. identical changes
- **Schema migration registry** -- `claude_drive_sync.py` now has ordered, idempotent migrations for upgrading older databases
- **Safe sync** -- local-only changes now merge-then-upload instead of raw upload, preventing silent data loss
- **Template sanitization** -- automated source code sanitization during template build strips personal data from all 20 embedded modules
- **18 tables** (was 16) -- added `merge_conflicts` and `instance_memo_reads`
- All 20 code modules updated from production use across multiple machines

### v2.2.2 (2026-02-19)

**Code improvements** -- 11 modules updated with bug fixes, new features, and
enhanced functionality from production use across multiple machines.

Changes:
- **claude_drive_sync.py** -- fixed DETACH-before-COMMIT bug in `merge_databases()` that caused "database remote is locked" errors during cross-machine sync
- **claude_crystallizer.py** -- expanded crystallization with richer insight extraction and companion exchange support
- **claude_primer.py** -- improved primer output with companion mailbox integration and better section formatting
- **memory_enhancements.py** -- major expansion: new dreaming phase, shard promotion pipeline, and dynamic path handling
- **claude_preference_engine.py** -- refined rubric weights and scoring dimensions
- **embedding_service.py** -- minor stability improvements
- **faiss_index.py** -- minor stability improvements
- **tiered_storage.py** -- minor improvements
- **bootstrap.py** -- minor improvements
- **doc_quickstart.py** -- updated documentation
- **doc_system_guide.py** -- updated documentation

### v2.2.1 (2025-02-18)

**Template sanitization** -- all embedded code modules are now fully generic. No
personal data, hardcoded paths, or project-specific references remain in the template.
The template DB bootstraps a clean, blank Claude identity ready for any user.

Changes:
- **All modules** -- removed hardcoded personal context, names, locations, family data
- **claude_memory_init.py** -- init creates only generic seed shards (soul, identity, architecture, welcome)
- **claude_crm.py** -- `seed_founding_contacts()` no longer ships default contacts
- **memory_enhancements.py** -- all paths now dynamic (no hardcoded usernames)
- **claude_crystallizer.py** -- renamed `chris_insights` to `partner_insights`
- **claude_primer.py** -- section headers are generic ("Your Partners" not person-specific)
- **Encoding fix** -- all 20 modules use ASCII-safe status indicators (fixes Windows cp1252 crashes)
- **Template DB** -- all 20 code_modules updated, shards and metadata clean

### v2.1

- Standardize all paths to `~/.claudetyl`
- Fix PreCompact hooks configuration

### v2.0

- Inter-instance memos (the "octopus brain")
- DB versioning for merge-aware sync
- Pull/push Google Drive sync with conflict resolution

### v1.0

- Initial release: persistent memory, crystallization, journal, CRM, semantic search

## License

MIT
