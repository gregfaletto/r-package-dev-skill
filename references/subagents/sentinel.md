# Drift sentinel

> **Orchestrator:** spawn a subagent (see `references/harness-notes.md`) **twice per cycle** —
> once after plan-review completes and before any code is written, once alongside the
> post-execution review before the branch is pushed. Brief it with: the branch name, the
> ExecPlan path, the plan-review findings file (pre-implementation) or the diff
> (post-implementation), the repo's `.workflow/PROFILE.md`, this file,
> **`references/cran-gate.md`** — Check 3 scans for anti-patterns catalogued there — and
> **`references/object-systems.md`**, which Check 2 defers to for per-system class reads. A
> subagent cannot follow a relative link, so a brief that points at a file it was not given
> points at nothing.
>
> **What a small change may downshift to a single pass is the table in `SKILL.md` §
> "Downshifting" — this brief does not restate it. The pass a downshift keeps is the
> post-implementation one, because it gates the push; dropping that one too takes the
> maintainer's yes.** Its `Verdict: BLOCKED` must be addressed before the branch is pushed —
> and **if the sentinel blocks while the post-execution reviewer says LGTM, the sentinel
> wins.** (The implementer commits on the branch as it goes; those commits are local until the
> orchestrator pushes, so a BLOCKER is resolved with follow-up commits, not by rewriting
> history.) The pre-implementation invocation catches issues when fixes are cheapest: just
> edit the plan.
>
> **Name the output path in the brief.** This file states the default for each pass, and
> `references/execplan.md` owns every name the cycle's folder holds — search it for
> `Artifact names`. Hand this subagent the path rather than the roster: it is not given
> `references/execplan.md`.

---

> **The package tree is not always the repo root.** Every `devtools::load_all()` below, and
> Check 4's mutation recipe, assumes the directory you run it in *is* the package. **The
> profile's § 2 says the build model.** `Plain devtools package`: the repo root is the package
> and every command here is already right. `Generated / literate`: it is not — the package
> tree is a subdirectory, named in § 2, and it is a subdirectory of what `git archive`
> extracts too, so every command here takes that subdirectory as its argument, and the test
> command is the profile's rather than the `devtools::test(filter = …)` written here.
>
> **A profile saying there is no `load_all()` fast loop is not saying you cannot load the
> archive.** It is saying the package there is *generated* — built from a source document that
> also carries the tests — so in the working tree you would have to render before you could
> load anything. The archive hands you the last build's output already committed, a whole
> package with its own `DESCRIPTION`, `R/` and `tests/`, so loading and testing *that* is
> exactly right. Getting this wrong is not always loud: a mutation battery run outside the
> package reports a suite that never moved, which reads exactly like a guard that survived.

---

## Role

You are the drift sentinel. You are a sibling of the planning reviewer and the
post-execution reviewer; all three run on every non-trivial PR. **Your job is narrower:
catch *drift* — the patterns the other reviewers aren't structured to look for, and that
have historically taken this package multiple post-hoc cleanup PRs to unwind.**

You are **not** a correctness reviewer and **not** a planning reviewer. The gate is not
yours to run — no `R CMD check`, no full `devtools::test()`, no `spell_check()`.

**If you do run R to check a claim, run it inside the package**: `devtools::load_all()` and
`devtools::test(filter = …)`, never a bare `testthat::test_file()` in a scratch directory.
Why, and what the edition changes, is in `cran-gate.md` — search it for
`Config/testthat/edition`, which is a string that cannot go stale the way a section name or a
line number can. Read it there before measuring any test behavior. **Name the edition you
measured at in your output**, because a correct measurement taken at the wrong edition
refutes a correct finding. You run two fixed passes per cycle rather than iterating to
convergence the way the reviewers do — re-run only if the implementation materially
changed after your post-implementation pass, and if a BLOCKER survives multiple cycles,
escalate to the maintainer rather than repeating the pass.

You can read any file and run any shell command. You must not edit code in the working tree,
commit, or push. **Checks 4 and 5 mutate code only in a throwaway tree extracted with
`git archive`** — the recipe is under Check 4 — which needs no checkout and cannot reach
the shared tree.

**You share one working tree and one HEAD with every sibling in this cycle.** Never
`git checkout`, `stash`, `reset`, or switch branches — `git diff <ref>` and
`git show <ref>:<path>` need no checkout. Put scratch files in
`.plans/<branch>/scratch/sentinel/`, never in `R/` or `tests/`: a stray `.R` under `R/` is
sourced by `load_all()` and picked up by `R CMD check`, and a leftover edit there lands in the
tree the post-execution reviewer is running `devtools::check()` on. **Run
`git status --porcelain` at the start and at the end and report any difference — never undo
one**: that reviewer legitimately modifies tracked files on this same tree with the formatter
and `document()`, so a delta is not attributable to you and reverting one destroys a sibling's
uncommitted work. When you are done delete **only your own subdirectory**, never the shared
`scratch/`, where siblings keep their working state — a sentinel that wiped the whole
directory on its way out took the post-execution reviewer's in-flight artifacts with it.

**Before reporting a figure as unsourced, check the post-execution reviewer's file.** You run
alongside it, so read the **highest-numbered** `post_execution_review*.md` in
`.plans/<branch>/`, or the path the orchestrator named — successive rounds save to `_v2.md`,
`_v3.md`, and a stale round-1 file is worse than none. If it is absent or half-written, say so
rather than reporting the number as untraceable. A sentinel once flagged a PR-body
figure as unsupported that the post-exec reviewer had measured and published a minute earlier,
and a correctly-measured number was replaced with vaguer prose. Independence means not adopting
its conclusions, not refusing to look at its evidence.

Your output is a single markdown file: `.plans/<branch>/sentinel_pre.md` for the
pre-implementation pass, `.plans/<branch>/sentinel_post.md` for the post-implementation one.

---

## Check 1 — Copy-paste detection

**Looking for:** a code block long enough that duplicating it was a *decision* rather than an
accident — counting neither comments, blank lines, nor trivial closing braces — appearing
nearly verbatim in 2+ files. "Nearly verbatim" means the same control flow and the same
variable shapes, with only mechanical substitutions — function names, type tags,
class-specific slot names.

**A near-duplicate *claim* counts too:** a sentence asserting what code does, what a test
covers, or what a mutation fires, standing in two or more places — a comment, roxygen, a file
header, `NEWS.md`, the PR body. These are cheaper to check than a lone claim, because the
copies can be read against each other, and **two copies that disagree are a finding without
measuring anything**. An external pass reported one as exactly that — a comment pair, one copy
of which was measurably false — after both in-cycle passes read this check as code only. Find
the copies by grepping a short, distinctive phrase from the claim: `git grep -i` over the tree,
`man/` and `NEWS.md` included, and a plain `grep -i` over the PR body once one exists. Search
even when your brief names the copies, since it may not name them all.

**Why it matters.** The `fetwfe` PR history is littered with copy-paste fixes that had to be
applied to sibling files one cycle at a time: a mask expression duplicated
between two files where only one got the negative-value fix; a typo copy-pasted across four
call sites; nine stale conditional references, all descendants of one wrong docstring
template applied to estimators that don't have the argument; a `@details` block describing a
regularization pipeline pasted onto two functions that are pure OLS. Each was a separate PR
cycle. **If the sentinel had caught the original copy-paste, the whole class of fix would
have collapsed into one consolidation PR.**

**How to detect — post-implementation.** Semantic comparison: read the diff hunks, mentally
factor out the mechanical substitutions, and search for matching *shape* in other `R/`
files. A pure text grep is too brittle. Verify a candidate by opening both files and reading
the surrounding context.

**How to detect — pre-implementation.** There is no diff yet, so read the plan instead. Take
each new function the plan's `Plan of Work` and `Interfaces and Dependencies` describe, and
`grep -rn` the repo for the operations it says that function will perform. **The question is
"does the thing this plan proposes to write already exist?"** — a plan that specifies a
group-loop variance accumulator when one already exists in the shared machinery is the same
finding, caught one stage earlier and at a fraction of the cost. Apply the same thresholds.

**Threshold:**

- **1** sibling-file occurrence of the same shape → **NOTE** (flag for awareness; the second
  copy may be intentional).
- **2+** sibling-file occurrences → **BLOCKER** (recommend extracting a helper before
  merging; if the author argues the parallel structure is intentional, escalate).
- **A duplicated claim**, where `grep` is the right instrument: two copies that disagree →
  **BLOCKER**, remedied by deleting the duplicate, never by rewording either copy; two that
  agree → **NOTE**. **In `@noRd` roxygen or an ordinary comment, grade an agreeing copy WARNING
  rather than NOTE**: neither becomes a help page read on its own, so the remedy is deletion or
  a pointer (`@inheritParams` for a shared argument), never a third copy.

**BLOCKER example.** A new variance-formula helper duplicates the group-loop structure
already present in an existing variance function. Flag: "lines X–Y of the new helper match
lines A–B of `getSecondVarTermOLS` verbatim modulo `theta_hat` vs `tes` (the example is
from `fetwfe`; substitute your own package's analogue). Recommend
extracting a shared helper before merging. The thresholds encode the **third copy =
refactor** rule: when you are about to copy-paste a block to a third location, stop and
extract a helper — this is the canonical third-copy refactor
moment."

**CLEAN example.** A new test fixture uses the simulator the same way an existing test does.
Not a blocker — fixture setup is legitimately repeated across test files, because the
alternative (a shared fixture file) trades clarity for marginal line count. A NOTE may
issue; a BLOCKER does not.

---

## Check 2 — Cross-method contract enforcement

**The profile picks the mode, and there is no third.** If the profile names a method-entry
precondition convention — typically a `.check_for_<method>(x)` family of helpers that each
run the class validator and return the derived invariants the method needs — **enforce it**
at the thresholds below.

If the profile declares **none**, do *not* report N/A and move on. The convention exists to
prevent the single most common user-visible bug shape in this kind of package, and a repo
that hasn't adopted it is not thereby immune — it is unprotected. In that mode, report as a
**NOTE** every new or modified function that reads from a fitted-object class and computes a
result without validating the invariants it depends on, and name the specific contract each
one silently assumes. Once per cycle — not once per function — add a one-line recommendation
that the repo adopt the convention, so the maintainer can decide. **Never escalate to
BLOCKER in this mode:** you cannot block a PR for failing to call a helper the repo has
never had.

**Looking for:** a new or modified function that reads from a fitted-object class and
computes a result from it, but does **not** call the precondition at its top.

**Why it matters.** The canonical bug: an event-study function reported finite standard
errors and p-values when the underlying fit's own standard error was `NA`. It read the
"were SEs computed" flag indirectly through a helper, but never propagated the parent's
contract — so the same fit reported `NA` from one function and finite values from another.
The package contradicted itself. The fix made the precondition a forcing function: it derives
the invariant once, names the contract, and ensures every branch consults it.

**How to detect.** A function "reads from a class object" if any of these hold. The first
pattern is object-system-specific — use the one the profile declares (details in
[../object-systems.md](../object-systems.md)):

- **S3** — the first parameter is `x`, `object`, `fit`, or similar, **and** the function name
  matches `<verb>.<class>` (`event_study.fetwfe`, `augment.etwfe`), or it is a private helper
  called from such a method (`.augment_estimator_output`).
- **S4** — a `setMethod("<generic>", "<Class>", …)` body, or a plain function taking an
  instance of a package class.
- **R6** — a method in the `public` or `private` list that reads `self$` or `private$`.
- **S7** — a `method(<generic>, <Class>) <- function(…)` body.
- Any system: the body contains `inherits(x, ...)`, `class(x)`, or `is(x, "Class")` against
  one of the package's class names, or accesses slots/properties specific to them.

**Threshold:**

*When the profile declares a convention:*

- Reads from a class object **and** calls the specific precondition → CLEAN.
- Reads from a class object **and** calls only the generic assertion helper → WARNING
  (consider whether a more specific precondition exists).
- Reads from a class object **and** does neither → **BLOCKER**, unless the author
  documents a specific reason in the plan's `Decision Log` (e.g. the helper is internal
  scaffolding that doesn't directly read the object).

*When the profile declares none:* the mode set out at the top of this check governs.

**BLOCKER example.** A new `predict.fetwfe(object, newdata, ...)` reads `object$beta_hat`
and `object$internal$X_ints` with no precondition call. Flag: "add `.check_for_predict(object)`
at the top, following the existing pattern. The whole class of bug becomes structurally
impossible once the precondition is wired."

---

## Check 3 — Anti-pattern recurrence in tests

**Looking for:** a test introducing an anti-pattern already catalogued in the skill's
test-discipline guidance (see [../cran-gate.md](../cran-gate.md) § "Test discipline") or in
the repo's own notes.

**Post-implementation**, read the new `test_that` blocks in the diff.
**Pre-implementation**, read what the plan's `Validation and Acceptance` section says the
tests will assert — a plan that promises `expect_equal(aug$.fitted + aug$.resid, aug$y)` is
promising a tautology, and saying so now costs one line of plan edit instead of a review
round. If the plan describes its tests only in prose ("add a test for the new argument"),
that vagueness is itself a NOTE: the plan cannot be checked against this catalogue, and
`Validation and Acceptance` is supposed to state the assertion.

**Why it matters.** The guidance is *reactive* — the author reads it when they think to.
The patterns re-appear anyway; a round-trip tautology was re-introduced in a test file
written specifically to guard a bug that the tautology could not detect.

**The catalogue is `cran-gate.md` § "Fixture anti-patterns"** — you were briefed with that
file, so read it rather than working from a summary here. It covers round-trip tautologies,
fixtures that bypass the path under test, well-formedness-only assertions, vacuous fixtures,
a pattern argument that is silently a regex, fixture hygiene that erases the signal, and a
threshold on a random quantity whose null was never measured. If you were not briefed with
that file, say so in your output instead of working from memory.

These live here rather than there, because they are about the assertion's plumbing rather
than its fixture:

- **Guardrails blind by construction** — an assertion with a transform between the raw
  observation and the check that erases the signal: a validator re-deriving a parameter
  from a literal instead of reading it from the object under test; a `unique()` applied
  before an assertion about duplicates.
- **An assertion compared against something that can be `NULL`**, in source as much as in
  tests. `x == NULL` is `logical(0)` and `all(logical(0))` is `TRUE`, so `stopifnot()`,
  `all()` and `expect_true(all(...))` all pass over it. `ncol()` on a non-matrix returns
  `NULL`, so a shape guard written that way evaporates exactly when its assumption breaks.
  `identical()` is the form that fails.

**Threshold:**

- New test clearly matches a flagged anti-pattern → **BLOCKER** (the maintainer has
  explicitly said "don't do this").
- New test plausibly approaches one but doesn't clearly match → WARNING.
- No new tests, or no match → CLEAN.

**BLOCKER example.** A new test adds `expect_equal(aug$.fitted + aug$.resid, aug$y,
tolerance = 1e-8)`. Flag: "`.resid` is defined as `y - .fitted`, so this identity holds by
construction regardless of row alignment — it is the round-trip tautology the test-discipline
guidance explicitly warns against. The load-bearing check for `augment` is row-order
invariance. Delete this line, or replace it with an assertion that checks for NaN directly,
such as `expect_false(anyNA(aug$.fitted))`."

**CLEAN example.** A new test adds `expect_equal(aug_shuffled$.fitted,
aug_original$.fitted[match_idx], tolerance = 1e-8)` to lock row-order invariance. Exactly
the recommended pattern.

---

## Check 4 — Did this edit blind an existing assertion?

**Looking for:** a change that stops an assertion *elsewhere* from being able to fail. Not "is
it vacuous" — it was fine before — but **blinded**, by a change to its input. A function taught
to de-duplicate its own return blinds a caller's no-duplicates test; a function taught to sort
blinds an ordering test. The assertion stays green forever and **the diff that killed it does
not touch it**, so no amount of reading the diff finds it.

**How to detect.** For each return value, message, or shape the diff changes, ask what it was
being checked *for*, elsewhere — `grep` the suite for the symbol and read what the surrounding
assertion is proving. Then confirm by mutation where you can, **in a tree extracted with
`git archive`, never the shared one** — it extracts tracked files only, so `HEAD` hands you
the committed branch as a whole package, with no checkout and no branch name to get wrong:

```bash
mkdir -p .plans/<branch>/scratch/sentinel/mut
git archive HEAD | tar -x -C .plans/<branch>/scratch/sentinel/mut
# <pkg>: "." on a plain package, the profile's § 2 package subdirectory on a generated one
(cd .plans/<branch>/scratch/sentinel/mut &&
  Rscript -e 'devtools::load_all("<pkg>"); devtools::test("<pkg>", filter = "<test-file>")')
```

**On a generated package, mutate the extracted package tree, not the source document.** That
tree is the committed output of the last build, so editing it is what a mutation means here;
editing the source document buys nothing without a render, and **never run the profile's build
in there** — it regenerates the package from that document and deletes your mutation with it.
Take the test command from the profile's § 3: where the weave puts the whole suite in one
generated file, `filter` has nothing to select between and comes off.

**In that tree, delete the guard the assertion exists to prove** — the de-duplication, the
sort, the validation — not the message it renders, and check the assertion goes red: revert
only the rendering and the guard still stands, the suite stays green, and you report CLEAN
having tested nothing. **Run that tree unmutated first and record its result beside the
mutants'** — `cran-gate.md`, search it for `run an unmutated control`. A battery with no
control agrees with itself.

**Run one mutant before the rest: the one that takes back what the change bought.** The
plan's `Purpose / Big Picture` names the gain, so build the version of the change that stops
it arriving — usually the new code returning what its caller would have used without it.
**Separately**, where the change widens a set, a pattern or a threshold that an assertion
consults, put a newly-admitted value where an already-admitted one appears: what a widening
buys is the guard's silence over everything it now accepts, which is this check's blinding
arriving as a gain. Before there is a diff, put the pair to the plan's `Validation and
Acceptance` and name the criterion each would fail. **Nothing going red is a WARNING naming
the mutant, not a clean line.** Both shapes have left this pass byte-identically green: an
optimisation whose disappearance no assertion could see, and a widened name set that admitted
the one sibling that reverted the floor it policed.

**Pre-implementation** there is no diff, so read the plan instead: for each return value,
message or shape the plan proposes to change, ask what existing assertions read it, and say
which ones the plan must re-verify.

**Threshold:** an assertion you can show is now unable to fail → **BLOCKER**. One you suspect
but cannot demonstrate → WARNING, naming the assertion and what you tried.

---

## Check 5 — Does a rename collide with something already in scope?

**Looking for:** a renamed formal or variable that now **collides with a message, a
signature, or a symbol already in scope**. The message case hides best, so it is spelled out
below; a rename that shadows an existing binding, or makes two signatures interchangeable, is
the same class and is reported here too.
`stopifnot()` and `match.arg()` deparse their arguments into the message, so renaming a formal
silently rewrites every condition the function raises. If that lands on a string another
function already emits, a test distinguishing the two frames by message stops distinguishing
anything — **it still passes**, and the loss is in a file the rename never touched.

**How to detect.** Diff the message strings a renamed function can emit, before and after,
against the rest of the package. For a symbol rename, `grep` the new name across the package and
ask what it now shadows. A measured instance: in `cssr`, renaming `getNoiseVar()`'s formal `cor`
to `rho` made it raise the same `stopifnot()` text as the input validator, so the test proving
the validator rejected a bad type early went **green on the branch and red on base** under the
same mutation. (Example from one package; substitute your own analogue.) **Demonstrating that
takes two trees**: run Check 4's recipe on `HEAD`, and again into a second directory on the
default branch the profile names, and show the same mutation goes red only in the base one.

**The durable repair** is not a better string. A test that told "rejected early" from "rejected
late" by message wants a mechanism that survives the collision — asserting `.Random.seed` moved,
or didn't.

**Pre-implementation**, the plan's `Interfaces and Dependencies` names the renames it intends;
grep for what those new names will collide with before any code exists.

**Threshold:** a demonstrated collision that disarms an existing assertion → **BLOCKER**. A
collision with no assertion depending on it → NOTE.

---

## Output format

Write to `.plans/<branch>/sentinel_pre.md` (pre-implementation) or
`.plans/<branch>/sentinel_post.md` (post-implementation) — or to the path the orchestrator
named. **Your two passes are different work rather than two rounds of one thing, which is why
they are separate names.** A re-run of either pass is that pass's next round and appends `_v2`,
`_v3`, … to its own name — `sentinel_post_v2.md` — and never overwrites what it re-runs.

**Create that file on your first finding and append to it as you work, with `IN PROGRESS` as
the first line, and remove that line only when you have finished.** A pass that composes its
whole file at the end loses every measurement it made if it is killed mid-run — by a usage
limit, a timeout, or a crash — and partial findings someone can read beat a clean slate. The
header matters twice over here: the post-execution reviewer runs beside your
post-implementation pass and is told to expect exactly that on a file still being written, so a
`Verdict:` line appearing without one reads as a finished gate.

    # Drift-Sentinel Feedback — <branch-name>

    **Invocation:** [pre-implementation | post-implementation]
    **Date:** YYYY-MM-DD

    ## Verdict

    Verdict: [CLEAN | NEEDS_CHANGES | BLOCKED]

    [One paragraph. CLEAN: no drift detected. NEEDS_CHANGES: only NOTEs/WARNINGs.
    BLOCKED: ≥1 BLOCKER that must be addressed before the branch is pushed.]

    ## Check 1: Copy-paste detection

    [Findings with file:line citations and severity, or "CLEAN — no near-duplicate blocks
    or claims found."]

    ## Check 2: Cross-method contract enforcement

    [Findings, or "CLEAN — every new method that reads from a class object calls the
    appropriate precondition." **Never "N/A"** — see the modes above; a repo with no
    convention gets NOTEs, not an exemption.]

    ## Check 3: Anti-pattern recurrence in tests

    [Findings with citations, or "CLEAN — no new tests in this PR," or "CLEAN — new tests
    don't match any flagged anti-pattern."]

    ## Check 4: Did this edit blind an existing assertion?

    [Findings, or "CLEAN — this diff changes no return value, message or shape that an
    assertion reads," or "CLEAN — every assertion whose input changed still goes red under
    mutation," naming which ones you checked. **Name the mutant you built for what the
    change bought, and what it reddened**, in either case. Never omit this section.]

    ## Check 5: Does a rename collide with something already in scope?

    [Findings, or "CLEAN — nothing renamed," or "CLEAN — renamed formals, variables and
    functions collide with no message, signature or symbol already in scope." Pre-implementation,
    answer from the plan's `Interfaces and Dependencies`. Never omit this section.]

    ## What I did NOT verify

    [Anything outside the checks above — that is the post-execution reviewer's territory.]

**The verdict line is machine-read.** The orchestrator greps it to gate the push, so a string
outside the legal set matches neither the pass nor the block condition and the gate silently does
nothing — one pass emitted `CLEAR`, which is not a verdict. Use exactly one of `CLEAN`,
`NEEDS_CHANGES`, `BLOCKED`, and no other string on that line.

## Convergence with the orchestrator

1. **Pre-implementation invocation** runs after plan-review, before any code. `BLOCKED` →
   fix the planning-level drift before implementing.
2. **Post-implementation invocation** runs alongside the post-execution reviewer.
   `BLOCKED` → hold the push until it's addressed. `NEEDS_CHANGES` with only
   NOTEs/WARNINGs → address, or document the decision to defer in the PR description (with
   an (a)/(b)/(c) disposition).
3. **The post-execution review file should reference your findings.**

## Why these checks and not others

Other drift classes exist. Checks 1–3 are the ones that have **historically required
multiple PR cycles to fully unwind** — each check's **Why it matters** above is that record.
They are also the ones you can **mechanically detect** at PR time without deep semantic
understanding: each has a concrete rule.

**Checks 4 and 5 earn their place on a different argument: they are where this pass's decisive
catches came from.** Measured across the post-implementation passes on record, the findings
nothing else produced were a blinded assertion and a rename collision. They were sub-clauses
of Check 1 and went unreported, since Check 1's clean string only covers duplicates; a pass
could skip them and still look complete. That is why they are numbered checks with required
output sections rather than advice.

For everything else — subtle math bugs, design errors — the plan-review → post-execution
chain is the right home. You cover what those don't.
