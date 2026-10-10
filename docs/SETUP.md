# Setup

## Requirements

`bash` (3.2 or newer), `git`, `jq`, `gitleaks`, `python3`. `shellcheck` is needed only
for `scripts/validate.sh --strict`. `scripts/doctor.sh` prints the install command for
anything missing.

## Personal machine (macOS): track main

```bash
git clone https://github.com/rickyb30/agent-config.git ~/code/agent-config
cd ~/code/agent-config
scripts/bootstrap.sh
scripts/doctor.sh
```

Update with `git pull` followed by `scripts/bootstrap.sh`.

## Office machine (Ubuntu on WSL): pin a tag

Before first use, confirm that your employer's policy allows cloning from public
GitHub and running third-party shell scripts. The hooks here are shell scripts that
run on every tool call, so treat them as code to review.

```bash
# Inside the Linux filesystem. Never under /mnt/c: bootstrap refuses to run there.
git clone https://github.com/rickyb30/agent-config.git ~/code/agent-config
cd ~/code/agent-config
scripts/bootstrap.sh --ref v0.1.0
scripts/doctor.sh               # reports the pinned tag
```

To update, review first, then move the pin:

```bash
git fetch --tags
git diff v0.1.0 v0.2.0          # read all of it, hooks and scripts especially
scripts/bootstrap.sh --ref v0.2.0
```

Never track `main` on the office machine.

## What bootstrap does

| Path | Action |
| --- | --- |
| `~/.claude/CLAUDE.md` | symlink to `claude/CLAUDE.md` |
| `~/.claude/{agents,skills,commands,hooks}/<entry>` | one symlink per entry shipped here; other files in those folders are left alone |
| `~/.claude/settings.json` | generated: `settings.base.json` merged with `settings.local.json` |
| `~/.config/agent-config/settings.local.json` | created once, seeded from your existing `settings.json` |
| `~/.config/agent-config/denylist.txt` | template created once; you add the terms |
| this checkout | `core.hooksPath=.githooks` so commits here are scanned |

Anything bootstrap would replace is first moved to
`~/.claude/backups/agent-config/<timestamp>/`. Running it again changes nothing.
`--dry-run` prints what would change.

`~/.claude` itself is never committed anywhere.

## Machine-specific settings

`~/.claude/settings.json` is generated, so edits made there (including changes Claude
Code writes when you use `/config`) are replaced on the next bootstrap, after being
backed up. Put machine-specific settings in `~/.config/agent-config/settings.local.json`
and re-run bootstrap. Objects merge, lists are combined, and for single values the
local file wins.

## The denylist

`~/.config/agent-config/denylist.txt` lists terms that must never be committed to a
public repository: employer and client names, internal domains, work emails, usernames,
absolute home paths. One term per line, case-insensitive. It exists only on the machine;
committing it would leak the terms. Commits in this checkout are blocked while the file
is missing.

## Uninstall

Remove the symlinks under `~/.claude` that point into this checkout, then restore what
you need from `~/.claude/backups/agent-config/`.

## Portability rules for scripts

- Target bash 3.2: no associative arrays, no `readarray` or `mapfile`.
- No GNU-only flags. Use `realpath_p` and `sed_inplace` from `scripts/lib/portable.sh`
  in place of `readlink -f` and `sed -i`; avoid `date -d`.
- `.gitattributes` forces LF line endings so an editor on Windows cannot break a hook.
- Hooks depend only on `bash`, `git`, `jq` and `gitleaks`.

`scripts/validate.sh` checks these.

## Releases

1. `scripts/validate.sh --strict` passes locally and in CI on `main`.
2. Update `VERSION`, commit, tag `vMAJOR.MINOR.PATCH`, push the tag.
3. Pinned machines move only by `scripts/bootstrap.sh --ref <tag>` after a diff review.
