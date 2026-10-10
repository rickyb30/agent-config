---
description: Write a knowledge proposal to docs/knowledge/inbox/ by hand.
argument-hint: <what was learned>
disable-model-invocation: true
---

Record this lesson as a knowledge proposal: $ARGUMENTS

1. Load the `knowledge-proposal` skill.
2. If the lesson has no evidence yet (a review finding, log entry or commit in this
   repository), ask for it. Do not invent one.
3. Read `docs/knowledge/INDEX.md` and stop if the lesson is already covered, naming the
   existing entry.
4. Write one file to `docs/knowledge/inbox/` in the skill's format, with
   `status: proposed`.
5. Print the path and the suggested index line.

Do not move the file into a curated folder and do not edit `INDEX.md`. Curation is the
human's step.
