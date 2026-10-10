---
name: knowledge-proposal
description: Format for proposing a lesson or pattern to a project's knowledge base by writing to docs/knowledge/inbox/. Use after a review, a failed run or a deviation, or when asked to record a lesson.
---

# Knowledge proposal

Agents propose; a human curates. A proposal is a single file in
`docs/knowledge/inbox/`. Curated folders (`patterns/`, `lessons/`, `references/`) and
`INDEX.md` are edited by a human only, and a hook blocks agent writes there.

## Is it worth proposing?

Propose when all three are true:

- it would change what someone does next time on this project;
- it is backed by something that happened (a review finding, a failed check, a deviation);
- it is not already in `INDEX.md`.

Do not propose restatements of the plan, general programming advice, or status updates.

## File

`docs/knowledge/inbox/YYYY-MM-DD-short-title.md`

```markdown
---
status: proposed            # proposed | accepted | retired
date: 2026-01-31
kind: lesson                # lesson | pattern | reference
evidence: docs/reviews/003-review.md#finding-2
review-by: 2026-07-31       # when this should be re-checked; default six months
tags: [retries, jobs]
---

# Cap retries wherever a job re-enqueues itself

## What happened
One or two sentences of fact, with the evidence link.

## Lesson
The rule, stated so it can be followed: when X, do Y.

## Applies when
The conditions under which this holds, and a case where it does not.

## Suggested index line
`lessons/cap-retries.md` | Cap retries wherever a job re-enqueues itself | retries, jobs
```

## Rules

- One lesson per file. Keep it under 40 lines.
- `evidence` must point at a real file, finding or commit in this repository.
- Write it so it makes sense inside this project only. Do not generalise for other
  projects; promotion to shared configuration is a separate, manual, scrubbed step.
- No secrets, credentials or personal data.

## What happens next

A human reads the proposal, then either deletes it or moves it into `patterns/`,
`lessons/` or `references/`, sets `status: accepted`, and adds the index line.
