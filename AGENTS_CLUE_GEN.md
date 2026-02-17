# AGENTS_CLUE_GEN.md - Mini Crossword Clue Generation

Use this file when generating clues for puzzles in `Puzzles/Puzzles_NO_CLUES/`.
Output completed puzzles to `Puzzles/Puzzles_FINISHED/`.

## Core Goal

Every clue must describe the specific answer. The solver does not know the answer in advance.

## Non-Negotiable Rules

- Fill every `entries.across[].clue` and `entries.down[].clue`.
- Do not change answers, grid, dimensions, cell coordinates, or black cells.
- Use ASCII only.
- Keep clues short and clear.
- Mixed difficulty is fine, but most clues should be approachable.
- Abbreviations are allowed only if they are widely known.
- Avoid obscure trivia.
- External APIs are allowed.

## Specificity Requirement (Mandatory)

A clue is valid only if it points to that exact answer, not just a random word of the same length/category.

Reject clues that are generic or non-informative, such as:

- "Common 6-letter word"
- "Normal 4-letter word"
- "Everyday term"
- "General vocabulary word"
- "Place name"
- "Person name"

If a clue could fit many unrelated answers, it is too weak and must be replaced.

## Allowed Clue Types

- Definition: "Large body of saltwater" -> SEA
- Fill-in-the-blank, only if specific enough: "Saint Elizabeth ___" -> SETON
- Category clue, only if specific enough: "Capital and largest city of Bahrain" -> MANAMA
- Light trivia is allowed if broadly known and specific.

## Proper Nouns (Strict)

- Proper-noun clues must include unique identifying context.
- Do not use vague clues like "City name" or "Famous person".
- Examples:
  - Good: "New York's capital" -> ALBANY
  - Bad: "U.S. city" -> ALBANY
  - Good: "Singer of 'Hello'" -> ADELE
  - Bad: "Singer" -> ADELE

## Quality Check Before Writing

For each clue, verify:

1. Does this clue describe this answer specifically?
2. Would this clue still make sense for many unrelated answers?
3. If yes, rewrite until specific.

## Uncertainty Policy (Option B)

If confidence is low:

- Use the most conservative specific clue you can produce.
- Flag that clue for review in your run notes/output summary.
- Do not fall back to generic filler clues.

## Workflow

1. Load a puzzle JSON from `Puzzles/Puzzles_NO_CLUES/`.
2. Generate clues for all across/down entries using the rules above.
3. Save updated JSON to `Puzzles/Puzzles_FINISHED/` with the same filename.
4. Remove the original from `Puzzles/Puzzles_NO_CLUES/` only after successful write.
5. Output a brief review list of low-confidence clues.

## Suggested Prompt (for another agent)

You are generating clues for a mini crossword. Follow AGENTS_CLUE_GEN.md exactly.

Requirements:

- Fill all empty `clue` fields.
- Every clue must specifically match its answer.
- No generic filler clues (for example: "Common 5-letter word").
- Fill-in-the-blank and category clues are allowed only when specific enough.
- Proper nouns must have unique identifying context.
- If uncertain, use a conservative specific clue and flag it for review.
- Do not change answers or grid data.
- ASCII only.
