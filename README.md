# agent-config

A portable Claude Code setup: the same workflow commands and safety hooks on every
machine you work on, installed with one command.

This repository is generic. It holds no project knowledge and nothing from any
employer or client. See [docs/PUBLIC-SAFETY.md](docs/PUBLIC-SAFETY.md).

## The workflow

1. **Discuss and research** the idea with Claude until you have some conclusions.
   Look things up here, before the design is locked.
2. **`/rb-design <name>`** writes a short design doc: purpose, high-level
   architecture, tech stack, and identity and security where they apply.
3. **You review it** and set `status: approved` in it.
4. **`/rb-intake <design>`** breaks the approved design into phases.
5. **`/rb-implement <plan>`** builds the next phase and runs the checks. Repeat, or
   add `all` to run every remaining phase.

Everything runs in your normal session. Details: [docs/PIPELINE.md](docs/PIPELINE.md).

## What it gives you

- **The same setup everywhere.** You configure a machine once and stop re-explaining
  how you like to work.
- **A written design before code.** The conversation becomes a short doc you can check
  and keep, and the build follows it phase by phase.
- **You decide when building starts.** Claude can't write code in an opted-in project
  until you approve the design, and it can't approve it for you.
- **No surprise changes to live environments.** Apply, deploy, delete and warehouse
  writes are blocked for Claude unless a project allows a specific command.
- **Secrets and employer details stay out of commits.** Writes and commits are scanned.

The hooks are shell scripts and add no token cost. The only standing cost is the
global `CLAUDE.md` and three short command descriptions.

## Install on a machine

Needs `bash`, `git`, `jq`, `gitleaks` and `python3`.

```bash
git clone https://github.com/rickyb30/agent-config.git ~/code/agent-config
cd ~/code/agent-config
scripts/bootstrap.sh
scripts/doctor.sh               # confirms everything is in place
```

Then add your employer's name, internal domains, work email and home paths to
`~/.config/agent-config/denylist.txt`. That file never leaves the machine.

Run `bootstrap.sh` once per machine and again after each update. It is safe to re-run,
backs up anything it replaces, and removes links to files this repository no longer
ships. Details: [docs/SETUP.md](docs/SETUP.md).

## Use it in a project

- **New project:** create it from
  [project-template](https://github.com/rickyb30/project-template).
- **Existing project:** run this from a terminal in the project. It asks which
  folders to protect, then writes `.claude/pipeline.json` and the `docs/` folders.

  ```bash
  ~/code/agent-config/scripts/init-project.sh
  ```

Projects without `.claude/pipeline.json` behave as usual, apart from the secret scan
and the block on commands that change a live environment.

## What is in here

| Part | What it is |
| --- | --- |
| 3 commands | `/rb-design`, `/rb-intake`, `/rb-implement` |
| 4 hooks | approval gate, deploy guard, secret scan, denylist scan |
| 4 scripts | `bootstrap.sh` (install), `doctor.sh` (check a machine), `init-project.sh` (set up an existing project), `validate.sh` (lint and test this repository) |

```
claude/            everything that is linked into ~/.claude
  CLAUDE.md        working style and workflow rules
  settings.base.json
  commands/  hooks/
scripts/           bootstrap.sh  doctor.sh  init-project.sh  validate.sh  lib/
tests/             run.sh
docs/              SETUP.md  PIPELINE.md  PUBLIC-SAFETY.md
```

## Change this repository

```bash
scripts/validate.sh --strict    # lint, shell checks, secret and denylist scans, tests
```

Tag a release as `vMAJOR.MINOR.PATCH` once CI is green. Pinned machines move only by
`scripts/bootstrap.sh --ref <tag>` after you have read the diff between tags.
