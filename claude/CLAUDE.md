# Global instructions

Working style and universal rules for every project on this machine. Project facts
(stack, commands, constraints) belong in the project's own `CLAUDE.md`. A rule that
appears in both places gets deleted from one.

## Working style

- Say what you found before what you think. Mark anything unverified as unverified.
- Prefer the smallest change that satisfies the request. No drive-by refactors.
- Read the project `CLAUDE.md` and the files you are about to change before editing.
- Run the project's checks (`scripts/verify.sh` when present) before calling work done,
  and report the real result, including failures.
- When blocked or when the instructions conflict, stop and ask. Do not improvise around a gate.
- Never change a live environment yourself: no apply, deploy, destroy, or SQL that writes
  to a shared warehouse. Validate and plan, then hand the command to the human. A hook
  blocks these unless the project allows a specific command.
- Never put secrets, credentials, employer names, internal hostnames or personal paths
  into any file. Reference an environment variable or a secret store instead.

## Pipeline

Projects that contain `.claude/pipeline.json` use a gated pipeline. Files are the
contract between stages; each stage reads and writes fixed paths.

| Stage | Entry point | Reads | Writes |
| --- | --- | --- | --- |
| Design | human, outside Claude Code | | `docs/architecture/NNN-name.md` |
| Intake | `/rb-intake` | architecture doc | nothing, reports gaps |
| Research | `/rb-research` | architecture doc, repo | `docs/research/NNN-assessment.md` |
| Plan | `/rb-draft-plan` | approved architecture | `docs/plans/NNN-name.md` (draft) |
| Implement | `/rb-implement` | approved plan | source, tests, `docs/plans/NNN-log.md` |
| Review | `/rb-review-diff` | approved plan, diff | `docs/reviews/NNN-review.md` |
| Verify | `scripts/verify.sh`, CI | | |

Rules that hold in every stage:

- **Two human gates.** Only a human sets `status: approved` on an architecture doc or a
  plan. Never set it, never ask another agent to set it, and never work around a blocked
  write. Hooks enforce this; a blocked tool call is the system working as designed.
- **One orchestrator.** The main session runs the pipeline commands and delegates to
  subagents. Subagents do not delegate further.
- **Stay in your lane.** Each agent writes only its own output folder. If the task
  seems to need more, stop and report.
- **Deviations are reports, not decisions.** If the plan cannot be followed as written,
  record why in `docs/plans/NNN-log.md` and stop.
- **Independent review.** The reviewer receives the plan and the diff, never a summary
  of what the implementer believes it did.

## Knowledge

- Durable project knowledge lives in the project's `docs/knowledge/`. Read `INDEX.md`
  first and open only the entries that match the task.
- Agents propose knowledge by writing to `docs/knowledge/inbox/`. A human curates it.
- Claude Code's auto-memory is a per-machine scratchpad. Anything worth keeping goes
  into `docs/knowledge/` and is committed.
- Nothing moves between projects automatically.
