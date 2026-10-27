---
description: Ad-hoc independent review of code changes or a design doc by a fresh, read-only reviewer.
argument-hint: "[base-ref | docs/architecture/NNN-name.md] [--research]"
disable-model-invocation: true
---

Run an independent review with: $ARGUMENTS

1. Work out the target:
   - no argument: the uncommitted changes against `HEAD`;
   - a path under `docs/architecture/`: that design doc;
   - anything else: the branch, as `<argument>...HEAD` plus uncommitted changes.
   If a code target has no changes, say so and stop.
2. Find the references:
   - always the project `CLAUDE.md`, if it exists;
   - for code, the plan named in `docs/plans/.active`, if present, and the design
     named in that plan's `design:` front matter.
   Pass paths only; do not read them out or summarise them.
3. Delegate to the `rb-reviewer` subagent. The message contains exactly: the target,
   the reference paths, and "research: yes" if `--research` was given, otherwise
   "research: no".

   Do not include anything about what was built, why, how it went, or your own view
   of it. The reviewer must form its own.
4. Print the reviewer's reply as it is. Do not soften, reorder or dispute it, and do
   not start fixing anything unless asked.
