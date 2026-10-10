# agent-config

Portable Claude Code configuration: four pipeline agents, the skills and commands they
share, and the hooks that enforce two human approval gates. One bash toolchain serves
macOS and Ubuntu on WSL.

This repository is public and generic. It contains no project knowledge. See
[docs/PUBLIC-SAFETY.md](docs/PUBLIC-SAFETY.md) before contributing anything.

## Install

```bash
git clone https://github.com/rickyb30/agent-config.git ~/code/agent-config
cd ~/code/agent-config
scripts/bootstrap.sh            # or: scripts/bootstrap.sh --ref v0.1.0
scripts/doctor.sh
```

- [docs/SETUP.md](docs/SETUP.md): machine setup, pinning, updating, uninstalling.
- [docs/PIPELINE.md](docs/PIPELINE.md): the stages, the gates, and how a project opts in.
- [docs/PUBLIC-SAFETY.md](docs/PUBLIC-SAFETY.md): what may never enter this repository.

## Layout

```
claude/            everything that is linked into ~/.claude
  CLAUDE.md        working style and pipeline rules
  settings.base.json
  agents/  commands/  skills/  hooks/
scripts/           bootstrap.sh  validate.sh  doctor.sh  lib/
tests/             run.sh (hooks, denylist fixture, bootstrap idempotency)
docs/
```

## Develop

```bash
scripts/validate.sh             # lint, shell checks, scans, tests
scripts/validate.sh --strict    # what CI runs: missing tools are failures
```
