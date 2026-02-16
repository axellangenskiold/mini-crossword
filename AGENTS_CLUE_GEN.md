# AGENTS_CLUE_GEN.md — Mini Crossword Clue Generation

Use this file when generating clues for puzzles in `Puzzles/Puzzles_NO_CLUES/`.
Output completed puzzles to `Puzzles/Puzzles_FINISHED/`.

## Rules

- Fill every `entries.across[].clue` and `entries.down[].clue`.
- Do not change answers, grid, dimensions, or black cells.
- Keep clues short, clear, and varied within each puzzle.
- Mixed difficulty: mostly approachable, with a few slightly tougher clues.
- Abbreviations are allowed only if they are widely known.
- Avoid obscure trivia; prefer general knowledge, common phrases, and everyday words.
- Use ASCII only.
- External APIs are allowed for clue generation.

## Style Guidance

- Vary clue types within a puzzle:
  - Straight definition (e.g., "Ocean inlet")
  - Synonym (e.g., "Swiftly")
  - Fill-in-the-blank (e.g., "Blanket \_\_\_")
  - Category hint (e.g., "U.S. state capital")
  - Abbreviation (clearly marked if needed)
- Proper nouns:
  - People: "Singer Adele" / "Inventor Edison"
  - Cities: "Florida city" / "Capital of New York"
  - Countries/continents: "European country"
  - Mythology: "Greek god of war"
- Keep clues consistent and non-repeating within the same puzzle.

## Workflow

1. Load a puzzle JSON from `Puzzles/Puzzles_NO_CLUES/`.
2. Generate a clue for each across/down entry.
3. Save the updated JSON into `Puzzles/Puzzles_FINISHED/` with the same filename.
4. Remove the original from `Puzzles/Puzzles_NO_CLUES/` only after successful write.

## Suggested Prompt (for another agent)

You are generating clues for a mini crossword. Use the rules below:

- Fill all empty `clue` fields in the puzzle JSON.
- Keep clues short, clear, and varied within the puzzle.
- Mixed difficulty, mostly approachable.
- Abbreviations only if widely known.
- Avoid obscure trivia.
- Do not change answers or grid data.
- ASCII only.

Instructions can be found in AGENTS_CLUE_GEN.md for how to generate clues.
Puzzles without clues can be found in Puzzles_NO_CLUES.
