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

Everything runs in your normal session. For a second opinion at any point,
**`/rb-review`** runs an independent, read-only reviewer on your code changes or a
design doc. Details: [docs/PIPELINE.md](docs/PIPELINE.md).

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
global `CLAUDE.md`, four short command descriptions and one agent description.

## Skills and agents

**Skill:** instructions or a checklist loaded into your current session when needed.
It shares your context and tools, so it is cheap.
**Agent:** a separate worker with its own fresh context, its own tool limits and
optionally its own model. It reports back but never sees your conversation.

| Use a skill when | Use an agent when |
| --- | --- |
| Claude should follow a format or checklist in the work it is already doing | You need an independent view the conversation can't bias, such as a review |
| Several commands or agents share the same guidance | The work must be restricted, for example read-only |
| Context from the conversation helps | A big read-heavy job would clutter your session, and only the conclusion matters |
| You want the lowest token cost | You are willing to pay for a second, separate read |

This repository ships one agent, `rb-reviewer`, because a review is only worth having
if it is independent. It ships no skills: the workflow commands carry their own short
instructions, and nothing is shared between several of them yet.

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
| 4 commands | `/rb-design`, `/rb-intake`, `/rb-implement`, and the optional `/rb-review` |
| 1 agent | `rb-reviewer`, read-only, used only by `/rb-review` |
| 5 hooks | approval gate, deploy guard, read-only guard, secret scan, denylist scan |
| 4 scripts | `bootstrap.sh` (install), `doctor.sh` (check a machine), `init-project.sh` (set up an existing project), `validate.sh` (lint and test this repository) |

```
claude/            everything that is linked into ~/.claude
  CLAUDE.md        working style and workflow rules
  settings.base.json
  agents/  commands/  hooks/
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
