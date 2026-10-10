---
description: Check that an architecture document has every required section. Reports gaps, rewrites nothing.
argument-hint: <docs/architecture/NNN-name.md>
disable-model-invocation: true
---

Run intake on the architecture document: $ARGUMENTS

1. If no path was given, list the files in `docs/architecture/` and ask which one.
2. Load the `architecture-intake` skill and check the document against it.
3. Print the intake report in the format the skill defines.

Do not edit the document, do not write any file, and do not suggest wording for the
missing sections unless asked.
