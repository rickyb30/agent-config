---
name: architecture-intake
description: Checklist of the sections an architecture document must contain before research and planning. Use when validating a file under docs/architecture/, or when asked whether a design doc is complete.
---

# Architecture intake

Intake checks that a design document is complete enough to challenge. It judges
presence and specificity, not quality. It reports gaps and rewrites nothing.

## Front matter

```yaml
---
title: Short name of the design
status: draft        # draft | challenged | approved (only a human sets approved)
date: 2026-01-31
---
```

## Required sections

| Section | Present when | Common gap |
| --- | --- | --- |
| Goals | Outcomes are stated and could be checked | A list of features instead of outcomes |
| Non-goals | At least one thing is explicitly excluded | Missing entirely |
| Constraints | Technical, organisational, budget and time limits are named | Only technical ones |
| Components | Each component has a responsibility and its interfaces | Boxes with no stated responsibility |
| Key decisions | Each decision names the option chosen and at least one rejected | Decisions stated as facts, no alternative |
| NFRs | Targets have numbers: latency, availability, volume, recovery, security | Adjectives ("fast", "secure") |
| Open questions | Listed, or the section says "none" | Questions buried in other sections |

Section titles may vary ("Non-functional requirements" for NFRs). Match on meaning.

## Report format

Print this in the conversation. Do not write a file and do not edit the document.

```
Intake: docs/architecture/NNN-name.md  (status: draft)

| Section | Result | Note |
| --- | --- | --- |
| Goals | ok | |
| Non-goals | missing | |
| NFRs | weak | availability has no target |

Ready for research: no (1 missing, 1 weak)
```

Results are `ok`, `weak` (present but not specific enough to challenge) or `missing`.
A document is ready for research when nothing is `missing`. `weak` items are listed
for the author and do not block.
