---
description: Run the engineering-planner on an approved architecture document and write a draft plan to docs/plans/.
argument-hint: <docs/architecture/NNN-name.md>
disable-model-invocation: true
---

Run the plan stage on: $ARGUMENTS

1. If no path was given, list `docs/architecture/` and ask which document.
2. Read the document's front matter. If `status` is not `approved`, stop and say:
   "Gate: <path> has status <status>. A human must set status: approved first."
   Do not offer to change it.
3. Delegate to the `engineering-planner` subagent. Give it the architecture path and,
   if it exists, the matching `docs/research/NNN-assessment.md` path.
4. When it returns, confirm that `docs/plans/NNN-name.md` exists with `status: draft`.
5. Report the plan path, the milestones, and the unresolved questions, then stop.

The next step is the human's: review the plan, then set `status: approved` by hand.
