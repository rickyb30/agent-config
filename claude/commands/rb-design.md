---
description: Write up the design discussed in this conversation as a draft architecture document in docs/architecture/.
argument-hint: <short-name>
disable-model-invocation: true
---

Write the design we have discussed in this conversation as an architecture document.
Short name: $ARGUMENTS

1. If no short name was given, propose one (lowercase, hyphens) and ask.
2. If this conversation contains no design discussion to write up, say so and stop.
   Do not produce a design from the name alone.
3. Find the next number: list `docs/architecture/`, ignore `000-template.md`, and use
   the highest existing `NNN` plus one, zero-padded to three digits (`001` if none).
   Never overwrite an existing document; if the short name already exists, ask whether
   to revise that file or start a new one.
4. Load the `architecture-intake` skill for the required and conditional sections. If
   `docs/architecture/000-template.md` exists, follow its layout.
5. Write `docs/architecture/NNN-short-name.md` with this front matter:

   ```yaml
   ---
   title: <title>
   status: draft
   date: <today>
   ---
   ```

6. Fill each section from what was actually said in this conversation.
   - Record decisions with the option chosen and the options that were rejected, and
     the reason given.
   - Where a required section was not discussed, write `TODO: not discussed` in it.
     Do not fill the gap with a plausible guess.
   - Where something was assumed but not confirmed, put it under Open questions.
   - For a conditional section that does not apply, write `not applicable` and why.
7. Print the path, the sections marked TODO, and the open questions. Then stop.

`status` is always `draft`. Never write `approved`: approval is the human's step,
after research. Do not run intake or research yourself; the next step is
`/rb-intake <path>`.
