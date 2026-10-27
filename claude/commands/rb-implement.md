---
description: Implement the next phase (or a named phase, or all remaining phases) of a plan in docs/plans/.
argument-hint: <docs/plans/NNN-name.md> [phase-number | all]
disable-model-invocation: true
---

Implement from this plan: $ARGUMENTS

1. The first argument is the plan path. If it is missing, list `docs/plans/` and ask.
2. Read the plan, then the design named in its `design:` front matter. If the design's
   `status` is not `approved`, stop and say so. Do not offer to change it.
3. Write the plan path, on one line, to `docs/plans/.active`. Code can only be written
   while that file names a plan whose design is approved.
4. Choose the work: the phase number given; otherwise the first phase still marked
   `- [ ] done`; with `all`, every remaining phase in order.
5. For each phase:
   - Build only that phase, following the project `CLAUDE.md`.
   - Run the project's checks: `scripts/verify.sh` if it exists, otherwise the
     commands in `CLAUDE.md`. Fix failures that belong to this phase.
   - When the checks pass, change that phase's `- [ ] done` to `- [x] done`.
   - Report what changed, the real check results, and any command the human needs to
     run (deploys and applies are theirs).
6. Stop and ask, without improvising, when:
   - the design or plan is wrong, unclear, or cannot be followed as written;
   - the phase would need something the design does not cover, such as a new service,
     a different stack, or a change to identity or security;
   - a check fails for a reason outside the phase;
   - a hook blocks a tool call.
7. When every phase is marked done, delete `docs/plans/.active` and say the plan is
   complete.

Never edit the design, never run commands that change a live environment, and do not
commit unless asked.
