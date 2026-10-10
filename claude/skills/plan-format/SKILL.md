---
name: plan-format
description: Schema for implementation plans and their progress log, including milestone and acceptance-criteria format. Use when writing a plan to docs/plans/, implementing a milestone from one, or logging progress or a deviation.
---

# Plan format

## Plan file: `docs/plans/NNN-name.md`

`NNN` matches the architecture document. Once a human sets `status: approved` the plan
is read-only for agents; progress goes in the log file.

```markdown
---
title: Short name
status: draft                                   # draft | approved (only a human sets approved)
architecture: docs/architecture/NNN-name.md     # must itself be approved
date: 2026-01-31
---

# Plan: <title>

## Requirements map
| Requirement (from the architecture) | Component | Files |
| --- | --- | --- |
| G1: jobs survive a restart | job store | src/jobs/store.py, migrations/0004_jobs.sql |

## Dependencies
New libraries, services, credentials or access. "None" if none.

## Migrations and interfaces
Schema changes, data moves, and every interface that is added or changed, with its shape.

## Must not change
Files, interfaces and behaviours that are out of bounds.

## Rollout and rollback
Which environments change, in what order, who runs each change, and how each step is
undone. "No deployed change" if none. Agents do not run deploys; see `guard-deploy`.

## Milestones

### M1: <outcome, not activity>
- Scope: what is built.
- Files: paths expected to change.
- Acceptance criteria:
  - [ ] AC1.1: a statement a reviewer can check by running or reading something
  - [ ] AC1.2: ...
- Checks: commands that must pass (default: `scripts/verify.sh`).

### M2: ...

## Unresolved questions
Numbered. "None" if none.
```

## Milestone rules

- Each milestone leaves the project building and its tests passing.
- A milestone is small enough to review in one sitting.
- Acceptance criteria are observable: "returns 404 for an unknown id", not "handles
  errors properly".
- Order milestones so the riskiest assumption is tested first.

## Log file: `docs/plans/NNN-log.md`

The implementer appends one entry per run. The plan's checkboxes stay untouched.

```markdown
## M1: done (2026-01-31)
- Changed: src/jobs/store.py, tests/test_store.py
- Checks: scripts/verify.sh passed (lint, types, 42 tests)
- Acceptance criteria: AC1.1 met, AC1.2 met

## M2: DEVIATION (2026-02-01)
- Blocked at: AC2.1
- What the plan says: reuse the existing retry helper
- What was found: the helper is synchronous and the new caller is async
- Options: (a) add an async variant, (b) wrap the call in a worker thread
- Work left in the tree: src/jobs/runner.py partially written, tests failing
- Decision needed from: human
```

A deviation entry states the facts and the options. It does not pick one.

## Active plan

`docs/plans/.active` holds the path of the plan being implemented, on one line. The
`/rb-implement` command writes it. Source writes are blocked unless it names an approved
plan whose architecture is approved.
