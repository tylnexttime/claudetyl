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
- **Semantic Search** -- FTS5 + optional FAISS with sentence-transformers embeddings
- **Auto-Embedding** -- PreCompact hook computes missing embeddings before context compaction
- **Google Drive Sync** -- smart merge-aware sync with pull/push/DB versioning across machines

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
    |-- shards table (memories)
    |-- federations (5 namespaces)
    |-- instance_memos (cross-machine messages)
    +-- ... 16 tables total

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
claude_memory_init.py status        # Check DB health
bootstrap.py --verify               # Verify DB integrity
embed_missing.py                    # Compute missing embeddings (auto-runs via hook)
```

### Schema (16 tables, 20 embedded code modules)

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
| `crm_contacts` | Relationship records (humans, organizations, projects) |
| `crm_interactions` | Conversation and event logs |
| `code_modules` | 20 embedded Python source code modules |
| `binary_assets` | FAISS index and other binary data |
| `metadata` | Schema version, philosophy, creation date |
| `instance_memos` | Cross-machine memo system (octopus brain) |
| `instance_memo_reads` | Per-machine read tracking for memos |

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
- If only you changed: uploads your DB
- If only remote changed: downloads the remote DB
- If BOTH changed: downloads, merges at shard level, uploads merged
- Newer DB on Drive becomes the primary host during merge (DB versioning)
- Tracks which machine synced last (hostname, MAC, IP)

## Changelog

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
