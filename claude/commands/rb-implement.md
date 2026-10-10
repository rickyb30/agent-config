---
description: Run the implementer on one milestone of an approved plan.
argument-hint: <docs/plans/NNN-name.md> [milestone]
disable-model-invocation: true
---

Run the implement stage with: $ARGUMENTS

1. The first argument is the plan path; the optional second is a milestone such as `M2`.
   If no plan was given, list `docs/plans/` and ask.
2. Read the plan's front matter. If `status` is not `approved`, or the architecture it
   references is not `approved`, stop and say which gate is closed. Do not offer to
   change it.
3. Read `docs/plans/NNN-log.md` if it exists.
   - If the latest entry is a `DEVIATION` without a recorded human decision, stop and
     show it.
   - If no milestone was given, pick the first milestone with no `done` entry.
4. Write the plan path, on one line, to `docs/plans/.active`.
5. Delegate to the `implementer` subagent with the plan path and that one milestone.
6. When it returns, read the new log entry and report: milestone, `done` or
   `deviation`, and the check results as logged.

Run one milestone per invocation. Do not start the next milestone, and do not resolve
a deviation yourself: a deviation goes to the human.
