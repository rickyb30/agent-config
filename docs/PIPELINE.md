# Workflow

Three commands and one approval. Everything runs in your normal Claude Code session:
no subagents, so nothing re-reads the context behind your back.

| # | You do | Command | Result |
| --- | --- | --- | --- |
| 1 | Discuss the idea with Claude, and research anything you need to, until you have conclusions | | |
| 2 | Have it written up | `/rb-design <name>` | `docs/architecture/NNN-name.md`, `status: draft` |
| 3 | Review it, then set `status: approved` yourself | | **the gate** |
| 4 | Break it into phases | `/rb-intake <design>` | `docs/plans/NNN-name.md` |
| 5 | Build | `/rb-implement <plan>` | code and tests for the next phase; the phase is ticked |

Repeat step 5 for each phase, or run `/rb-implement <plan> all` to do the remaining
phases in one go. `/rb-implement <plan> 2` runs phase 2 specifically.

## Research

Research happens in step 1, before the design is written: ask Claude to look up
documentation, limits, pricing or how a service behaves while you discuss. Points that
came from research keep their source link in the design. There is no research stage
after the design is locked.

## The design doc

`/rb-design` writes five sections from what you discussed:

1. **Purpose**: what the project is for.
2. **High-level architecture**: the parts and how they connect.
3. **Tech stack**.
4. **Identity**, when the project needs it.
5. **Security and governance**, when the project needs it.

Sections 4 and 5 say `Not applicable: <reason>` for projects that don't need them,
such as a workflow that runs inside a platform with its built-in permissions. Anything
needed but not discussed is marked `TODO: not discussed` rather than guessed, and open
questions are listed at the end.

Review it against your conversation before approving: is everything captured, and is
nothing invented?

## The phases

`/rb-intake` refuses to run until the design is approved. It writes one section per
phase:

```markdown
## Phase 1: the query runs and returns the top ten
- Build: the scheduled workflow and its query
- Files: workflows/expensive-queries.yaml
- Done when: a manual run lists ten queries with their cost
- [ ] done
```

Each phase leaves the project working. Steps that change a live environment are
marked "(you run this)": agents don't run deploys.

## Opting a project in

The gate applies only to projects that contain `.claude/pipeline.json`.

- **New project:** create it from the project-template repository.
- **Existing project:** run, from a terminal in the project,

  ```bash
  ~/code/agent-config/scripts/init-project.sh
  ```

  It finds the folders that look like source, asks you to confirm, writes the file,
  and creates `docs/architecture/` and `docs/plans/`. It never overwrites a file.
  Options: `--source-paths "src,tests"`, `--all`, `--allow-deploy "CMD, CMD"`,
  `--yes`, `--dry-run`.

`.claude/pipeline.json` settings:

```json
{
  "source_paths": ["src", "tests"],
  "allow_deploy": ["dbt build --target dev"]
}
```

- `source_paths`: folders that need an approved design before Claude writes to them.
  Empty or absent means everything except `docs/` and `.claude/`.
- `allow_deploy`: environment-changing commands Claude may run in this project.
  Matched from the start of the command.

Only you can create or edit this file; Claude is blocked from it.

## What the hooks enforce

Hooks are shell scripts and cost no tokens.

| Hook | Rule |
| --- | --- |
| `require-approved-plan.sh` | In an opted-in project, a write to a source path is blocked unless `docs/plans/.active` names a plan whose design has `status: approved`. `/rb-implement` sets that file and deletes it when every phase is done. |
| `require-approved-plan.sh` | No tool call may leave a design doc with `status: approved`, so approval is always yours and an approved design is read-only for Claude. To change one, set it back to `draft` yourself. |
| `require-approved-plan.sh` | `.claude/pipeline.json` cannot be created or edited by a tool call. |
| `guard-deploy.sh` | In every project, commands that change a live environment are blocked for Claude: infrastructure apply and destroy, cloud CLI calls that create, change or delete, warehouse SQL that writes, job and bundle deploys, `dbt` runs, `kubectl` and `helm` changes. Read, validate and plan commands pass. |
| `secret-scan.sh` | Content about to be written, and staged changes at `git commit`, are scanned with gitleaks. |
| `denylist-scan.sh` | Commits to this repository are checked against your private denylist. |

## Known limits

- The gate covers the file-writing tools. A shell command can still change files;
  the gate stops drift, it is not a sandbox.
- The deploy guard reads command text only. It can't see what a script or Makefile
  target does, and it can block a command that merely mentions a deploy command.
  Read-only cloud credentials for Claude are the control that really holds.
- Work done outside the repository, in a platform's web UI, passes through no hook.
- After a plan is finished its design stays approved. `/rb-implement` removes
  `docs/plans/.active` when all phases are done, which closes the gate again.
