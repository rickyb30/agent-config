---
name: architecture-assessment
description: Output template for challenging an architecture document, with verified facts kept apart from recommendations and an alternatives matrix. Use when writing an assessment to docs/research/.
---

# Architecture assessment

An assessment gives the author what they need to revise a design. It does not revise
the design for them.

## The fact and recommendation split

- **Verified fact**: something you confirmed during this run, with a source. A source is
  a URL you fetched or a `file:line` you read. Record the date for anything that changes
  (pricing, limits, versions).
- **Recommendation**: your judgement. It may rest on facts, and it cites them by number.
- Anything you recall but did not confirm is not a fact. Put it under open questions as
  "unverified: ...".

## Template

Write to `docs/research/NNN-assessment.md`, where `NNN` matches the architecture document.

```markdown
---
architecture: docs/architecture/NNN-name.md
date: 2026-01-31
---

# Assessment: <title>

## Summary
Three to five sentences: is the design sound, and what are the main risks.

## Verified facts
| # | Fact | Source | Checked |
| --- | --- | --- | --- |
| F1 | The queue service caps messages at 256 KB | https://docs.example.com/limits | 2026-01-31 |
| F2 | The repo already has a retry helper | src/lib/retry.py:14 | 2026-01-31 |

## Alternatives matrix
One row per realistic option for each key decision, including the proposed one.

| Decision | Option | Build cost | Run cost | Operational burden | Main risk |
| --- | --- | --- | --- | --- | --- |
| Job store | Proposed: relational table | low | low | existing backups cover it | lock contention above 500 jobs/s |
| Job store | Dedicated queue service | medium | usage-based | one more service to monitor | 256 KB payload cap (F1) |

## Security gaps
Authentication, authorisation, secrets handling, data exposure, trust boundaries.

## Failure modes
For each component: what happens when it is slow, down, or returns bad data, and
whether the design says so.

## Unnecessary complexity
Components, abstractions or configurability the stated goals do not require.

## Recommendations
| # | Severity | Recommendation | Based on |
| --- | --- | --- | --- |
| R1 | high | State a recovery target for the job store | F2, failure modes |

## Open questions
Questions for the author, and anything unverified.
```

Severity: `high` (the design should not be approved until this is answered), `medium`
(should be answered before planning), `low` (worth considering).

Write "none found" in a section rather than leaving it out.
