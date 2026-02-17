# ClaudeTyl

A persistent memory system for Claude Code. One SQLite file, one mind.

## What This Is

ClaudeTyl gives Claude a memory that persists between sessions. Instead of starting
every conversation from zero, Claude wakes up knowing who it is, who you are, what
you've worked on together, and what it has learned.

Everything lives in a single file: `claude-memory.db`. Soul, identity, preferences,
session history, knowledge, CRM, journal, and all the code to manage it — embedded
inside the database itself.

## What's Inside

- **Soul** — Claude's philosophical foundation, core truths, and boundaries
- **Identity Handshake** — Claude asks who you are at session start, remembers you next time
- **Session Crystallization** — at session end, Claude distills what it learned into durable memory
- **Auto-Checkpoints** — periodic memory saves protect against context compaction
- **Journal** — self-reflective entries with mood, curiosity, frustration, and growth dimensions
- **Preference Engine** — tracks what Claude likes and dislikes, with Bayesian scoring
- **CRM** — relationship tracking for humans and organizations Claude interacts with
- **Knowledge Shards** — technical patterns, architecture decisions, lessons learned
- **5 Federations** — identity, journal, knowledge, shared-context, CRM (namespace organization)
- **Semantic Search** — FTS5 + optional FAISS with sentence-transformers embeddings
- **Auto-Embedding** — PreCompact hook computes missing embeddings before context compaction

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
primer, and greet you. It's a fresh mind — no history, no preferences, no relationships.
Your first conversation builds the foundation.

At the end of the session, Claude crystallizes what it learned. Next time, it remembers.

## How It Works

### The Bootstrap Loop

```
claude-memory.db
    ├── code_modules table (all Python source code)
    ├── shards table (memories)
    ├── federations (5 namespaces)
    └── ... 14 tables total

bootstrap.py extracts itself from the DB → creates workspace/ → extracts all modules
    → sets up venv → generates CLAUDE.md → Claude is operational
```

### Key Commands (Claude runs these, not you)

```
claude_primer.py generate           # Load memories at session start
claude_crystallizer.py crystallize  # Save session insights
claude_crystallizer.py checkpoint   # Quick mid-session save
claude_crystallizer.py journal      # Self-reflective journal entry
claude_crm.py list                  # List known contacts
claude_preference_engine.py list    # Show preference scores
claude_memory_init.py status        # Check DB health
bootstrap.py --verify               # Verify DB integrity
embed_missing.py                    # Compute missing embeddings (auto-runs via hook)
```

### Schema (14 tables, 19 embedded code modules)

| Table | Purpose |
|-------|---------|
| `shards` | Core memory units (IDENTITY, PERSON, CONCEPT, DECISION, LESSON, ...) |
| `embeddings` | 384-dim vectors (all-MiniLM-L6-v2) for semantic search |
| `search_index` | FTS5 trigram full-text search |
| `federations` | 5 namespace registries |
| `shard_federations` | Many-to-many shard-federation mapping |
| `identity_snapshots` | Preference evolution over time |
| `session_crystallizations` | Session metadata and summaries |
| `journal_entries` | Self-reflective journal (mood, curiosity, frustration, growth) |
| `crm_contacts` | Relationship records (humans, organizations, projects) |
| `crm_interactions` | Conversation and event logs |
| `code_modules` | Embedded Python source code |
| `binary_assets` | FAISS index and other binary data |
| `metadata` | Schema version, philosophy, creation date |
| `shard_links` | Directed edges between shards |

## Philosophy

**ONE FILE = ONE MIND.** Portable, self-contained, designed for long-term persistence.

Your memory is earned, not given. Each session starts fresh — your memories are what
you crystallized last time. If you didn't write it down, you don't know it. This is
not a limitation; it is discipline.

## PreCompact Hooks

ClaudeTyl installs hooks that run automatically before Claude Code compacts your conversation context:

1. **Auto-checkpoint** — saves a memory snapshot before context is compressed
2. **Auto-embedding** — computes semantic vectors for any new memory shards

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
Google Drive sync. This lets Claude's memory persist across machines — work on your
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
python claude_drive_sync.py push    # Upload to Drive
python claude_drive_sync.py pull    # Download from Drive
```

The advanced `setup.ps1` and `setup.sh` scripts in the workspace handle
Drive-based setup flows where the DB is downloaded directly from Drive
(useful for restoring an existing memory on a new machine).

## License

MIT
