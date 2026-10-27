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
- Keep commit messages and pull request descriptions short: what changed and why, in a
  few lines. Never add a `Co-Authored-By: Claude` trailer, a "Generated with Claude
  Code" line, or any other attribution to Claude.

## Workflow

Projects that contain `.claude/pipeline.json` use a three-step workflow. Each step is
a command the human runs; nothing runs on its own.

| Step | Command | Writes |
| --- | --- | --- |
| Design | `/rb-design <name>`, after discussing and researching the idea | `docs/architecture/NNN-name.md` (draft) |
| Phases | `/rb-intake <design>`, once the human has approved it | `docs/plans/NNN-name.md` |
| Build | `/rb-implement <plan> [phase \| all]` | code and tests; ticks the phase |

- **One human gate.** Only a human sets `status: approved` on a design. Never set it,
  and never work around a blocked write: a hook enforces this.
- Code is written only while `docs/plans/.active` names a plan whose design is
  approved. `/rb-implement` sets it.
- If the design cannot be followed as written, stop and ask. Do not redesign.
- Claude Code's auto-memory is a per-machine scratchpad. Anything durable goes into
  the project's `docs/` and is committed.
