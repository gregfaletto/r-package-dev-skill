# Failure-mode catalogue

Failure modes with **no check behind them** — things you have to remember, because nothing
in the workflow catches them. Look one up when something surprising happens, or when a plan
touches the territory; there is no need to read them all before a cycle.

**Before adding one, see acceptance criterion 19.** A check beats a lesson every time, a
profile gotcha beats a lesson when the finding is repo-specific, and **nothing** is the
default — most of what a cycle surfaces was surprising once and will not recur.

**Retention rule.** A lesson leaves this list when its story moves *inside* the check that
enforces it — see the **Mechanized** and **Rules whose home is elsewhere** tiers in the
index. That is the whole retirement path, and it has the right incentive: writing a gate
removes a lesson rather than adding one.

**These are real incidents, not hypotheticals.** Where an entry names a function, a variable,
or a symptom, that is the actual one — not an anonymized stand-in. The concrete detail is kept
because it is usually what makes a failure mode recognizable when you hit it in your own
package.

## Index

A row links to a file when a plan reviewer is handed it, and otherwise names the destination
in prose — a link there would reach nothing from a clean context. **Every tier is a bullet
list carrying its number in the text**, because entries are cited by number throughout the
corpus and an ordered list would renumber itself from whatever its first item is.

**Process discipline**

- **1.** [The workflow is mandatory — never self-authorize a skip](#1)
- **4.** [Fix the bug *class*, not just the instance](#4)
- **24.** [CRAN release prep is a state, not a step](#24)

**Claims, evidence, and instruments**

- **10.** [Enumerate the real on-disk set before asserting a diff inventory](#10)
- **30.** [A claim about reachability is a testable claim](#30)
- **32.** [Your measuring instrument can be blind, and blindness looks like success](#32)

**Guardrails that stop guarding**

- **29.** [Consolidation kills the parity test that licensed it](#29)
- **31.** [Making a dead guard live promotes its error message to UI](#31)

**Environment and landing**

- **15.** [Air's config discovery, and why the repo ships its own](#15)
- **22.** ["PR shows merged" ≠ "the change is on `main`"](#22)
- **28.** [Green locally ≠ green everywhere](#28)

**Mechanized — a check now catches these.** Kept as the rationale for that check, not as
something to remember. Delete the check and you lose the reason it exists.

- **3.** Every deferred item needs a definitive disposition — no limbo → criterion 14 + the orchestrator's close-the-loop step
- **6.** Confirm test status from the summary line, never an empty grep → [cran-gate.md § Test discipline](cran-gate.md#test-discipline)
- **7.** A regression guard must be proven to fail when the code breaks → [cran-gate.md § Test discipline](cran-gate.md#test-discipline) + criterion 5
- **8.** Guardrails that structurally cannot see the bug → [subagents/post-exec-reviewer.md](subagents/post-exec-reviewer.md), search it for "Guardrail blind by construction"
- **9.** A perf change is a hypothesis — benchmark before shipping → the implementer's benchmark STOP
- **13.** Any signature change needs a roxygen `@param` audit → [subagents/post-exec-reviewer.md § 4](subagents/post-exec-reviewer.md)
- **14.** Keep version strings in sync wherever they appear → [execplan.md](execplan.md) criterion 8 — `meta$Version` deletes the class
- **16.** When guarding N sites, enumerate every *consumer* of the guarded value → [subagents/post-exec-reviewer.md](subagents/post-exec-reviewer.md), search it for "Multi-site fix incomplete"
- **17.** Additive parity fixes propagate to hand-built mock fixtures → [subagents/post-exec-reviewer.md](subagents/post-exec-reviewer.md), search it for "Slot-inventory change"
- **18.** A behavior-preserving rename must rename the tests too → the implementer's things-that-will-bite list
- **19.** Changing a user-visible condition invalidates existing assertions → the implementer's things-that-will-bite list
- **27.** Drift patterns: the classes worth a dedicated defense → the drift sentinel — that pass *is* this lesson
- <a id="33"></a>**33.** Repository facts verify; predictions about behavior do not → [execplan.md](execplan.md) + [subagents/plan-reviewer.md](subagents/plan-reviewer.md)

**Rules whose home is elsewhere** — no story to tell; the operational detail is the point.

- **2.** Underspecified issues are the norm — always clarify → the orchestrator's clarify-scope step
- **11.** Don't `@export` internal helpers → [cran-gate.md § Export discipline](cran-gate.md#export-discipline-internal-vs-public)
- **12.** Regenerate `NAMESPACE` and `man/` in the same commit as the roxygen change → [cran-gate.md § The per-PR CRAN gate](cran-gate.md#the-per-pr-cran-gate)
- **20.** "Accept both changes" is not always safe → [git-and-pr.md § Gotchas](git-and-pr.md#gotchas-learned-the-hard-way)
- **21.** Commit messages with Unicode — avoid heredocs → [git-and-pr.md § Gotchas](git-and-pr.md#gotchas-learned-the-hard-way)
- **23.** Landing a batch of parallel PRs — rebuild, never hand-merge → [git-and-pr.md § Gotchas](git-and-pr.md#gotchas-learned-the-hard-way)
- **25.** Delegate implementation to a subagent for non-trivial PRs → the implementer subagent
- **26.** A generated-artifact build's misleading failure symptom → the profile's §§ 2, 3, and 12

(Numbers are stable and never reused; every gap in the sequence above is an entry listed in
one of the tiers above, or retired. 5 was retired: it claimed a check that no file
implements.)

---

<a id="1"></a>
## 1. The workflow is mandatory — never self-authorize a skip

Every issue runs the full cycle: ExecPlan → plan-review subagent → (delegated)
implementation → post-execution review subagent → PR. **The only thing that authorizes
dropping a step is the maintainer's explicit permission for that specific issue**; trimming
one's depth needs it stated in chat where it can be vetoed. A prior documented skip is not a
precedent you may invoke unilaterally later; "this is obviously a one-liner" and "it's only
build/doc tooling" are not self-authorization.

The cautionary case: working a build-determinism issue, the agent judged the change "very
small" (one chunk option), skipped both review gates, and self-implemented. Two failures
followed, both of which a plan review is designed to catch.

- **The change was not obviously correct.** The premise that justified the skip — "trivial,
  zero risk" — was false: the fix interacted with the renderer's output capture in a way
  that needed an empirical rebuild, not eyeballing.
- **The acceptance criterion was bogus.** The success test was "grep the rendered chapter
  for zero `## Writing` lines," but the documentation generator legitimately writes 64 such
  lines every build. The real criterion was "zero *churning* writes **and** a twice-build
  no-op." The agent declared failure against the wrong metric. **A plan review's "are these
  acceptance criteria the right observable behaviors?" question exists precisely to catch
  this.**

A related miss the same cycle: the agent told the maintainer a timestamp churned "the title
page only," when it is emitted into every page's metadata and churns ~10 files per
cross-day rebuild. The maintainer's "accept that residual" decision had been made on a wrong
characterization — a second reason the gate matters. **It re-checks the facts a scope
decision rests on.**

For build or tooling changes whose correctness is only confirmable by a rebuild, the rebuild is
part of implementation, never a replacement for the review gates.

<a id="4"></a>
## 4. Fix the bug *class*, not just the instance

After fixing a bug, immediately grep for the same *shape* and fix every occurrence in the
same PR — or file a tracking issue for the rest. A fix scoped to the one function you
happened to be in leaves identical latent bugs behind.

The case: a PR fixed "vectorized `cor()` returns `NA` on a constant column, which then
poisons `which.max`" in one prototype-selection function. The **identical** pattern lived in
a sibling function's tie-break — and there it was *worse*, crashing the print method through
an output guard. A periodic review found it two cycles later; an *earlier* review had
already flagged it as a "could fold into PR B" aside, and it was simply never propagated.
**Two misses of the same defect, because the fix was instance-scoped.**

Rules:

1. After fixing a bug, grep for the operation that caused it and audit every hit for the same
   failure mode. Sibling functions doing near-identical things are a strong prior for the same
   bug.
2. If a review or plan flags "the same issue also exists at X (out of scope)," **X must
   become a filed issue, not a parenthetical.** Parentheticals get lost.
3. When a fix establishes a new safe idiom, note in the PR that it should be the standard
   for that operation, so future code and reviews can check adherence.

<a id="10"></a>
## 10. Enumerate the real on-disk set before asserting a diff inventory

When a plan's acceptance criteria predict "the diff will be exactly X," derive X from `ls` /
`git status` against the actual tree, never from a mental model of what the tool "should"
emit.

The case: a plan to prune orphan documentation pages assumed the directory held only
`<fn>.html`, so the predicted diff was "4 deletions." Plan-review, reading the tree, found
the directory also held **67 pandoc-generated `.md` siblings** and a figures subdirectory —
so the whole-directory delete actually pruned **48 stale `.md` too**, and the live topic
count was 18, not 17. The fix was still correct and the broadened prune desirable, but had
the wrong "4 deletions, byte-identical otherwise" gate survived to implementation review, it
would have **false-flagged the correct 52-deletion diff as a defect.** Generated trees
accumulate artifact classes across tool upgrades. List what is actually there.

**Corollary — a whole-directory delete can silently inherit a new tool dependency.** Once
the directory is pruned wholesale, the kept `.md` are regenerated by pandoc every build. A
build run *without* pandoc would delete the directory and not regenerate them, silently
shrinking the committed site with no error. So: don't commit a build produced in an
incomplete environment, and verify the determinism check still holds with the new dependency
rather than assuming it. **When you replace a surgical edit with "delete and let the tool
rebuild," ask what the tool needs in order to rebuild, and whether that's guaranteed
present.**

<a id="15"></a>
## 15. Air's config discovery, and why the repo ships its own

`air format .` walks **up** the directory tree looking for a hidden `.air.toml`. The first
one found determines indentation.

**The backstory, recorded so the investigation isn't repeated.** For a long time a repo had
no config, yet `air format .` from inside it preserved tabs. The reason: the maintainer has
a **user-global `~/.air.toml`** setting tab indentation. Air's upward search hit the home
directory for any path under it but missed it for paths under `/tmp/` — which explained why
formatting a copy of a repo file in `/tmp/` converted tabs to spaces while the same file in
the repo did not. The original investigation missed the user-global config entirely because
`find -name "air.toml"` does not match the dot-prefixed `.air.toml`.

**Why ship a repo-local `air.toml` anyway:** it removes the dependency on one person's
personal config. Anyone cloning the repo gets the right indentation without setting anything
up, and the behavior doesn't drift if the global config changes.

**If air ever misbehaves:** check the repo-root config still exists with the expected
`[format]` block; check whether air is current; then check whether a release changed
config-discovery semantics. Why currency matters, and the other hazards, in
[cran-gate.md](cran-gate.md#if-the-repo-uses-air).

<a id="22"></a>
## 22. "PR shows merged" ≠ "the change is on `main`"

**Prefer sequential single-PR-to-`main`.** Stacking carries a real failure mode: GitHub only
retargets a dependent PR when the base branch is **deleted**. Merging the base without
deleting its branch means the dependent PR merges **into the base branch, not `main`** —
while still showing "Merged."

That happened: the base reached `main`; the dependent did **not**, yet its PR showed merged
and the issue *looked* done. The issue stayed open only because the merge wasn't into the
default branch — a lucky tell. Had it auto-closed, the miss would have been quieter still.

**Verify the landing, every time**, before deleting any branch or moving on:

```bash
git fetch --prune
git merge-base --is-ancestor <commit> origin/main
```

A merged PR number is not proof; the ancestry check is. Recovery and the stacking protocol
are in [git-and-pr.md](git-and-pr.md#gotchas-learned-the-hard-way).

<a id="24"></a>
## 24. CRAN release prep is a state, not a step

The repo cycles between open development and pre-submission lockdown. **During lockdown,
scope is locked**: only bug fixes, doc fixes, and CRAN-compliance changes belong in flight.
Larger features and refactors are deferred; `cran-comments.md` and the submission file are
updated; `NEWS.md` gets a finalized header for the version about to ship.

Cues you're in lockdown: recent commits reading "increment version number," "fix CRAN
NOTE," "update CRAN-SUBMISSION"; and a recent `cran-comments.md` modification date. If
you're picking a target during lockdown, a CRAN-NOTE fix is welcome and a new exported
function is not. **When in doubt, ask.**

<a id="28"></a>
## 28. Green locally ≠ green everywhere

A green check on your machine is evidence about **one platform, one R version, and one
BLAS.** The catalogue of what fails only elsewhere — BLAS tolerance, locale collation,
Windows' missing `fork`, oldrel syntax, R-devel strictness — is in
[cran-gate.md § Continuous integration](cran-gate.md#continuous-integration), along with the
`skip_on_*` tools and the triage rules. It is not repeated here.

The story is what makes it worth reading. A package added a six-job matrix, and the
**first run** failed on all four Ubuntu jobs while passing on macOS and Windows: four
assertions demanding bit-identity between `kronecker(diag(N), A) %*% y` and a `T×T`
block-apply — mathematically the same quantity, numerically two different operation orders,
disagreeing by 1–4 ULPs. They had been in the suite for months, and the shipped release note
for that change asserted the identity was "verified bit-identical (16-digit parity)."

**No local check could ever have falsified that claim.** It cost twenty minutes to demonstrate
once the matrix existed.

<a id="29"></a>
## 29. Consolidation kills the parity test that licensed it

**Now checked.** The post-execution reviewer carries the consolidation-disarms-parity check
and the re-run-the-mutation-after requirement — search it for "A consolidation that silently
disarms the parity test". This entry is its rationale.

**A cross-implementation parity test loses all of its power the moment the two
implementations it compares are consolidated.** It keeps passing. Nothing announces the
loss. And the PR that causes it is, by construction, the very PR the test was written to
police.

The case. A ten-PR single-sourcing campaign opened with a dedicated guardrail file, written
as "the blocking prerequisite for the refactor" — three anchors, each asserting that two
independently-implemented code paths agree on the same fitted object. It worked: at the
commit it merged into, perturbing one of the three then-duplicated copies fired **all three
anchors on all three fixtures, nine failures**.

Eight consolidation PRs later, the same conceptual perturbation — now applied to the single
surviving copy — fired **three failures**. Two anchors had gone silent, because both sides
of each now called the same extracted helper. A ninth PR then folded the last independent
path, and with it the third anchor: the perturbation passed the **entire** guardrail file.
Nobody noticed for three weeks. The file header still read *"if any copy drifts, the
accessors silently report INCONSISTENT SEs for the same fit."*

**The rules.**

- **When a PR folds N call sites onto one helper, ask which existing assertions compared
  those N sites to each other.** Every one of them just became a tautology. Enumerate them
  in the PR, and say what replaces them.
- **Absolute pins are the consolidation-proof half of a guardrail.** A parity assertion
  depends on two implementations existing; a hand-computed expected value does not. If a
  guardrail file has a "compare A to B" half and a "pin literal values" half, the second half
  is the one that survives — so pin *every* fixture, not one of six.
- **A guardrail-then-refactor pair needs a review pass AFTER the refactor, not only before
  it.** This is the load-bearing rule. The guardrail is normally reviewed when written —
  when it demonstrably has power — and the refactor is then waved through *because* the
  guardrail is green. The one moment nobody looks is the moment the power is lost.
- **Verify by mutation at the end, not the beginning.** "Mutation-checked to bite" in a PR
  body is a claim about the code *at the time the guardrail was written*. Re-run the mutation
  against the post-refactor tree.

**Two subtler variants from the same audit.** A "pre-refactor reference implementation" test
that calls the live helper it is supposed to be a reference *for* is not an independent
reference. And a test asserting two S3 aliases are one implementation via
`expect_identical()` on the closures cannot detect a **byte-exact** re-expansion — closure
comparison ignores `srcref` — which is precisely the duplication state it exists to prevent.

<a id="30"></a>
## 30. A claim about reachability is a testable claim

**Now checked.** The post-execution reviewer treats an untested reachability claim as a
finding — search it for "An untested reachability claim". This entry is its rationale.

"This branch is unreachable through any public entry point" is not a remark. It is an
assertion about the code, it is usually cheap to test, and in this codebase it has been
**wrong more often than right**.

The case. A defensive branch carried the comment "unreachable through any public fit." Two
successive reviewers tried to reach it, were intercepted by an upstream guard, and each
concluded the comment was correct — one of them hedging it to "not proven, but consistent
with unreachable." A third reviewer reached it in fifteen lines: the upstream guard tested
`anyNA(coef(lm(...)))` on the *uncentered* design at `lm.fit`'s `1e-7` QR tolerance, while
the branch's own guard tested the *centered* Gram at `max(dim) * .Machine$double.eps` — on
that design, ≈ `9e-15`; the value scales with the dimension, so it is not a constant. Two
covariates collinear at `1e-6` land between them: the fit returns `att_se = NA` with a
warning, from a plain public call. Worse, another comment elsewhere in the package had said so
all along — "a genuinely singular design is caught downstream" — so the codebase carried two
comments asserting opposite things.

**The rules.**

- **Hedging is not a substitute for testing.** "Not proven, but consistent with unreachable"
  reads as caution and functions as an assertion — the next reader takes it as settled. If
  it's cheap to test, test it; if you genuinely can't, say what you tried and what would
  falsify it.
- **Two failed attempts are not a proof.** They are two data points about the parameter
  values you happened to pick. Where two guards use *different tolerances on different
  matrices*, there is almost always a window between them.
- **Grep for the counter-claim before writing yours.** Contradictory comments in one package
  are worse than no comment, and the older one is often the correct one.
- **Pin the claim with a test.** An untested reachability claim rots silently. A test with
  fixtures on both sides of the boundary also pins the *ordering* of the two tolerances, so a
  future change to either cannot move it unnoticed.

**The twin corollary.** When two near-duplicate paths are merged, each one's documentation
was scoped to *that* path. Promoting one twin's comment onto the shared helper silently
falsifies it for the other. One fold in the same audit did exactly that — kept the claim that
was true for the cohort twin, generalized it onto the helper where it is false for the
event-study twin, and **deleted the comment that was accurate**. When merging twins, diff
their comments as carefully as their code.

<a id="31"></a>
## 31. Making a dead guard live promotes its error message to UI

**Now checked.** The post-execution reviewer covers newly-live guards and both-ends tolerance
interrogation — search it for "A guard made live inherits an unreviewed error message". This
entry is its rationale.

A guard whose condition was never true has an error message that has never been read. The
moment you fix the condition, that message becomes user-facing text — and it has had none of
the scrutiny user-facing text normally gets.

The case. A hardening batch replaced a tautological condition (`sum(n_g) + n_never != N`,
where `n_never` was defined as `N - sum(n_g)`) with one that actually fires. The `stop()`
underneath was untouched — and it hardcoded one caller's name and one analysis family, while
the helper is shared by two public entry points. After the fix, the second entry point's
users were told to look at a function they hadn't called, about a family they weren't using.

**The rules.**

- **When you make a dead branch live, review its message as if newly written.** Check the
  function name, the argument names, and any claim about *which* caller or *which* code path
  is involved.
- **A shared helper must not hardcode one caller's name.** Pass it in.
- **Watch the tolerance you widen.** The same batch fixed a false positive by scaling an
  absolute tolerance by `N` — and reintroduced the original defect at the other end, because
  `round()` bounds the deviation at `0.5` and the scaled tolerance crosses `0.5` at
  `N = 2^25`. A threshold needs interrogating at **both** ends of the input range: does it
  reject what it should accept, *and* does it still accept-nothing-it-should-reject at the
  far end? A tolerance widened past the signal it exists to detect is a tautology again.

<a id="32"></a>
## 32. Your measuring instrument can be blind, and blindness looks like success

The **guardrail blind by construction** anti-pattern (now in the post-execution reviewer —
search it for "Guardrail blind by construction") is about a *guardrail* that cannot see the
bug. This is the same shape one level out: the **tool you use to measure coverage** reports
absence of evidence in a way indistinguishable from evidence of absence. Three instances
surfaced in a single cycle, each in different clothing — all read off testthat 3.3.2,
2026-08-23, so re-check before relying on one:

- **A reporter that stops reporting.** Above `testthat.progress.max_fails` — **default 10** —
  `devtools::test()` aborts with `Maximum number of failures exceeded; quitting.`, leaves every
  later test file unrun, and prints **no `[ FAIL n | … ]` line at all.** So the summary-line
  grep returns empty precisely when the suite is most broken, which is byte-identical to what a
  clean run's grep returns. A harness parsing that output reported **"SURVIVED — no test
  detects this" for all twelve mutations while every one of them was in fact caught** — twelve
  fabricated coverage gaps.
  *(Measured on the default reporters. An earlier version of this lesson blamed the default
  reporter for omitting per-failure detail; that does not reproduce — the defaults print
  file:line detail **and** the summary. Wrong mechanism, right rule, which is its own instance
  of the lesson.)*
- **A silent cap.** `SummaryReporter`'s `max_reports` defaults to **10**, so five mutations
  reported exactly `FAIL 10` with truncated attribution lists that looked complete. One
  appeared to miss the very file that must catch it.
- **A pattern that isn't a literal.** `expect_match()` defaulting to `fixed = FALSE`, so
  `"[pointwise 95% CI]"` matched the output it was written to exclude.

**The rule: before believing a measurement, prove the instrument can produce a negative.**
Feed it a case you *know* should register and confirm it registers. A harness whose entire
job is detecting silence must itself be shown to break silence — otherwise a broken parser
and a perfect test suite emit the same output, and you cannot tell which you have.

A mutation script should verify its pattern applied before running the suite.
