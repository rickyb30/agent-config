---
name: adr-writing
description: Format for architecture decision records extracted from an approved architecture document. Use when writing or updating files under docs/adr/.
---

# ADR writing

An ADR records one decision that the approved architecture already made, so the reason
survives after the design document is forgotten. Writing an ADR never makes a new
decision.

## When to write one

One ADR for each entry under "Key decisions" in the approved architecture. If a
decision is not in the architecture, it does not get an ADR; raise it as an unresolved
question in the plan instead.

## File

`docs/adr/NNNN-short-title.md`, numbered in sequence across the project (not per
architecture document). Never renumber or delete; supersede.

```markdown
---
status: accepted            # accepted | superseded by NNNN
date: 2026-01-31
source: docs/architecture/NNN-name.md
---

# NNNN: Store jobs in the relational database

## Context
What forced a decision: the requirement, the constraint, and the facts known at the time.
Two to five sentences.

## Decision
The option chosen, stated in one or two sentences in the active voice.

## Alternatives considered
- Dedicated queue service: rejected because of the payload cap and an extra service to run.
- In-memory queue: rejected because jobs must survive a restart.

## Consequences
What becomes easier, what becomes harder, and what would make this decision worth
revisiting.
```

## Rules

- Take context, alternatives and reasons from the architecture and its assessment. Do
  not invent a rationale; if the document gives none, write "Reason not recorded in the
  architecture" and list it as an unresolved question in the plan.
- One decision per file. Keep it under one page.
- Use fictional or generic names in examples.
