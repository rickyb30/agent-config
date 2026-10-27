---
description: Write up the design discussed in this conversation as a short draft design doc in docs/architecture/.
argument-hint: <short-name>
disable-model-invocation: true
---

Write up the design we have discussed in this conversation. Short name: $ARGUMENTS

1. If no short name was given, propose one (lowercase, hyphens) and ask.
2. If this conversation contains no design discussion, say so and stop. Do not invent
   a design from the name alone.
3. Pick the next number: list `docs/architecture/`, ignore `000-template.md`, and use
   the highest `NNN` plus one, zero-padded to three digits (`001` if none). Never
   overwrite an existing file; if the name is taken, ask whether to revise that file.
4. Write `docs/architecture/NNN-short-name.md` in this shape:

   ```markdown
   ---
   title: <title>
   status: draft
   date: <today>
   ---

   # <title>

   ## Purpose
   What the project is for and the problem it solves. A few sentences.

   ## High-level architecture
   The main parts, how they connect, and how data or requests flow between them.
   A short list or a simple text diagram.

   ## Tech stack
   Languages, platforms, services and tools, with versions where they matter.

   ## Identity
   Who and what authenticates, and with which identities, roles or service accounts.

   ## Security and governance
   Secrets handling, network exposure, data classification, access, audit, cost limits.

   ## Open questions
   ```

5. Rules for the content:
   - Use only what was said in this conversation. Where something needed was not
     discussed, write `TODO: not discussed` rather than a guess.
   - Identity, and Security and governance, apply only when the project needs them.
     Otherwise write `Not applicable: <one-line reason>`, for example "runs inside the
     platform with its built-in permissions; no new identities".
   - Where a point came from research done in the conversation (docs, limits,
     pricing, API behaviour), keep its source next to it as a link.
   - Leave out Open questions when there are none.
   - Keep it short: one or two pages. Where a choice was made, one line on why.
6. Print the path and any TODOs or open questions, then stop.

`status` is always `draft`. Never write `approved`: the human reviews the doc and
approves it. The next step is theirs, then `/rb-intake <path>`.
