# AGENTS.md — Mini Crossword iOS App

Offline-first iOS application for a daily mini crossword (“Daily Challenge”).
All puzzle data is local. The only online component is ads.

---

## Non-negotiables

- **Offline data loading:** No network calls for puzzles, clues, calendar logic, or progress.
- **Ads only:** Any non-ad network request is a bug.
- **Eligibility window:** Only puzzles from **1st of current month through today (inclusive)** are playable.
- **Default selection:** App opens focused on **today’s date**.
- **Persistence:** Puzzle data is bundled; user progress is stored locally.

---

## Main View — Daily Challenge

### Calendar

- Displays **current month only**.
- Days **1 → today** are selectable.
- Days **after today** are disabled.
- Styling:
  - **Completed puzzle:** green
  - **Uncompleted puzzle:** white
- Selecting a day opens that puzzle.

### Data population

- App ships with a bundled puzzle dataset.
- On app launch:
  - For each day from **1 → today**:
    - If puzzle is missing in local storage, populate it from the bundled dataset.
- No downloading, no online fallback.

### CTA

- A large button below the calendar: **“Today’s Puzzle”**
- Opens today’s puzzle (same behavior as tapping today).

---

## Puzzle View

### Grid

- Sizes: **5×5 to 7×6**
- **0–4 black cells**
  - Only on **border cells**
  - Must be **connected to a corner** on that border via a contiguous chain
- Black cells:
  - Are uneditable
  - Are skipped by navigation and focus

### Keyboard

- Custom keyboard
- Letters **A–Z only**
- Backspace supported
- No system keyboard or autocorrect

### Clue bar

- Displays the **clue (description)** for the currently active entry
- Left/right arrows navigate to previous/next entry

### Top-right controls

- **Hint** button
- **Difficulty** dropdown:
  - Easy
  - Medium
  - Hard

---

## Difficulty Rules

### Easy

- Unlimited hints
- When an entry is fully filled **and correct**:
  - Entry becomes **locked**
  - Cells turn **green**
  - Locked cells are **uneditable**

### Medium

- 2 hints per puzzle
- Entry locking behavior same as Easy

### Hard

- 2 hints per puzzle
- No per-entry validation or locking
- Correctness is evaluated **only when the entire grid is filled**

---

## Navigation & Focus Rules (NYT Mini–style)

### General

- Focus is always on a **fillable cell**
- Black cells are skipped automatically

### Phase 1 — Across

- On puzzle open, focus starts at the **first fillable cell scanning row-major**
- User types **across**
- When an across entry is completed:
  - Jump to the **next across entry start**, scanning:
    - left → right
    - top → bottom
- After the last across entry is completed, switch to Down mode

### Phase 2 — Down

- Focus resets to first fillable cell (row-major)
- User types **down**
- When a down entry is completed:
  - Jump to the **next down entry start**, scanning left-to-right, top-to-bottom

### Entry completion

- An entry is “complete” when all its cells are filled
- In Easy/Medium, correctness is checked **only at entry completion**

---

## Hint Rules

- A hint reveals the **correct letter** in the currently focused cell
- If the focused cell is already confirmed/locked:
  - Reveal the letter in the **next cell that would normally receive focus**
- Hint limits:
  - Easy: unlimited
  - Medium/Hard: 2 total per puzzle

---

## Completion & Validation

- When all fillable cells contain letters:
  - **Incorrect:** popup explaining something is wrong
  - **Correct:** popup (“Congratulations, you did it!”) and return to main view
- Hard mode validates **only here**, never earlier

---

## Data Model (Offline)

### Puzzle JSON (bundled)

Each puzzle includes its clues directly.

```json
{
  "id": "mcw_v1_ab12cd34",
  "date": "2026-02-06",
  "width": 5,
  "height": 5,
  "blackCells": [[0, 4]],
  "gridSolution": [
    ["C", "A", "T", "S", null],
    ["A", "R", "E", "A", "S"],
    ["R", "E", "D", "O", "N"],
    ["T", "A", "P", "E", "S"],
    ["S", "S", "E", "E", "R"]
  ],
  "entries": {
    "across": [
      {
        "number": 1,
        "cells": [
          [0, 0],
          [0, 1],
          [0, 2],
          [0, 3]
        ],
        "answer": "CATS",
        "clue": "Furry household pets"
      }
    ],
    "down": [
      {
        "number": 1,
        "cells": [
          [0, 0],
          [1, 0],
          [2, 0],
          [3, 0],
          [4, 0]
        ],
        "answer": "CARTS",
        "clue": "Shopping vehicles"
      }
    ]
  }
}
```

### Local storage

- User fill state
- Completion state
- Hints used
- Difficulty selected

⸻

### Agent Rules

Do

- Write pure functions for:
- eligibility window
- entry scanning order
- next-entry navigation
- hint targeting
- Add unit tests for all navigation and validation logic

Don’t

- Don’t validate entries per keystroke
- Don’t add networking beyond ads
- Don’t deviate from navigation rules

⸻

### Acceptance Checklist

- Calendar shows only current month
- Days 1 → today are playable
- Completed days turn green
- Missing days are populated from bundle at launch
- Grid respects size + black-cell constraints
- Navigation matches NYT mini behavior
- Clues are loaded from puzzle JSON
- App works fully offline
