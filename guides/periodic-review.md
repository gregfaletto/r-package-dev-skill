# Periodic multi-agent code review

> **Orchestrator:** spawn one subagent per lens below (see `references/harness-notes.md`)
> concurrently, in one batch, once Step 0's inventory exists. Brief them with everything
> Step 1 requires, in the order it gives, and with each one's own lens and nothing from the
> others. What is named here is named because it has to travel rather than be pointed at —
> and they do not travel to the same agents. **`references/object-systems.md`** goes in
> every brief; lens 3 needs it for the method-registration check, and a lens text sends the
> agent to it. **`references/cran-gate.md`** goes to lens 3 alone, which is the only lens
> that runs a gate command, and the bars for reading what a gate prints are there. Step 1
> states each handover in its own place, and states what lens 3 must not carry across from
> that runbook. Nothing else of Step 1 is repeated here: a partial copy is how the
> reliability instructions go missing, and agents have already been lost to their absence.
>
> **Only the lens sections are the brief.** A subagent handed the whole runbook reads
> instructions addressed to you as if they were addressed to it — and it cannot follow a
> relative link, so a brief that points at a file it was not given points at nothing.

## Contents

> **Orchestrator through the end of this section.**

- [When to run](#when-to-run)
- [Step 0 — set up context](#step-0--set-up-context)
- [Step 1 — launch the agents in parallel](#step-1--launch-the-agents-in-parallel)
- [Agent output reliability](#agent-output-reliability)
- [Step 2 — synthesize](#step-2--synthesize)
- [Step 3 — update the process docs](#step-3--update-the-process-docs)
- [Files this cycle produces](#files-this-cycle-produces)

---

The orchestrator's runbook for a **codebase-wide** review pass. Distinct from the per-PR
review chain: parallel subagents each cover a focused slice with a different lens, then
the orchestrator synthesizes their findings into a prioritized review and (typically) a set
of issue drafts.

What it is good at is the drift that accumulates across months of feature work and that no
single PR review is positioned to see: a standard-error inflation that only appears under
partial selection, a variance-component bug affecting every default inference call, plus the
doc, test, and cleanup debt that never surfaces as a failing check.

## When to run

> **Orchestrator through the end of this section.**

**Primarily, the periodic review should be run upon explicit request of the user.** You
may also suggest a periodic code review:

- **After a stretch of feature PRs** — three or more releases since the last comprehensive
  review.
- **Before a CRAN submission window**, to surface latent issues before users find them.
- **After methodology-touching work** — math bugs are easier to find in a focused pass than
  scattered across per-PR reviews.
- **Not** as a substitute for the per-PR review chain, which stays mandatory.

---

## Step 0 — set up context

> **Orchestrator:** what to assemble before a run. None of it is briefed to anyone;
> `{{RECENT_CONTEXT}}` is the one product of it that reaches an agent.
>
> Inventory before launching:
>
> 1. **What shipped since the last review.** Skim `NEWS.md` and `git log --oneline main`
>    since the prior review date. This becomes the `{{RECENT_CONTEXT}}` each agent receives.
> 2. **What's open on GitHub.** If a bug is already filed and being worked, agents don't need
>    to rediscover it.
> 3. **What lives in the prior run's output directory.** Agents shouldn't re-litigate
>    findings already addressed.
>
> Then create the run's output directory and the shared scratch directory under it.
> **`{{DATE}}` everywhere in this file is this run's date in `YYYY-MM-DD` form** — fix it once
> here and substitute it into every path below and into every brief:
>
>     mkdir -p .plans/code-review-{{DATE}}/scratch     # e.g. .plans/code-review-2026-08-27

---

## Step 1 — launch the agents in parallel

> **Orchestrator through the end of this section.**

Spawn one agent per lens, **concurrently, in one batch, in the background** if the harness
supports it. Wall time is ~10–20 minutes; each agent produces a 1500–3000 word report.

Every brief must include, in this order:

- The lens (below), with a **bounded** read-in-full list plus instructions to grep/skim the
  rest for the target patterns.
- `{{RECENT_CONTEXT}}` — "for grounding, not re-litigation."
- The repo's `.workflow/PROFILE.md` path and the authority document, if any.
- **`references/object-systems.md`** — lens 3 needs it for the method-registration check, and
  a lens text sends the agent to it. Hand the file over; from a clean context a relative link
  reaches nothing.
- **The working-tree rules, verbatim, in every brief.** These agents run at the same time
  against one working tree and one HEAD, and the lenses put them to work in it: lens 1 is told
  to write a small empirical test to verify, and lens 3 to run the test suite, the check, and
  the spell check. So one agent is running `R CMD check` on a tree its siblings are writing
  into, and none of them can see the others. The per-PR chain at least runs on a feature
  branch whose work is already committed; this pass creates no branch at all, so whatever the
  maintainer had checked out is what these agents share. Hand over:
  - *Scratch files go in `.plans/code-review-{{DATE}}/scratch/<the basename of your report
    file>/`, never in `R/` or `tests/`. Create it if it is not there.* A stray `.R` under `R/`
    is sourced by `load_all()` and picked up by `R CMD check`; a stray test file runs in the
    suite — and a sibling running the check sees both and reports them as findings.
  - *Never `git checkout`, `git stash`, `git reset`, or switch branches; never `git add`,
    `git commit`, or `git push`.* `git diff <ref>` and `git show <ref>:<path>` need no
    checkout. A reviewer that checked out another branch to compare and did not restore has
    stranded a sibling's work before.
  - *Do not edit source.* Every lens is a reporting pass: name the fix with a file:line, do
    not apply it. A refactor lens that starts refactoring is indistinguishable from the drift
    it was sent to find.
  - *Run `git status --porcelain` at the start and at the end, and report any difference in
    your report rather than undoing it.* A delta may be a sibling's — reverting one destroys
    uncommitted work you cannot see.
  - *When you finish, delete only your own subdirectory, never the shared `scratch/`*, where
    the others keep their working state.
- **"Write your report file FIRST, before any final structured return."**
- The output path — the exact filename [Files this cycle produces](#files-this-cycle-produces)
  gives for that lens, under `.plans/code-review-{{DATE}}/`. Those names are shorter than the
  lens headings, so a path derived from a heading is a file synthesis will not find.
- The required report structure for that lens.
- **"Making the final structured-output call is an explicit, non-negotiable last step."**

**Lens 3's brief carries a file the others do not**, which is why it is not in the list above.
`references/cran-gate.md` goes to lens 3 and to no other lens: nothing else here runs a gate
command, and this one is a runbook rather than an inert reference — handed to a lens with no
gate to run, it reads as an invitation to run one. Slot it where the list puts
`references/object-systems.md`. Lens 3 needs it because it runs the check and the spell check,
and how to read what they print, including that `error_on = "note"` is what makes the exit
status mean anything, is there.

**Nothing checks that restriction — it is on you.** `check-briefs.R` derives one handed set per
brief *file*, and this file holds a brief per lens, so every name after "Brief them with" in
the opening block counts as handed to all of them: a lens text pointing at that runbook passes
the check, and a copy of the runbook reaching another lens's brief is outside what any check
here can see. Why this is left as prose rather than made mechanical is recorded above
`handed_set()` in `scripts/check-briefs.R`.

**Reconcile as you brief: parts of that runbook are written for a pass that is allowed to
write, and this one is not.** Its gate sequence opens with the formatter and
`devtools::document()`, and its base check extracts the default branch with `git archive` to
separate a pre-existing NOTE from a new one. Lens 3 runs the commands its own lens names and
nothing else out of that file — there is no branch here for a base check to compare against,
and a finding that predates this pass is this pass's subject, not its exemption. Its scratch
paths are the per-PR cycle's for the same reason, keyed to a branch folder this pass never
creates, so the ones above are the paths that hold here.

**The check is itself one of those writers.** `devtools::check()` regenerates `man/` and
`NAMESPACE` before checking unless it is told not to: its `document` argument defaults to
`NULL`, and `NULL` resolves to run the documenter whenever `DESCRIPTION`'s `RoxygenNote`
matches the installed roxygen2 — which, on the machine whose maintainer generated that field,
it generally does. So brief lens 3 with **the profile's § 3 invocation, with `document =
FALSE` in it**. § 3 carries whatever else this repo's check requires, such as a package
subdirectory; `document = FALSE` is mandatory here whether or not § 3 records it, because a
profile that omits it is resting on a `DESCRIPTION` field and an installed version rather than
on a decision. Left off, the regenerated files land in the tree every other lens is reading,
the working-tree rule above sends each of them to report the delta rather than undo it, and it
stays in the maintainer's uncommitted tree. If the check then reports documentation out of
date, that is a finding about the tree as the maintainer left it — report it, do not
re-document it away.

### Lens 1 — Core bug hunt

Read the package's primary entry points and their numerical cores in full. Look for:

1. **Off-by-one errors** in indexing — especially Jacobians, index vectors, and loop bounds
   where the boundary is easy to get wrong. Compare each estimator's path against its
   siblings' analogous paths to spot drift.
2. **NA / NaN handling on edge cases** — the minimum of each dimension (one group, two
   periods, zero covariates), the extremes of each tuning parameter, zero-coefficient
   fallback paths, empty groups, and how a zero or `NA` standard error flows through
   p-value computation.
3. **Numerical issues** — near-singular inversions (`solve()` with no ridge fallback),
   floating-point `==` comparisons, log or division by zero, variances that can go slightly
   negative under accumulated error and then get `sqrt`'d.
4. **Inconsistencies between sibling estimators** — the same logical operation implemented
   differently; a recent addition that landed in some but not all; different argument names;
   different output slot shapes.
5. **Cross-reference with the authority document** where reasonable. Spot-check the variance
   formulas against the theorems they implement.

Procedure: read each file fully; for each potential issue decide whether it's an actual bug
or merely unusual code; **write a small empirical test to verify** where possible.
**Severity > count.**

Report structure: verdict; bugs found (severity, location, what's wrong, how to verify,
suggested fix); edge-case concerns; inconsistencies between estimators; alignment notes;
what you did NOT verify.

### Lens 2 — Shared math and utility machinery

Read the design-matrix construction, the variance formulas, the input validators and
coercion helpers, and the data-generating utilities in full. Look for:

1. **Numerical correctness vs the spec** — each variance formula against its theorem; any
   sandwich estimator's shape against the reference implementation; transformation matrices
   (invertibility, determinant); matrix square roots (verify it's the *inverse* square root
   where claimed, not the square root).
2. **Vestigial parameters and dead code** — parameters in signatures never referenced in the
   body; branches that can't execute; helpers nobody calls.
3. **Off-by-one risk areas** — index-computing helpers spot-checked against brute force
   across a grid of dimensions.
4. **Edge cases and brittleness** — does the balance check report *all* malformed units or
   just the first? Does the constant-column drop behave at zero covariates? Integer-vs-double
   comparisons.
5. **Input-validation consistency** — inputs one estimator accepts that a sibling rejects
   unnecessarily.
6. **Redundancy** — helpers doing nearly the same thing; multiple variance computations in
   different files.
7. **Performance landmines** — quadratic loops that could be vectorized, a `solve()` on a
   matrix that is later crossprod'd, repeated `model.matrix` calls. Flag, don't assume:
   a vectorization is a hypothesis until benchmarked.

Report structure: verdict; bugs and numerical issues; vestigial parameters and dead code;
edge-case and robustness concerns; validator inconsistencies; redundancy opportunities;
alignment notes; what you did NOT verify.

### Lens 3 — API design and best practices

Read the repo's conventions first — `.workflow/PROFILE.md` and `references/object-systems.md`,
which you were handed, as was `references/cran-gate.md` for the bars below. Then skim all of
`R/`, with the public entry points and S3 method files read in full. **This lens is not about
numerical correctness.** Look for:

1. **Roxygen completeness and accuracy** — every public function has title, description,
   `@param`, `@return`, `@examples`, `@export`. Are `@return` blocks listing output slots
   current? Stale `@param` descriptions? `@inheritParams` opportunities? Do internal helpers
   carry `@keywords internal` + `@noRd`?
2. **API consistency across siblings** — argument order, option-value vocabulary, output
   slot names, S3 class vs bare list returns.
3. **Error-handling quality** — a generic `stopifnot(is.character(x))` produces an opaque
   error where `if (!cond) stop("the time column 'foo' must be character")` would not.
4. **Method consistency** across the classes — `print`, `summary`, `coef`, `plot`, `tidy`,
   `glance`, `augment` — and correct registration in `NAMESPACE` for whichever object
   system(s) the profile declares. The per-system registration rules are in the skill's
   `references/object-systems.md`, which you were handed.
5. **Test coverage gaps** — exported functions with no dedicated `test-*.R`; edge cases not
   systematically tested across the parameter grid.
6. **Naming and ergonomics** — names matching local convention, and user-facing argument
   names matching the reference packages users will have seen.
7. **Spell-check vocabulary** — terms that belong in `inst/WORDLIST` but aren't there.
8. **CRAN conventions** — `message()` gated on `verbose` rather than `print()`/`cat()`;
   `tempdir()` for file writes in examples, tests, and vignettes; no `<<-` in user-facing
   paths.

Be empirical: actually run the test suite, the check, and the spell check. The bars for
reading what they print are in `references/cran-gate.md`, which you were handed; search it
for `exits 0 on a run with NOTEs`, because a check that exits 0 is not a check that passed.
Cite file:line for everything.

Report structure: verdict; roxygen issues; API inconsistencies; error-handling issues; S3
dispatch and method consistency; test coverage gaps; naming and ergonomics; CRAN-policy and
build-hygiene issues; what you did NOT verify.

### Lens 4 — Recent additions deep-dive

Read every file added or modified in the `{{RECENT_CONTEXT}}` window in full, plus every
test file created in that window. **These additions have had less production exposure than
the rest of the package; bugs are more likely here.** Look for:

1. **Tautological tests** — any assertion that holds by construction regardless of
   correctness. A test framed as a correctness check that is actually trivial should be
   flagged.
2. **Row-order and alignment assumptions** in any method binding computed values back onto
   user-supplied data.
3. **New options' interactions with old behavior** — does each new option compose correctly
   with each pre-existing one?
4. **`requireNamespace` fallbacks** for `Suggests:`-only dependencies — does the fallback
   path error cleanly and actionably when the package isn't installed?
5. **Test fixture coverage** — do recent tests use fixture parameters that actually exercise
   the code path? (A convenience wrapper that passes true parameters straight through does
   not exercise the estimator meant to infer them.)
6. **Coverage gaps** — specific parameter combinations recent features should exercise but
   don't.

Don't re-litigate what the per-PR reviews in that window already settled. Their
`.plans/<branch>/` folders are deleted when the PR merges, so read what outlives them: the
merged PR bodies, the issues those cycles filed, and the previous `.plans/code-review-*/` run,
which is kept for exactly this purpose. Treat a branch folder that happens to have survived as
a bonus, not as the source — don't plan on finding one.

Report structure: verdict; tautological or weak tests that may be masking bugs; bugs by
severity; row-order and alignment risks; new-option interaction concerns; coverage gaps;
what you did NOT verify.

### Lens 5 — Redundancy, structure, and streamlining

**Structural quality only** — DRY violations, parallel implementations that should be
unified, overly complex functions, copy-paste patterns. Not a bug hunt, not a docs review.
Read the sibling entry points and their cores, the variance machinery, the S3 class files,
and the tidy/glance/augment backend. Look for:

1. **DRY violations** — blocks appearing in 2+ places with only mechanical substitutions.
   Where is the same pattern in *code*, not just docs?
2. **Parallel implementations that should be unified** — read both side by side, identify
   the actual differences, and judge whether unification is worth the complexity of the
   merged abstraction. **Sometimes two functions that look similar are doing different
   things; flag cases where the parallel structure obscures a real difference.**
3. **God functions** — over ~200 lines doing too many things. Could input-prep, estimation,
   and output-assembly be factored into named subroutines?
4. **Deep nesting and convoluted control flow** — `if/else` chains four-plus levels deep,
   early returns that obscure the happy path.
5. **Helpers that should be consolidated** — small utilities defined locally inside larger
   functions or duplicated across files; utility-tier functions sitting in non-utility files.
6. **Repeated patterns across siblings** — where the same 10–50 lines appear with different
   specific calls, could a skeleton wrap the common structure with a few injection points?
   **Be careful: factor out only what's truly shared. Fake-DRY — forced unification of
   things that merely look similar — is worse than honest copy-paste.**
7. **Naming inconsistencies that hint at incomplete refactors** — mixed case conventions,
   two names for the same concept. Where the inconsistency points at an incomplete past
   refactor, flag it.
8. **Functions with 8+ arguments** — often a sign the function does too much, or that the
   arguments should be a config object.
9. **Files that have grown beyond their stated purpose.**
10. **Mid-file dead helpers** with no remaining callers. Grep each non-exported function and
    check the call sites.

**Important caveat.** Act as if this is a CRAN-published package with real users. Refactoring
for its own sake is dangerous — every refactor is a chance to introduce a subtle behavior
change the test suite might not catch. Flag opportunities aggressively but **recommend** them
only when all three hold: the refactor meaningfully reduces future bug surface; the
consolidation is genuine (the unified function is *simpler*, not just shorter); and the test
suite would catch a regression — if no such guardrail exists, recommend adding one *before* the
refactor.

Report structure: verdict; high-leverage consolidation opportunities (recommended, with
file:line and proposed shape); DRY violations not worth fixing (awareness only); god
functions worth splitting; parallel implementations correctly kept separate, with rationale;
naming inconsistencies pointing at incomplete refactors; helpers that should move; dead
helpers; what you did NOT verify.

---

## Agent output reliability

> **Orchestrator through the end of this section.**

A run once lost 2 of 5 agents on the first pass: they completed their analysis but never
emitted the final structured return and, having spent their budget, wrote no report file
either — so synthesis ran on three lenses and had to be redone. **The two that failed had
the longest briefs.** Three mitigations, all confirmed on the re-run:

1. **Tell each agent to WRITE ITS REPORT FILE FIRST**, before any final structured return.
   The file is the durable artifact; if the structured step then fails, synthesis can still
   read it off disk.
2. **Bound the reading scope.** "Read all of `R/` in full" exhausts the budget before the
   agent reaches its output step. Give a high-value read-in-full list and tell the agent to
   grep or skim the rest for the target patterns.
3. **Make the final structured-output call an explicit, non-negotiable last step.**

If an agent still returns nothing, **check whether its report file landed on disk before
re-running** — the file may be complete even when the structured return failed. Re-run only
the failed lenses, then re-synthesize from the full set.

---

## Step 2 — synthesize

> **Orchestrator:** what to do with the agents' reports once they land. None of it is briefed
> to anyone.
>
> Produce one consolidated review:
>
> 1. **Verdict** — one paragraph: overall assessment, count of real bugs vs lower-severity
>    findings.
> 2. **Real bugs, in priority order** — for each: severity (Major / High / Real-but-latent),
>    file:line, what's wrong and what the fix is, how to verify (with a link to the empirical
>    reproduction the agent ran, if any).
> 3. **Lower-severity findings**, grouped: soft bugs (latent or inconsequential under current
>    usage); dead and vestigial code; doc gaps; weak tests; API gaps and RFC-style items;
>    **structural and refactor opportunities flagged separately**, because those typically
>    warrant an RFC issue first to confirm the refactor is wanted before the work is done.
> 4. **Suggested action plan** — a proposed PR breakdown: one PR per bug, sweep PRs for
>    cleanup categories, honoring the repo's prioritization tiers.
>
> Then **ask the maintainer whether to draft issues.** If yes, write one
> `.plans/follow-ups/issue-draft-<topic>.md` per real bug, bundling small cleanups into
> category issues, matching the repo's existing draft convention.

## Step 3 — update the process docs

> **Orchestrator:** what to update after a run. None of it is briefed to anyone.
>
> 1. **The repo's prioritization doc** — if the review surfaced a pattern that should inform
>    future target selection, capture it as a heuristic.
> 2. **This skill.** If the review found the *same class* of issue three times across recent
>    PRs, that's a process signal, not just a bug list: it belongs as a new sentinel check, a
>    new reviewer anti-pattern, or a new entry in [lessons.md](../references/lessons.md).
> 3. **The repo's `.workflow/PROFILE.md`**, read against the thinness rules the template
>    states — a machine fact, or an explanation of what a gate command's output means, has
>    drifted in if it is there. Move what is general into the skill file that owns it. Nothing
>    detects this, and the profile is unversioned, so this pass is the only thing that looks.

## Files this cycle produces

> **Orchestrator through the end of this section.**

    .plans/code-review-{{DATE}}/
      00-synthesis.md                  (optional; often written in chat instead)
      01-core-bugs.md                  lens 1
      02-shared-machinery.md           lens 2
      03-api-and-practices.md          lens 3
      04-recent-additions.md           lens 4
      05-redundancy-and-structure.md   lens 5
      scratch/                         one subdirectory per lens agent, named for its report

Step 1 says why a brief must carry these names rather than derive one. That much is not
specific to this runbook: the per-PR cycle's own names are defined in one place, for the same
reason — `references/execplan.md`, search it for `Artifact names`. This section owns **only**
the review-run files above; nothing here names a per-PR artifact, and nothing there names one
of these.

Plus, when the maintainer opts in, a batch of `.plans/follow-ups/issue-draft-*.md`. All
under `.plans/`, which is gitignored.

**Retention: keep the most recent run, delete the rest.** The next run needs the prior one so
it doesn't re-litigate settled findings — that is the *only* reason to keep any of them. Once
a run's findings are filed as issues, GitHub carries them and the reports are spent; they are
also gitignored, so they are not a durable record in the first place. These folders are the
largest thing in `.plans/` by far in a repo that has been reviewed a few times, and nothing
else prunes them.

    ls -d .plans/code-review-* | sort | sed '$d' | xargs rm -rf

(`sed '$d'` rather than `head -n -1`, which is GNU-only and errors on BSD/macOS.)

Same for `.plans/follow-ups/`: a draft whose issue has been filed is spent. Delete it rather
than leaving two copies of the same text to drift.
