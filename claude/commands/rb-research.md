---
description: Run the architecture-researcher on an architecture document and write an assessment to docs/research/.
argument-hint: <docs/architecture/NNN-name.md>
disable-model-invocation: true
---

Run the research stage on: $ARGUMENTS

1. If no path was given, list `docs/architecture/` and ask which document.
2. Read only the document's front matter. If `status` is `approved`, say that research
   normally happens before approval and ask whether to continue.
3. Delegate to the `architecture-researcher` subagent. Give it the document path and
   nothing else: no opinion of the design, no hints about what to conclude.
4. When it returns, confirm that `docs/research/NNN-assessment.md` exists.
5. If the architecture's `status` is `draft`, set it to `challenged`. Change nothing
   else in the document.
6. Report the assessment path and the researcher's summary, then stop.

The next step is the human's: revise the design, then set `status: approved` by hand.
Never set `approved` yourself.
