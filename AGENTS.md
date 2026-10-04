# AGENTS.md

Entry point for harnesses that read a repo-root agent file.
**This file is a pointer, not a copy.**

## Read this first

**[`SKILL.md`](SKILL.md)** is the real entry point: who this is for, the cycle, the
non-negotiables, and the routing table for everything in
[`references/`](references/). Read it now, before doing anything else.

Then, if you are working inside an R package:

1. **`.workflow/PROFILE.md`** in that package — its build and gate commands, conventions,
   dependencies, and gotchas. Several of its fields *switch* what the process does. If it is
   missing, `SKILL.md` says how to create it.
2. **[`references/harness-notes.md`](references/harness-notes.md)** — how to spawn subagents
   in your harness, and why absolute paths in every brief are non-negotiable.

## What this is

A development process for **statistical and numerical R packages** — the kind implementing
an estimator, a model, or an algorithm against a documented methodology, where a wrong answer
looks exactly like a right answer: nothing crashes, no type check fails, and often the test
that should have caught it came from the same derivation as the bug.

## Working on the skill itself

If you are editing *this repo* rather than using it: process content belongs in `references/`
so it exists once. Anything harness-specific goes in `references/harness-notes.md`.

Before you finish, run `Rscript scripts/check-docs.R` and `Rscript scripts/check-briefs.R`,
plus `Rscript scripts/check-fields.R` if you touched an instruction or
`templates/PROFILE.md`. What each list in their output obliges you to do is in
[`CONTRIBUTING.md`](CONTRIBUTING.md).

Before proposing a change to the skill, check [`CONSIDERED.md`](CONSIDERED.md) for it.

Commit as you go. Push, change the repo's settings, or do anything else outward-facing only
when the maintainer asks. The maintainer also edits files on GitHub's website, so fetch and
check `git status -sb` before you edit or push.

If a `LOCAL.md` exists at the repo root, read it. It is gitignored, and it records facts about
this machine's install, such as where the skill is installed and which installed files are
copies.

Don't keep instructions or facts about this skill in an agent's memory feature. What an agent
needs to use the skill belongs in `SKILL.md` and `references/`, what it needs to edit the skill
belongs in this file or `CONTRIBUTING.md`, and what is specific to one machine belongs in
`LOCAL.md`.
