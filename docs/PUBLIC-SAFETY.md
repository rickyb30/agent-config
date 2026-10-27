# Public-repository safety

This repository is public. Nothing derived from an employer's or a client's work may
enter it: no names, no systems, no domains, no data, no lessons that only make sense
with inside knowledge.

These rules are written down so they hold when attention lapses.

## Rules

1. **Generic only.** Agents, skills, commands and hooks describe a process, never a
   project. Project facts live in each private project repository.
2. **Fictional examples only.** Every sample system, table, hostname and person is
   invented. A realistic example modelled on real work is a leak even when the names
   are changed, so invent the scenario too. Use `example.com` and the reserved
   `.example` domain.
3. **No secrets.** gitleaks runs before each commit and in CI.
4. **No denylisted terms.** `denylist-scan` runs before each commit against the
   machine-local `~/.config/agent-config/denylist.txt`.
5. **The denylist is never committed**, here or anywhere. The list of terms is itself
   sensitive. CI therefore cannot run your denylist; it runs a fixture of fictional
   terms to prove the scanner works. The real check happens on your machine, which is
   why a commit is blocked when the file is missing.
6. **No machine details.** No usernames, home paths, hostnames or email addresses.

## Before the first commit on a machine

Add to `~/.config/agent-config/denylist.txt`:

- employer and client names, including abbreviations and former names;
- internal domains and hostnames;
- work email addresses and usernames;
- absolute home paths on that machine;
- project code names.

`scripts/doctor.sh` warns while the file is empty.

## Promoting a lesson from a project

This is the only way anything moves from a project into this repository, and it is
manual.

1. Start from a lesson that has proved itself in a project.
2. Rewrite it from scratch as a general rule. Do not copy and edit; copying carries
   detail along.
3. Remove every project, employer, system and person reference, and replace the
   example with a fictional one.
4. Place it as a line in `claude/CLAUDE.md`, a checklist item in a skill, or a new skill.
5. Commit from a machine whose denylist covers the source project. The pre-commit
   scans run on the way in.
6. Read the diff once more as an outsider: could a reader tell where this came from?
