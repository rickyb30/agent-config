---
name: review-rubric
description: Severity scale, security checklist and output format for code review findings. Use when reviewing a diff against a plan or writing a review to docs/reviews/.
---

# Review rubric

## Severity

| Severity | Meaning | Effect on verdict |
| --- | --- | --- |
| blocker | Security hole, data loss or corruption, or an acceptance criterion not met | changes required |
| major | Wrong behaviour in a realistic case, or a missing test for changed logic | changes required |
| minor | Correct but fragile, unclear, or inconsistent with the project's conventions | approve with comments |
| note | Observation or question; no change requested | none |

When unsure between two levels, choose the higher one and say why.

## Checklist

Work through every category. Record "checked, no finding" when a category is clean and
"not applicable" with a reason when it does not apply.

1. **Authentication**: every new entry point establishes who the caller is.
2. **Authorisation**: access is checked per resource, not only per route; no check relies
   on the client.
3. **Secrets**: no credentials, tokens or keys in code, tests, fixtures, logs or errors.
4. **Input validation**: external input is validated at the boundary; queries, shell
   commands and file paths are not built from raw input.
5. **Data exposure**: responses, logs and errors do not leak personal data or internals.
6. **Race conditions**: shared state, check-then-act sequences, retries and idempotency.
7. **Failure handling**: timeouts, partial failure, error paths, cleanup, no swallowed errors.
8. **Performance**: queries in loops, unbounded reads, work on a hot path, missing limits.
9. **Missing tests**: each acceptance criterion and each new branch has a test that would
   fail without the change.
10. **Plan conformance**: every acceptance criterion of the milestone is met, and nothing
    was changed that the plan did not ask for or said must not change.

## Output: `docs/reviews/NNN-review.md`

```markdown
---
plan: docs/plans/NNN-name.md
diff: main...HEAD
date: 2026-01-31
verdict: changes required        # approve | approve with comments | changes required
---

# Review: <plan title>, <milestone>

## Findings
| # | Severity | Location | Finding | Suggested direction |
| --- | --- | --- | --- | --- |
| 1 | blocker | src/jobs/api.py:88 | Job lookup does not check the job belongs to the caller | Scope the query by owner |
| 2 | major | src/jobs/runner.py:41 | Retry loop has no upper bound | Cap attempts; test the cap |

## Acceptance criteria
| Criterion | Met | Evidence |
| --- | --- | --- |
| AC1.1 | yes | tests/test_store.py:20 |
| AC1.2 | no | finding 1 |

## Checklist
One line per category: finding numbers, "checked, no finding", or "not applicable: reason".

## Outside the plan
Changes in the diff that the plan did not ask for. "None" if none.
```

## Rules for findings

- A finding needs a `file:line` that exists in the diff or in a file you read.
- Describe the failure concretely: the input or sequence that goes wrong and what happens.
- Suggest a direction, not a patch. The reviewer does not write the fix.
- Do not soften a finding because the surrounding code is good.
