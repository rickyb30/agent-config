# agent-config

A portable Claude Code setup: the same agents, commands, skills and safety hooks on
every machine you work on, installed with one command.

- **Want to see it in action first?** The worked example in
  [project-template](https://github.com/rickyb30/project-template/blob/main/examples/README.md)
  follows one small job from idea to reviewed code.
- This repository is generic. It holds no project knowledge and nothing from any
  employer or client. See [docs/PUBLIC-SAFETY.md](docs/PUBLIC-SAFETY.md).

## What this gives you

**The same setup everywhere.** Your personal machine and your office machine run
identical agents and rules. You configure a machine once and stop re-explaining how
you like to work.

**Problems found before code is written.** A researcher agent challenges your design
and must separate what it verified from what it merely thinks. Finding a flaw at this
point costs a paragraph. Finding it after the build costs the build.

**A second opinion that is actually independent.** The reviewer agent sees the plan
and the diff, never the implementer's account of its own work, so it cannot be talked
into agreeing.

**You stay in charge of the two decisions that matter.** Nothing is built until you
have approved the design and then the plan. These are enforced by hooks on tool calls,
so an agent cannot argue or drift its way past them.

**Agents cannot change a live environment.** Shell commands that apply infrastructure,
deploy, delete cloud resources or write to a warehouse are blocked unless a project
explicitly allows them. Planning and reading are still allowed.

**Secrets and employer details stay out of commits.** Every write and every commit is
scanned for credentials, and commits to public repositories are checked against a
private list of names and domains.

**Each project remembers what it learned.** Lessons from reviews go into that
project's own `docs/knowledge/`, and the agents read the index before the next piece
of work. Nothing crosses between projects unless you move it by hand.

**Repeatable, not remembered.** Each stage is a slash command, so the process is the
same on the tenth run as on the first.

### What it costs

- **Tokens.** Four agents each read the context afresh, so a change run through the
  whole pipeline costs several times a single session.
- **Ceremony.** A design document, two approvals and a review are too much for a typo.
  Use the pipeline for work where building the wrong thing would hurt.
- **It is unproven on your work.** The scripts and hooks are tested; the pipeline has
  not yet been run end to end on a real project. Expect to adjust it after the first.

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

Run `bootstrap.sh` once per machine, and again after each update. It is safe to
re-run, and it backs up anything it replaces. Details: [docs/SETUP.md](docs/SETUP.md).

## Use it in a project

**New project:** create it from
[project-template](https://github.com/rickyb30/project-template), which sets up
everything below.

**Existing project:** run the setup script from a terminal in the project. It
detects the folders that look like source, asks you to confirm, and writes
`.claude/pipeline.json` and the `docs/` folders.

```bash
~/code/agent-config/scripts/init-project.sh
```

Then, in Claude Code:

| Step | You type | Result |
| --- | --- | --- |
| Talk the design through, then write it up | `/rb-design <name>` | `docs/architecture/001-name.md` (draft) |
| Check it is complete | `/rb-intake <design>` | a gap report |
| Have it challenged | `/rb-research <design>` | `docs/research/001-assessment.md` |
| **Gate 1** | you set `status: approved` in the design | |
| Turn it into a plan | `/rb-draft-plan <design>` | `docs/plans/001-name.md` |
| **Gate 2** | you set `status: approved` in the plan | |
| Build one milestone | `/rb-implement <plan> [M1]` | code, tests, a log entry |
| Review independently | `/rb-review-diff` | `docs/reviews/001-review.md` |
| Record a lesson | `/rb-lesson <text>` | a proposal in `docs/knowledge/inbox/` |

In projects without `.claude/pipeline.json` the approval gate is off and Claude Code
behaves as usual, apart from the secret scan and the block on commands that change a
live environment.

Full reference: [docs/PIPELINE.md](docs/PIPELINE.md).

## What is in here

| Part | What it is |
| --- | --- |
| 4 agents | researcher, planner, implementer, reviewer; each can write only to its own folder |
| 7 commands | `/rb-design`, `/rb-intake`, `/rb-research`, `/rb-draft-plan`, `/rb-implement`, `/rb-review-diff`, `/rb-lesson` |
| 8 skills | shared templates and checklists: intake sections, assessment, plan format, review rubric, infrastructure and data review, decision records, knowledge lookup and proposal |
| 5 hooks | approval gate, per-agent path guard, deploy guard, secret scan, denylist scan |
| 4 scripts | `bootstrap.sh` (install), `doctor.sh` (check a machine), `init-project.sh` (set up an existing project), `validate.sh` (lint and test this repository) |

```
claude/            everything that is linked into ~/.claude
  CLAUDE.md        working style and pipeline rules
  settings.base.json
  agents/  commands/  skills/  hooks/
scripts/           bootstrap.sh  doctor.sh  init-project.sh  validate.sh  lib/
tests/             run.sh
docs/              SETUP.md  PIPELINE.md  PUBLIC-SAFETY.md
```

## Limits worth knowing

The gates stop an agent drifting past a decision; they are not a sandbox. An agent
with shell access can still change files through a shell command, and the deploy
guard reads command text only. The control that truly holds for cloud work is giving
agents read-only credentials. [docs/PIPELINE.md](docs/PIPELINE.md) lists the limits.

## Change this repository

```bash
scripts/validate.sh --strict    # lint, shell checks, secret and denylist scans, tests
```

Tag a release as `vMAJOR.MINOR.PATCH` once CI is green. Pinned machines move only by
`scripts/bootstrap.sh --ref <tag>` after you have read the diff between tags.
