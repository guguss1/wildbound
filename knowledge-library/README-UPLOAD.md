# Knowledge library (upload snapshot)

This folder is a snapshot of `roblox-codex-starter`, the shared knowledge base used while designing Wildbound.

## What it contains

- `knowledge/`: curated notes. `INDEX.md` is the entry point, `DECISIONS.md` records decisions, `youtube/<video-id>/` holds a transcript, notes and a manifest per ingested video, and `sources/` holds notes on external sources.
- `.agents/skills/youtube-to-knowledge/`: the skill and `scripts/ingest_youtube.py` script that turn a YouTube video into a transcript, frames and notes.
- `.agents/skills/roblox-implementation/` and `tooling/skills/roblox-project-start/`: helper skills for Roblox work.
- `.codex/agents/`: agent definitions for video research and Roblox engineering.
- `odd/tasks/`: task records for the work that built this library.
- `requirements.txt`: Python dependencies for the ingest script.

## Not included

- Downloaded video files and extracted frames (`knowledge/youtube/*/media/`, `knowledge/youtube/*/frames/`), excluded by the library's own `.gitignore`.
- The local virtualenv (`.venv-youtube/`), temporary download folder (`.youtube-tmp/`) and the local skill registry cache (`.atl/`).

## Usage notes

Video advice is a hypothesis to test, not an official requirement. Recreate the environment with `pip install -r requirements.txt` before running the ingest script.
