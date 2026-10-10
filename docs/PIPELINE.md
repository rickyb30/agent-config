# Pipeline

Four agents, two human gates. Files are the contract between stages: each stage reads
fixed paths and writes one output, so any stage can be re-run or inspected on its own.

## Stages

| # | Stage | Entry point | Runs as | Reads | Writes |
| --- | --- | --- | --- | --- | --- |
| 1 | Design | you, in chat | | | `docs/architecture/NNN-name.md` (`status: draft`) |
| 2 | Intake | `/intake <doc>` | main session | the doc | nothing; prints a gap report |
| 3 | Research | `/research <doc>` | `architecture-researcher` | the doc, the repo, the web | `docs/research/NNN-assessment.md`; doc becomes `challenged` |
| | **Gate 1** | you | | the assessment | you revise the doc and set `status: approved` |
| 4 | Plan | `/draft-plan <doc>` | `engineering-planner` | approved doc, assessment | `docs/plans/NNN-name.md` (`status: draft`), `docs/adr/` |
| | **Gate 2** | you | | the plan | you set `status: approved` |
| 5 | Implement | `/implement <plan> [M#]` | `implementer` | approved plan | source, tests, `docs/plans/NNN-log.md` |
| 6 | Review | `/review-diff [base-ref]` | `independent-reviewer` | approved plan, the diff | `docs/reviews/NNN-review.md` |
| 7 | Verify | `scripts/verify.sh`, CI | no model | | |

`/lesson <text>` writes a knowledge proposal at any point.

The plan and review commands are named `/draft-plan` and `/review-diff` because
`/plan` and `/review` are built-in Claude Code commands.

## Status values

| Document | Values | Who moves it |
| --- | --- | --- |
| Architecture | `draft` → `challenged` → `approved` | `/research` sets `challenged`; only you set `approved` |
| Plan | `draft` → `approved` | only you set `approved` |
| Knowledge entry | `proposed` → `accepted` → `retired` | agents create `proposed`; you do the rest |

## Opting a project in

The source gate applies only to projects that contain `.claude/pipeline.json`:

```bash
mkdir -p .claude docs/{architecture,research,plans,reviews,adr,knowledge/inbox}
echo '{}' > .claude/pipeline.json
```

With `{}`, every path except `docs/` and `.claude/` is a source path. To gate only
some folders:

```json
{ "source_paths": ["src", "tests", "migrations"] }
```

The path guard for the researcher, planner and reviewer applies in every project.

## What the hooks enforce

| Hook | Rule |
| --- | --- |
| `require-approved-plan.sh` | In an opted-in project, a write to a source path is blocked unless `docs/plans/.active` names a plan with `status: approved` whose `architecture:` document is also `approved`. |
| `require-approved-plan.sh` | No tool call may leave a file in `docs/architecture/` or `docs/plans/` with `status: approved`. Approved documents are therefore read-only for agents, and approval cannot be granted by an agent. |
| `require-approved-plan.sh` | `.claude/pipeline.json` cannot be edited by a tool call. |
| `guard-paths.sh` | Researcher writes only `docs/research/`; planner only `docs/plans/` and `docs/adr/`; reviewer only `docs/reviews/`. Their shell access is limited to read-only git commands. |
| `guard-paths.sh` | Any subagent may write `docs/knowledge/inbox/`; none may write elsewhere under `docs/knowledge/`. |
| `secret-scan.sh` | Content about to be written, and staged changes at `git commit`, are scanned with gitleaks. |

To edit an approved document, set its status back to `draft` yourself, make or request
the change, and approve it again.

## Known limits

Be clear about what the gates are: they stop an agent from drifting past a gate, and
they make every approval a visible act of yours. They are not a sandbox.

- The source gate covers the file-writing tools. An agent with shell access (the
  implementer, the main session) can still change files through a shell command.
  Review and `scripts/verify.sh` are the backstop.
- The main session is not restricted by the path guard, because you direct it.
- A plan stays `approved` after its work is finished. Remove `docs/plans/.active` when
  a plan is complete to close the source gate again.
- The role-based guard relies on agent front matter hooks and on the `agent_type` field
  of hook input. On an old Claude Code release neither may exist; `scripts/doctor.sh`
  warns about this.

## Deviations

The implementer does not decide. When the plan cannot be followed, it appends a
`DEVIATION` entry to `docs/plans/NNN-log.md` and stops. `/implement` refuses to continue
past an unresolved deviation. You record the decision in the log, or revise the plan
(back to `draft`, then approve again).

## Knowledge loop

1. After a review or a failed run, the reviewer or implementer writes a proposal to
   `docs/knowledge/inbox/`. `/lesson` does the same by hand.
2. You read it, then delete it or move it into `patterns/`, `lessons/` or
   `references/`, set `status: accepted`, and add one line to `INDEX.md`.
3. Agents read `INDEX.md` first and open only matching entries.

Nothing moves between projects automatically. See [PUBLIC-SAFETY.md](PUBLIC-SAFETY.md)
for how a lesson is promoted into this repository.
