# AGENTS.md — Crossword Generator Engine (Python)

Offline Python application that generates mini crossword puzzles and writes
no-clue JSON files for the iOS app. The engine runs on a developer machine and
outputs static JSON files under the repo.

The engine is not shipped with the App Store binary.

---

## Goals

- Generate unique mini crosswords
- Grid sizes: **5×5 to 7×6**
- **0–4 black border cells** with strict corner-connectivity rules
- Fill valid across and down entries
- Embed **clues directly in puzzle JSON** as empty strings for now
- Deduplicate puzzles via hashing

---

## Output (No-Clue JSON)

- Output directory: `Puzzles/Puzzles_NO_CLUES/`
- File naming: `puzzle_000001.json`, `puzzle_000002.json`, ...
- `gridPreview` is a list of strings representing the filled grid, using `-` for black cells
- `clue` fields are **empty strings**
- `date` is an **empty string** (assigned later when bundling)
- Hashes stored in `Puzzles/Puzzles_NO_CLUES/_hashes.txt`

---

## Word Sources (Downloaded Locally)

Word sources are listed in `crossword-engine/wordlists/word_sources.json` and
fetched by `crossword-engine/scripts/download_wordlists.py`.

Default sources:

- **Core dictionary:**
  - `dwyl/english-words` (words_alpha.txt)
  - Filtered to **Google 10k** frequency list from `first20hours/google-10000-english`
- **Names:**
  - `smashew/NameDatabases` (US first names, US surnames)
- **Slang (informal):**
  - `dariusk/corpora` interjections + strange_words
- **Abbreviations:**
  - `dariusk/corpora` US airport IATA codes
 - **Frequency list (filter):**
   - `first20hours/google-10000-english` (google-10000-english.txt)

Filtering rules:

- A–Z only
- Length 2–7
- Allowlist: `crossword-engine/wordlists/allowlist.txt`
- Banlist: `crossword-engine/wordlists/banlist.txt`
- Core words must appear in the **Google 10k** list

---

## How to Run

1) Download wordlists (requires network access):

```
python crossword-engine/scripts/download_wordlists.py
```

2) Run the engine (generates until stopped):

```
python crossword-engine/run_engine.py
```

Optional flags:

- `--seed <int>` for deterministic runs
- `--time-limit <seconds>` for solver timeout per attempt
- `--sleep <seconds>` to throttle generation
- `--max <count>` to stop after N puzzles
- `--output-dir <path>` to change output folder
- `--wordlists-dir <path>` to change wordlist folder

---

## Black Cell Rules

- Only border cells may be black
- Maximum of 4 black cells
- Any black cell must be connected to a corner on that border via a contiguous chain
- Rules must exactly match the iOS app

---

## Slot Extraction & Numbering

- Identify across and down entries (length ≥ 2)
- Standard crossword numbering (row-major; shared number if both start at same cell)
- For each entry output:
  - number
  - direction (across/down)
  - ordered list of cell coordinates
  - answer (A–Z)
  - clue (empty string for now)

---

## Filling Strategy

Constraint-based backtracking (not naive brute force).

Required heuristics:

- MRV (minimum remaining values)
- Forward checking
- Cached candidate filtering by letter pattern

Performance:

- Pre-index wordlists by length and letter position
- Abort and resample grid on timeout
- Optional seed for deterministic generation

---

## Hashing & Deduplication

Canonical representation includes:

- width and height
- sorted black cell coordinates
- solution grid (row-major, `#` for black)

Hashing:

- SHA-256 over canonical bytes
- Puzzle ID format: `mcw_v1_<first16hex>`

Reject duplicates within and across runs.

---

## Agent Rules

### Do

- Validate every puzzle before output
- Test black-cell constraints and slot numbering
- Keep generation reproducible when seeded

### Don’t

- Don’t output puzzles without clue fields (use empty strings)
- Don’t change canonicalization without bumping version
- Don’t write puzzles outside `Puzzles/Puzzles_NO_CLUES/`
