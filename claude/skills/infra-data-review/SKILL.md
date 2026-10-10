---
name: infra-data-review
description: Review checklist for infrastructure code, cloud resources, data pipelines, SQL, warehouse objects and notebooks. Use alongside review-rubric when a diff touches infrastructure-as-code, pipeline or job definitions, SQL, transformations or notebooks.
---

# Infrastructure and data review

An addition to `review-rubric`, not a replacement. Same severity scale, same rule that
every finding has a `file:line`. Platform-neutral on purpose: the project's `CLAUDE.md`
and project skills supply the conventions of its particular cloud or warehouse.

Record "checked, no finding" or "not applicable: reason" for each category.

## Infrastructure

1. **Identity and access**: roles and policies grant the least that works. No wildcard
   actions or resources, no broad built-in admin roles, no long-lived keys where a
   managed or workload identity is available. Human and service identities are separate.
2. **Network exposure**: nothing is reachable from the public internet unless the plan
   says so. Storage, databases and control endpoints are private by default; ingress
   rules name sources rather than allowing all.
3. **Encryption and secrets**: data is encrypted at rest and in transit. Secrets come
   from a secret store reference, never from variables files, defaults, outputs or state.
4. **Blast radius**: a change that replaces or destroys a stateful resource (a rename
   that forces recreation, a changed immutable property) is called out. Deletion
   protection, backups and retention are set on anything holding data.
5. **Environment separation**: no hard-coded account, subscription, workspace or
   region identifiers; environments differ by configuration, not by copied code. Nothing
   in a lower environment can reach production data.
6. **Cost**: compute has a size, an auto-stop or scale-down, and an upper bound.
   Storage has lifecycle or retention rules. New paid services are in the plan.
7. **Drift and state**: resources are defined in code, not created by hand or by a
   one-off script. State is remote and locked. Naming and tagging follow the project's
   convention so resources can be attributed.

## Data pipelines and SQL

8. **Idempotency**: running a job twice, or re-running after a partial failure,
   produces the same result. Appends without a key, and inserts without a merge or
   overwrite boundary, are findings.
9. **Incremental logic**: watermarks and windows handle late and out-of-order data,
   boundaries are neither skipped nor double-counted, and a full refresh path exists.
10. **Schema changes**: a change is backward compatible for downstream readers or the
    plan sequences the migration. Dropped or renamed columns, changed types and changed
    nullability are called out. No `select *` across a contract boundary.
11. **Data quality**: keys are tested for uniqueness and non-null, joins cannot fan out
    silently, and row counts or reconciliation checks exist where data moves between
    systems.
12. **Query cost and performance**: filters reach partition or clustering columns, no
    accidental cross joins, no unbounded scans in a scheduled job, and compute size
    matches the workload.
13. **Sensitive data**: personal or restricted fields are classified, masked or
    excluded as the plan requires, and are not copied into logs, samples, test fixtures
    or lower environments.
14. **Access to data**: grants are to roles, not individuals; no broad grants on a
    whole database or catalog; ownership of new objects is deliberate.
15. **Orchestration**: jobs have retries with a limit, a timeout, an alert on failure,
    and an owner. Dependencies between jobs are explicit, not timed.

## Notebooks

16. **Reproducibility**: runs top to bottom from a clean state, no reliance on cell
    order or leftover variables, no hard-coded user paths, parameters instead of edits.
17. **Outputs**: no query results, data samples, credentials or tokens saved in cell
    output. Logic that other work depends on lives in a tested module, not a notebook.

## What this review cannot see

State the limits in the review: a diff shows intended configuration, not the deployed
environment. If the plan's acceptance criteria depend on a dry run or a plan output
(for example an infrastructure plan showing no destroys), say whether that evidence
was provided, and record a `major` finding when it was required and is missing.
