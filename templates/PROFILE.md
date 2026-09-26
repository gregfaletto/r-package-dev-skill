# PROFILE — <repo name>

## Contents

- [1. Identity](#1-identity)
- [2. Build model](#2-build-model)
- [3. The gate — exact commands](#3-the-gate--exact-commands)
- [4. Version bookkeeping](#4-version-bookkeeping)
- [5. Distribution](#5-distribution)
- [6. Authority](#6-authority)
- [7. Repo layout at a glance](#7-repo-layout-at-a-glance)
- [8. Public API](#8-public-api)
- [9. Conventions](#9-conventions)
- [10. Dependencies](#10-dependencies)
- [11. Smoke snippet](#11-smoke-snippet)
- [12. Gotchas that WILL bite](#12-gotchas-that-will-bite)
- [13. Other local docs](#13-other-local-docs)

---

**This file is the repo's half of the contract with the `r-package-dev` skill.** The skill
carries the *process*; this file carries this repo's *facts*. Keep it thin — if something is
true of R packages generally, it belongs in the skill, not here.

Several fields below don't just describe the repo, they **switch parts of the process**:
`Governance`, `CI`, `Object system(s)`, `Formatter`, and `Method-entry preconditions` each
change what the skill and its subagents do. Those are marked **[switch]**.

Local-only: gitignored and `.Rbuildignore`d, like `.workflow/` and `.plans/`. Not shipped to
CRAN, not tracked in git.

Keep it in a **single present-tense state**. No dated "refreshed YYYY-MM-DD" sections.

> **These quoted blocks are notes to whoever fills this in, not part of the finished profile**
> — likewise a parenthetical note standing alone under a heading. Delete each once the section
> it governs is written. A parenthetical sitting on a field's own line is not one of these: it
> is that field's value hint, and what replaces it is the value. Nothing enforces that, and
> nothing enforces keeping them: guidance is the one part of this template `check-profile.R`
> derives no requirement from, so it is the one part that can go without a word. Deleting it
> loses nothing, because the rules live in the skill — the gate boundary in `cran-gate.md`, the
> ranking in the acceptance criteria — which is where an agent editing this file mid-cycle
> actually reads them.

> **A fact about your machine is not a fact about the repo** — a stale binary, a missing
> subcommand, an unlicensed compiler. Filed here, those are wrong for CI, for a collaborator,
> and for a fresh clone, and no cycle corrects them, because nothing about the repo changes
> when your laptop does. A toolchain fact goes where the toolchain is used, as a check with a
> fallback (`run X; if it errors, do Y`) or as an escalation when it needs a human — the way
> the skill's `cran-gate.md` puts the failing compiler probe at the gate rather than in
> anyone's profile.

> **A rule about what a gate command's output means is not a fact about this repo** — a § 3
> that explains what a NOTE means, which URL statuses are tolerable, when a spell-check flag
> is a typo and when it belongs in the wordlist. The skill's `cran-gate.md` § "Expected
> results and triage" owns those bars and is what gets corrected when one of them is wrong.
> A copy here is worse than ordinary duplication, because this file is gitignored and
> unversioned: a bar that goes wrong in it cannot be found by anyone, has no history to
> bisect, and never receives that correction. Nothing detects the copy, either. What § 3
> owes is this package's own measurements — its recorded exceptions, its own URLs and their
> statuses, the flags its build model makes mandatory. The boundary is explanation of a bar
> versus measurement of this package.

---

## 1. Identity

- **Package:** `<name>` — one sentence on what it does.
- **Maintainer:** `<github-handle>`.
- **Default branch:** `main` / `master` / `devel`.
- **Repo:** <https://github.com/…>

### Governance **[switch]**

Pick one. This determines what the agent is allowed to do at the end of a cycle.

- **`solo-maintainer-reviews`** *(the skill's default)* — one maintainer owns `main` and owns
  merges. The agent branches, implements, gates, opens the PR, and **hands off at "ready to
  merge."** It never commits to `main` and never merges. No fork; push branches directly to
  `origin`. No "request review from."
- **`solo-self-merge`** — a single developer who is also the reviewer. The agent still
  branches and opens a PR (for the diff and the revert point), but **may merge once the gate
  and reviews are green**, unless told otherwise for a given change.
- **`team`** — multiple maintainers with review requirements. The agent opens the PR,
  requests review per the repo's convention, and **waits for human approval**. Branch
  protection rules are authoritative over anything in the skill.
- **`outside-contributor`** — the agent has no write access to the upstream repo. **Work on a
  fork**, push there, and open a cross-repo PR. Follow `CONTRIBUTING.md` if present; it
  outranks the skill.

*(The skill is currently best-tested on `solo-maintainer-reviews`. See its Scope and
limitations section.)*

### CI **[switch]**

- **`none`** — no CI. The local gate is the only gate.
- **`advisory`** — CI exists but does not block merge. Report failures; don't hold on them.
- **`gating`** — CI must be green before handoff or merge.

If not `none`, record:

- **Workflows:** `<paths under .github/workflows/>`
- **Matrix:** `<the actual job list, not a shorthand>` — os × R version, read off the workflow
  file rather than named by the generator that wrote it. What a stock
  `use_github_action("check-standard")` expands to is in the skill's `cran-gate.md` § "If the
  repo has no CI and it should", which is where that fact stays current.
- **Check strictness:** the `error-on` the workflow passes. Absent or `"warning"` means CI is a
  weaker bar than the local `error_on = "note"` gate — say so rather than implying parity.
- **Status command:** `gh pr checks <n> --watch` *(or the repo's equivalent)*
- **Known-flaky jobs:** *(any job that fails for reasons unrelated to the change)*

## 2. Build model

Pick one and delete the other.

**Plain devtools package.** Source lives in `R/`; `man/` and `NAMESPACE` are
roxygen-generated. Fast loop:

    devtools::load_all()  →  devtools::test(filter = "…")  →  devtools::test()

**Timings — measure them, and date the measurement.** `<filtered: …s; full test(): …; check():
…>`, measured `<YYYY-MM-DD>`. A suite grows and the figure rots silently, so anything that
runs the suite repeatedly — a mutation battery, a bisect, a before/after sweep — must be
budgeted against a *current* measurement, not this line as written months ago.

**Generated / literate package (litr or similar).** The single source of truth is
`<source>.Rmd`; the package tree `<pkg>/**` and the site `docs/**` are **generated — never
hand-edit them**, your edit is overwritten on the next build. Tests are woven into the source
too. Build with:

    <command>          # give it a ~N-minute timeout; it deletes <pkg>/ first

**A green build means every woven test passed** — the renderer executes each test chunk.
Before each run, clear the intermediates: `rm -rf <intermediates>`.

## 3. The gate — exact commands

From a shell at the repo root:

    <formatter command>

Then from an R session at the repo root:

    <document command>
    <test command>
    <check command>          # required
    <spell-check command>    # required
    <url-check command>      # required

**Every command above is required, and what counts as a clean result for each is not this
file's to define** — that standard, and the triage when one is not clean, is the skill's
`cran-gate.md` § "Expected results and triage", where it is maintained. What this file
records is the other half: which commands this repo actually runs, and this repo's own
measured baseline — the recorded exceptions and the WARN/SKIP counts below. Those are facts
about this package, held nowhere else and unrecoverable once deleted: the distinction is a
general bar there versus a per-repo baseline here, and a pass that prunes bar-setting prose
from this file leaves the baseline standing.

**Recorded baseline exceptions.** This field is **the accepted exceptions list** — the name
the skill's gate criteria use for it, so a grep for either term lands here. The gate
`cran-gate.md` defines is 0/0/0 and clean, and what this field records is what stands as an
exception to it. Anything that survived the adoption clean-up is listed here by name, with
why it cannot be fixed and the date it was last confirmed — and *only* these are permitted.
Anything not on this list is a finding. That includes output a gate command prints without
failing — an environmental NOTE, a `spell_check()` advisory, a redirect status from the URL
probe: report it, and it is a finding until the maintainer's explicit permission puts it
here by name, because there is nowhere else for it to live. Delete the examples; an empty
list is the goal and a common, correct answer.

    <none>
    # e.g. NOTE  installed size 12.4Mb -- reference data, cannot shrink (2026-01-14)
    # e.g. url_check  https://doi.org/10.xxxx/yyy -- publisher 403s HEAD requests (2026-01-14)
    # e.g. spell_check  Defaulting to 'en-US' -- DESCRIPTION has no Language field (2026-01-14)

**Test-suite baseline counts.** These are the accepted exceptions list for the `[ FAIL … ]`
summary line; criterion 5 quotes them, and any new warning or skip is a finding. Record
`SKIP` under the **check** command as well as the test command — a block can skip under one
and not the other. Zero and zero is the goal and a common, correct answer.

    WARN  <n>
    SKIP  <n> under <test command>, <n> under <check command>

Note any mandatory flags and *why*. For example: a litr package must pass `document = FALSE`
to `check`, because a plain check rewrites every man-page header and corrupts the diff.

## 4. Version bookkeeping

- **Version lives in:** `DESCRIPTION`'s `Version:` — or, for a literate package, the
  `Version = "..."` field in `<source>.Rmd` (grep it; the line drifts).
- **Other files that must match:** `NEWS.md` top header, `inst/CITATION`'s
  `note = "R package version X.Y.Z"`, `codemeta.json`. **State explicitly if the repo has
  none of these** — the skill's acceptance criteria are conditional on their existence.
- **Development version:** does the repo sit on `x.y.z.9000` between releases, with a single
  `# <pkg> <version> (development version)` header in `NEWS.md`? *(What the skill assumes. R's
  news parser drops a header carrying no version, so its bullets never reach the news database
  and a file with no other version header draws a `No news entries found` NOTE. If this repo
  instead bumps the release version on every PR, say so — it changes acceptance criterion 7.)*
- **Release bump policy:** patch for bug fixes and minor enhancements; minor for new exports
  or behavior changes; major reserved for the maintainer. Applied **at submission time**.

## 5. Distribution

- **Channel:** CRAN / Bioconductor / GitHub-only / internal.
- **If CRAN:** every PR's compatibility with `R CMD check --as-cran` is a first-class concern,
  and release prep is a *state* (see the skill's lesson 24).
- **If Bioconductor:** note the `devel` / `RELEASE_x_y` branch model, `BiocCheck::BiocCheck()`
  as an additional gate, and the 6-month release cycle. *(The skill's gate and release
  guidance are written for CRAN — see its Scope and limitations.)*
- **If GitHub-only or internal:** say which of the CRAN-flavored acceptance criteria do not
  apply, so they aren't enforced pointlessly.

## 6. Authority

- **Methodology / spec authority:** `<path>` — *when code and this document disagree, this
  document wins.* Any change to the domain math must cite the equation, lemma, or section it
  implements, in the PR description or a code comment — the comment form being a line that
  cites, not a paragraph restating it. *(Delete if there is no external authority document.)*
- **Reference implementations users will have seen:** `<pkg>`, `<pkg>` — API conventions
  should not deviate without a reason.

## 7. Repo layout at a glance

- **`R/`** — one file per logical unit. *(Name the important groupings: entry points,
  numerical cores, shared machinery, class/method files, simulation helpers.)*
- **`tests/`** — framework and layout. *(testthat is assumed by the skill; if this repo uses
  tinytest, RUnit, or bare scripts, say so and give the run command.)*
- **`vignettes/`**, **`man/`** (generated — never hand-edit), **`inst/WORDLIST`**.
- *(Anything unusual: a generated tree, a build script, compiled `src/`, `renv`.)*

## 8. Public API

The exported surface: `fn()`, `fn()`, … Adding to it is a one-way door — a new export needs a
plan-level decision.

**Derive this list; do not type it from memory.** A hand-written list drifts, and the drift is
invisible until a plan scoped to "every exported door" quietly misses one:

    Rscript -e 'devtools::load_all(quiet=TRUE); print(sort(getNamespaceExports("<pkg>")))'

`*Core()`-style functions are the usual casualty — exported, carrying live man pages, and
often the function that does the work the public wrapper only forwards.

## 9. Conventions

### Object system(s) **[switch]**

Which of `S3`, `S4`, `R6`, `S7` the package uses, and where each applies — e.g. "S3
throughout; R6 only for the connection handle in `R/pool.R`." This selects the dispatch,
export, validator, and documentation checks the reviewer and sentinel apply. **If the package
uses more than one, say which files use which**, so a reviewer doesn't apply S3 rules to an
S4 file.

### Formatter **[switch]**

- **Tool:** `air` / `styler` / `none`.
- **Config:** `<air.toml at root | .styler settings | none>`.
- **Indentation:** `<tabs, width 4 | 2 spaces | …>`.
- **Command:** `<air format . | styler::style_pkg() | n/a>`.
- **Do not run:** *(the other formatter — mixing them churns the whole diff.)*

If **`none`**: the skill will match the surrounding file's existing style and will **not**
introduce a formatter as a side effect of a feature PR. Adopting one is a separate, deliberate
repo-wide decision.

### Other conventions

- **Errors:** *(e.g. `stop()` / `stopifnot()`. Do not introduce `cli::cli_abort()` or
  `checkmate`.)*
- **Verbose output:** *(e.g. `message()` gated on `verbose`, never `cat()` / `print()`.)*
- **Naming:** *(e.g. camelCase exports, snake_case arguments.)*
- **Method-entry preconditions **[switch]**:** *(Does every method that reads from a fitted
  object call a precondition helper — typically `.check_for_<method>(x)` — that validates the
  object and returns the invariants the method depends on? Name the convention if so. **This
  sets the drift sentinel's Check 2 mode:** with a convention, the sentinel BLOCKS on a method
  that skips it; with "none", it instead reports each unvalidated read as a NOTE and
  recommends adopting the convention. "None" does not disable the check.)*
- **Class validators / expected-slot lists:** *(name them — e.g. `.EXPECTED_SLOTS_<CLASS>`,
  an S4 `setValidity`, an S7 `validator=`, an R6 `initialize()` check — and the test files
  holding hand-built fixtures that must track them.)*

## 10. Dependencies

- **`Imports:`** — `<list>`.
- **`Suggests:`** — `<list>`. **Every code path calling these must guard with
  `requireNamespace("...", quietly = TRUE)` and degrade gracefully.** Tests and examples using
  them need the same guard or `\donttest{}`.
- **`LinkingTo:` / `src/`** — *(if the package has compiled code, note the toolchain and
  whether the gate needs a clean recompile.)*
- Adding a dependency is a decision to confirm with the maintainer, not a convenience.

## 11. Smoke snippet

A small, fast, self-contained call to exercise the package interactively after a change:

    <5–15 lines of R>

## 12. Gotchas that WILL bite

*(Only the ones specific to this repo and expensive to re-derive. Test each sentence: still
true in a different R package? Then it belongs in the skill, and what stays here is the one
clause naming the repo fact that makes it bite. Keep each short: symptom, cause, fix.)*

1. **<symptom>** — <cause>. Fix: <fix>.
2. …

## 13. Other local docs

*(The repo-local docs the skill does not carry — typically prioritization and the queue.)*

- **`.workflow/PRIORITIZATION.md`** — the tier order and heuristics for picking the next
  target.
- **`.workflow/QUEUE.md`** — the thin ordered head of the next few issues.
- **`.workflow/PROJECT_NOTES.md`** — durable methodology and design positions not obvious
  from the code, the spec, or git history.
