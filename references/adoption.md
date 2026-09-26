# Adopting the skill in a new package

## Contents

- [1. Scaffold](#1-scaffold)
- [2. Add the delegation standing request](#2-add-the-delegation-standing-request)
- [3. Derive every field. Do not infer any of them.](#3-derive-every-field-do-not-infer-any-of-them)
- [4. Mark what you could not derive](#4-mark-what-you-could-not-derive)
- [5. Confirm the filled profile with the maintainer](#5-confirm-the-filled-profile-with-the-maintainer)
- [6. Verify by running, before the first cycle](#6-verify-by-running-before-the-first-cycle)
- [Generated / literate packages](#generated--literate-packages)

---

For a package starting from zero — no existing workflow docs. The whole job is producing an
accurate `.workflow/PROFILE.md`, because **every serious failure in this workflow's history
traces to a profile that was wrong**, not to the process:

- a Public API list typed from memory omitted two exported functions, and the omission
  propagated into a plan that would have shipped inconsistent documentation;
- a suite timing that was stale by 5× produced a two-hour mutation-battery run;
- a "several minutes" build estimate was wrong in the other direction, discouraging work that
  actually took ninety seconds.

Budget your effort accordingly: the cycle is self-correcting, the profile is not.

## 1. Scaffold

From the package's repo root:

```bash
bash <skill-root>/scripts/bootstrap-repo.sh
```

`<skill-root>` is the absolute path of the directory holding the skill's `SKILL.md`; resolve it
once and use it in every command here. The script creates `.workflow/` and `.plans/`, copies in
`templates/PROFILE.md`, and adds the gitignore entries. Idempotent; never overwrites an
existing profile.

It modifies tracked `.gitignore`, and `.Rbuildignore` as well **when a `DESCRIPTION` sits at
the repo root** — the repo-root guard also accepts `build.R` or `R/`, so a package generated
from a source document passes the guard, has no root `DESCRIPTION`, and gets the gitignore
lines only. Land whichever it wrote yourself in a small commit before starting feature work —
the agent is forbidden from committing to the default branch.

## 2. Add the delegation standing request

A harness bug can silently turn every subagent check in this workflow into self-review — plan
review, both sentinel passes, delegated implementation, post-execution review, all run inline
in the orchestrator's own context, which agrees with itself. The symptom is an agent that
reports a standing instruction not to spawn subagents and then does every stage itself.

The repair lives in the repo rather than in the skill: a standing request in the repo's
`AGENTS.md` or `CLAUDE.md`. **Its exact phrasing is what makes it work or not**, so take it
from [harness-notes.md](harness-notes.md#known-harness-bugs--dated-verify-before-acting),
which owns the mechanism, the dates, the wording that survives, and an optional
`UserPromptSubmit` hook that delivers the same text on every turn.

**Do not re-invent the wording.** `scripts/delegation-standing-request.sh` already carries a
phrasing that works — lift the request text out of it and adapt it to the entry point. Every
repo running this skill has one, so a repo without one is running a different workflow than
this document describes.

**Whether that file is tracked is the repo's choice, so check the `.gitignore` rather than
assume.** Tracked is the default, and then it goes into the same small commit as step 1's
ignore lines — the agent may not put it on the default branch itself. Both repos this skill was
distilled from chose the other model instead, ignoring `AGENTS.md` in one and `/CLAUDE.md` in
the other, because the file points at the gitignored `.workflow/`. Then there is nothing to
commit — and nothing to restore either: the standing request lives on one machine, and no
clone, no collaborator, and no new checkout gets it.

## 3. Derive every field. Do not infer any of them.

**Run the command; paste the answer.** A field you reasoned out is a prediction, and
[predictions are wrong far more often than repository facts](lessons.md#33).

| Profile field | The command that produces the truth |
|---|---|
| **Public API** (§ 8) | `Rscript -e 'devtools::load_all(quiet=TRUE); print(sort(getNamespaceExports("<pkg>")))'` — or `grep "^export" NAMESPACE` for a generated package. **Never type this list.** |
| **S3 methods** | `grep "^S3method" NAMESPACE` |
| **Object system(s)** (§ 9) | the detectors in the fenced block that follows this table; **not** inline here, because a `\|` inside a table cell is a literal pipe to anything reading the raw file |
| **testthat edition** | `grep "Config/testthat/edition" DESCRIPTION` — **absent means edition 2** — see `cran-gate.md`, search it for `Config/testthat/edition`; the edition changes red-side *counts* as well as tolerances |
| **Formatter** (§ 9) | `ls air.toml .air.toml 2>/dev/null`; `grep -rl styler .github/ Makefile 2>/dev/null`. Neither → `none`, and the agent will match surrounding style rather than introduce one |
| **Version lives in** (§ 4) | `grep -n "^Version:" DESCRIPTION` — or grep the source document for a generated package, and record the line as drifting |
| **`NEWS.md`** | Does it exist at all? If not, acceptance criterion 7 is inapplicable — say so rather than letting it be silently skipped |
| **`inst/CITATION`** | Does it exist, and does it hard-code a version? `grep -n version inst/CITATION`. No version string → criterion 8 is inapplicable |
| **Dependencies** (§ 10) | `sed -n '/^Imports:/,/^[A-Z]/p' DESCRIPTION`, same for `Suggests:`. Copy verbatim — a stale list disarms the reviewer's unguarded-`Suggests:` check |
| **Governance** (§ 1) | `cat CONTRIBUTING.md 2>/dev/null`; `gh api repos/:owner/:repo/branches/main/protection`. When unsure, leave the conservative default |
| **CI** (§ 1) | `ls .github/workflows/`. A workflow that only deploys a site is **not** a checking gate — say which it is. Then `grep -n "error-on" .github/workflows/*.y*ml`: absent or `"warning"` means CI is a weaker bar than the local gate, and the profile says so rather than implying parity |
| **Method-entry preconditions** (§ 9) | `grep -rl "\.check_for_" R/`. None → the sentinel's Check 2 runs in NOTE mode |
| **Timings** (§ 2) | `time` the suite and the check. **Measure. Never estimate. Date the measurement.** |

The object-system detectors, kept out of the table because table-cell escaping breaks the
alternation for a raw-markdown reader:

```bash
grep -rlE 'setClass|setGeneric'        R/   # any hit → S4
grep -rl  'R6Class'                    R/   # any hit → R6
grep -rlE 'new_class|new_generic|S7::' R/   # any hit → S7
# none of the above → S3
```

A package can use more than one; record every hit, not the first. **An empty result here is
the same trap the gate warns about** — it is indistinguishable from "the grep was wrong", and
it defaults the profile to S3, which silently switches the reviewer onto the wrong checks.

**Several fields change what the agent does**, not just what it knows — Governance, CI, Object
system(s), Formatter, and Method-entry preconditions. Get those right and the rest is
descriptive.

### What "good" looks like, per field

Fragments to convey register, not content:

    § 8   17 exports (derived — `grep "^export" NAMESPACE`), listed by name.
          Note what is NOT exported: the three helpers named in older notes are
          internal, and read like API to anyone who hasn't checked.

    § 12  2. `expect_error` on a message you changed halts the build rather than
          failing a test, and surfaces as an unrelated missing-directory error.
          Fix: when you change a user-visible condition, grep the tests for the
          old assertion in the same edit.

Short, specific, and each earns its place by being expensive to re-derive.

## 4. Mark what you could not derive

Some fields have no command — the gotchas especially. Anything you wrote from reading rather
than running gets said so, in the file:

> *(Inherited from the repo's prose and **not independently reproduced** — treat as reported,
> not measured.)*

This is [lesson 33](lessons.md#33) applied to the profile. It costs one clause and it tells
the next reader which claims to trust. It is also the annotation that would have caught, a
week earlier, both of the litr claims this skill later had to correct.

## 5. Confirm the filled profile with the maintainer

The agent gets commands and layout right and **guesses at conventions**. Error style, naming,
where a new helper belongs, what counts as a user-visible change — those are decisions, not
facts, and the maintainer owns them.

## 6. Verify by running, before the first cycle

A profile assembled by reading is a set of predictions until something executes it. Before
running a real PR cycle, do one throwaway pass:

- **Run the full gate once, and if it is not clean, cleaning it is your first PR.** Not a
  reason to weaken the criteria — the bars are in [cran-gate.md](cran-gate.md) § "Expected
  results and triage", which owns them, and every cycle after this one is measured against
  them. A package that starts dirty and stays dirty makes criteria 1–3 unfalsifiable forever:
  they fail on the base tree, so they can never fail *because of* a change, and they read as
  verification anyway.

  This is a good first cycle, not a chore. `spell_check()` on a package with no
  `inst/WORDLIST` routinely returns dozens of words, and triaging them surfaces genuine
  documentation errors. `url_check()` finds citations that have rotted. NOTEs are frequently
  real bugs: `no visible binding for global variable` is an unqualified name that will fail
  at runtime on some path.

  **What survives that effort gets recorded, with the reason and the date**, in the profile's
  § 3 — an installed size you cannot shrink, a publisher that 403s `urlchecker`'s HEAD
  requests (`doi.org` does this), the `unable to verify current time` environmental flake.
  From then on the criterion is *that accepted exceptions list and nothing new*, which is
  falsifiable again. Anything not on the list is a finding.
- **Time the slow steps and record the figures, dated.**
- **Confirm the tree is restorable.** For a generated package the build rewrites tracked
  files; know what dirties and how to restore it before you need to.

**Then run `Rscript <skill-root>/scripts/check-profile.R .workflow/PROFILE.md`.** It derives
what a profile must contain from the template and fails on a section or a named field that is
missing, empty, or still holding a placeholder — including the fields the gate criteria address
by name, which two independently-derived profiles both omitted. Its advisory block needs your
judgement; its failures do not.

---

## Generated / literate packages

If the package is built from a source document rather than edited directly in `R/`, the build
model changes the process and not just the commands — no fast loop, a green build that is
itself a test result, a generated tree you must never hand-edit, and a build-abort symptom
that points at the wrong file. **See [guides/litr.md](../guides/litr.md)** before filling in
§§ 2, 3, and 12.
