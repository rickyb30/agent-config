---
description: Break an approved design doc into implementation phases in docs/plans/.
argument-hint: <docs/architecture/NNN-name.md>
disable-model-invocation: true
---

Break this design into implementation phases: $ARGUMENTS

1. If no path was given, list `docs/architecture/` and ask which design.
2. Read the design's front matter. If `status` is not `approved`, stop and say:
   "Not approved yet: set `status: approved` in <path> yourself, then run this again."
   Do not offer to change it.
3. The output is `docs/plans/NNN-name.md`, with the same `NNN-name` as the design. If
   it already exists, ask whether to replace it.
4. Read the design and the project `CLAUDE.md`. Look at the repository only as far as
   you need to name the files each phase touches.
5. Write the plan in this shape:

   ```markdown
   ---
   design: docs/architecture/NNN-name.md
   date: <today>
   ---

   # Phases: <title>

   ## Phase 1: <what works at the end, not an activity>
   - Build: what is built.
   - Files: the files or folders it touches.
   - Done when: checks a person can run or see.
   - [ ] done

   ## Phase 2: ...

   ## Questions
   ```

6. Rules:
   - Usually two to five phases. One phase is fine for a small project.
   - Each phase leaves the project working, and the first tackles the riskiest part.
   - Nothing beyond the design. Anything missing or unclear goes under Questions;
     leave that section out when there are none.
   - Mark any step that changes a live environment (apply, deploy, warehouse write)
     with "(you run this)": agents do not run those.
7. Print the phase titles and any questions, then stop. The next step is
   `/rb-implement docs/plans/NNN-name.md`.
