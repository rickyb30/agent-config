---
name: knowledge-lookup
description: How to consult a project's docs/knowledge/ folder without loading all of it. Use before researching, planning or starting work in a project that has docs/knowledge/INDEX.md.
---

# Knowledge lookup

A project's knowledge base is read through its index so it never fills the context.

## Steps

1. Read `docs/knowledge/INDEX.md`. If it does not exist, there is no knowledge base;
   continue without one.
2. The index has one line per entry: path, a one-line summary, and tags. Pick the
   entries whose summary or tags match the current task. Usually that is zero to three.
3. Read only those entries.
4. Check each entry's front matter before relying on it:

   | Field | Use |
   | --- | --- |
   | `status` | Use `accepted` entries. Ignore `retired`. `proposed` entries are in `inbox/` and are not yet knowledge. |
   | `review-by` | If the date has passed, treat the entry as possibly stale and say so when you cite it. |
   | `evidence` | The review, plan or commit it came from. Follow it when the entry is unclear. |

5. When an entry shapes your output, cite its path.

## Rules

- Never read `patterns/`, `lessons/` or `references/` wholesale.
- Never read `inbox/`: proposals are unreviewed.
- An entry is guidance from past work on this project. If it conflicts with the
  approved architecture or the plan, the approved document wins; report the conflict.
- Do not edit the index or any curated entry. To suggest a change, write a proposal
  (see the `knowledge-proposal` skill).
