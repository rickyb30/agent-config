---
description: Run the independent-reviewer on the current diff against its approved plan and write findings to docs/reviews/.
argument-hint: [base-ref] [docs/plans/NNN-name.md]
disable-model-invocation: true
---

Run the review stage with: $ARGUMENTS

1. Plan: use the plan path if one was given, otherwise the path in `docs/plans/.active`.
   If neither exists, ask.
2. Diff range: if a base ref was given, use `<base-ref>...HEAD` plus uncommitted changes.
   Otherwise use the uncommitted working tree against `HEAD`. If that is empty, ask for
   a base ref.
3. Delegate to the `independent-reviewer` subagent. The message you send contains
   exactly three things: the plan path, the diff range, and the milestone under review
   if known.

   Do not include anything about what was implemented, how, why, or how well. Do not
   pass the implementer's final message, the log file, or your own reading of the
   change. The reviewer must form its view from the plan and the diff alone.
4. When it returns, confirm that `docs/reviews/NNN-review.md` exists.
5. Report the verdict and the findings table as written. Do not soften, reorder or
   dispute findings, and do not start fixing them.

Fixes for `changes required` go back through `/implement`.
