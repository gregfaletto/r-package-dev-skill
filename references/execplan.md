# ExecPlans

> **Derived work.** The ExecPlan concept and this document's structure — the non-negotiable
> requirements, the mandatory living-document sections, and the skeleton's section taxonomy —
> come from [`articles/codex_exec_plans.md`](https://github.com/openai/openai-cookbook/blob/main/articles/codex_exec_plans.md)
> in the OpenAI Cookbook, MIT-licensed, Copyright (c) 2025 OpenAI. See [NOTICE](../NOTICE).
> The R-package-specific half — the standard acceptance criteria onward — is original here.

## Contents

- [Non-negotiable requirements](#non-negotiable-requirements)
- [How to use plans](#how-to-use-plans)
- [Formatting](#formatting)
- [Guidelines](#guidelines)
- [Milestones](#milestones)
- [Living-document sections](#living-document-sections)
- [One section owns each load-bearing fact](#one-section-owns-each-load-bearing-fact)
- [Skeleton](#skeleton)
- [Artifact names](#artifact-names)
- [The standard acceptance criteria](#the-standard-acceptance-criteria)
- [Conventions every plan should encode](#conventions-every-plan-should-encode)
- [PR scope guidance](#pr-scope-guidance)
- [Failure modes a plan should pre-empt](#failure-modes-a-plan-should-pre-empt)
- [Idempotence with respect to upstream](#idempotence-with-respect-to-upstream)

---

An **ExecPlan** is a design document a coding agent can follow to deliver a working
change. Treat the reader as a complete beginner to the repository: they have only the
current working tree and this one file. There is no memory of prior plans and no
external context.

A plan is one of the files the cycle writes into `.plans/<branch>/`, gitignored and local-only.
[Artifact names](#artifact-names) below defines what each of them is called, for this file and
for every other file in the skill that has to name one.

## Non-negotiable requirements

- **Fully self-contained.** In its current form it contains all knowledge and
  instructions a novice needs to succeed. Do not point at external blogs or docs; if
  knowledge is required, embed it in your own words. If the plan builds on a prior plan
  that is checked in, incorporate it by reference; if it is not checked in, include all
  relevant context.
- **A living document.** Revise it as progress is made, as discoveries occur, and as
  decisions are finalized. Each revision must remain self-contained. It must always be
  possible to restart from *only* the ExecPlan.
- **Produces demonstrably working behavior**, not merely code changes that "meet a
  definition."
- **Defines every term of art in plain language**, or does not use it.

## How to use plans

- **Authoring:** follow this document to the letter. If it isn't in your context, re-read
  it. Start from the skeleton and flesh it out as you research; be thorough in reading
  and re-reading source material.
- **Implementing:** do not prompt for "next steps" — proceed to the next milestone.
  Keep all sections up to date. Resolve ambiguities autonomously and commit frequently.
- **Discussing:** record decisions in the `Decision Log`. It should be unambiguously
  clear why any change to the specification was made.
- **Researching something hard:** use milestones to build proofs of concept and toy
  implementations that validate feasibility before committing to a full design. Read
  the source of the libraries involved.

## Formatting

A plan is the whole content of its own file, so it carries **no outer code fence**. Do not
nest triple-backtick fences inside it either: present commands, transcripts, diffs, and code
as **indented blocks**, so that nothing in the plan can prematurely close a fence when it is
quoted into a chat message or a review brief.

Two newlines after every heading. Correct `#`/`##` nesting and correct list syntax.

**Write in plain prose. Prefer sentences over lists.** Avoid checklists, tables, and long
enumerations unless brevity would obscure meaning. Checklists are permitted only in
`Progress`, where they are mandatory. Narrative sections stay prose-first.

## Guidelines

**Purpose and intent come first.** Open by explaining, in a few sentences, why the work
matters from a user's perspective: what someone can do after this change that they could
not do before, and how to see it working.

**Define your jargon.** If you introduce a phrase that is not ordinary English, define it
immediately and say how it manifests in this repository — name the files or commands where
it appears. Statistical packages are dense with such phrases, and each one is invisible to
the author and opaque to everyone else: "bridge regression", "fusion transform", "weave",
"prototype", "nuisance parameter", "influence function" all read as ordinary vocabulary if
you wrote the paper.
Never write "as defined previously" or "per the architecture doc."

**Anchor on observable outcomes.** Acceptance is behavior a human can verify — "after
`library(pkg); ?fn` opens, the help page documents the new `min_se` argument with a
worked example" — not internal attributes ("added a `min_se` roxygen block"). For an
internal change, explain how the impact is still demonstrable: tests that fail before and
pass after, plus a scenario exercising the new behavior.

**Never write down the number of places something occurs,** e.g. "Nine call sites", "the two
test files", "four of the six routes." It quickly goes stale and has little to no value in the
best case. Correcting one costs a review round spent on documentation about documentation.

This is about counting occurrences, not about numbers. Measured results of a run — `FAIL 25`,
`PASS 4104`, a gate status line — are governed by criterion 17. A figure something *checks*
also stays: a recorded baseline, a pinned version, a hash. Those cannot rot unnoticed, because
the check failing is how you find out. A budget is not a tally either: `≥ 50 lines`,
`~400 words` bound a size rather than count a set, and it moves only when someone moves it.

**Name the predicate, not the cardinality.** "The call sites that still read `$`" stays true
and is greppable; "the eight call sites that still read `$`" is wrong the moment one is fixed.
The same applies to anything you are recording for later — say what to look for, not how many
there were.

**Then separate what you have verified from what you are predicting.** A plan makes claims of
several kinds, and they are not all checkable while you are writing it:

- **Repository facts** — this function exists, this file has that line, this argument is
  never passed. Verifiable *now*, **by reading**. Verify them; they are cheap and they hold
  up *where something downstream depends on them*. Where nothing does — a count written into
  a prose comment — they go wrong as readily as anything else, because cheap-to-check and
  actually-checked are different properties.
- **Mechanism claims** — *why* existing code behaves as it does. These checks must be ordered
  this way because a character argument compares as a string; a length-2 argument recycles
  across the columns; this guard prevents overwriting the previous cluster. Verifiable now as
  well, but **only by running**. They are the dangerous category because they read like
  repository facts: they are about code already sitting in the tree, so they feel like
  something you could look up rather than something you have to execute. **If you are
  asserting *why*, run it.**
- **Behavioral predictions** — this check will emit that NOTE, this command will report six
  runs, this diff will be one line, this job will take two hours. **Not verifiable until you
  run the thing**, and far more likely to be wrong than you expect. The shapes that recur: a
  NOTE that turns out structurally impossible, a count off by one, a diff size off by an order
  of magnitude, a runtime overestimated several-fold, a grep returning 0 where you expected 6,
  and an absence of output reported as a measurement.

Write predictions *as* predictions — "expected, unverified" — and keep them out of the
sections an executor treats as instructions.

**Never arm an acceptance criterion on an unverified prediction.** A criterion reading
"expect exactly 26 URLs; any deviation is a blocker" halts the executor on a *correct* result
when the 26 was a guess. If a prediction is load-bearing, either measure it before the plan
ships, or make the criterion **structural rather than numerical** — "no removed lines in
`README.Rmd`" survives being wrong about the count in a way that "exactly 26" does not.

**When you revise a rule, check that the revision still discriminates.** Replacing a vague
phrase with a precise number feels like tightening and is sometimes the opposite: one plan
swapped "perturb meaningfully" for "perturb by 10× the tolerance," which is vacuous by
arithmetic for *every* tolerance. Vague-but-correctly-aimed beats precise-but-vacuous. Ask
what input the new rule *rejects* that the old one accepted.


**Avoid the common failure modes.** Undefined jargon. Describing "the letter of a feature"
so narrowly that the code compiles but does nothing meaningful. Outsourcing decisions to
the reader — when ambiguity exists, resolve it in the plan and explain why. Err toward
over-explaining user-visible effects and under-specifying incidental implementation.

## Milestones

Milestones are narrative, not bureaucracy. Introduce each with a paragraph describing the
scope, what will exist at the end that did not before, the commands to run, and the acceptance
you expect to observe. Never abbreviate a milestone for brevity's sake.

Each milestone must be **independently verifiable** and must incrementally implement the
overall goal.

**Prototyping milestones are encouraged** when they de-risk a larger change — validating
that an upstream API returns the matrix shape you assume before wiring it in, or comparing
two weighting schemes on synthetic data before committing to one. Label the scope as
prototyping, describe how to run and observe it, and state the criteria for promoting or
discarding it. When working with multiple new libraries or feature areas, spike each
*independently* so you prove the external library does what you need in isolation.

Prefer additive changes followed by subtractions that keep tests passing. Parallel
implementations (a deprecated argument kept at a `NULL` default alongside its replacement
during a one-version deprecation cycle) are fine when they reduce risk. Describe how to
validate both paths and how to retire one safely.

## Living-document sections

These are **mandatory** and must be kept current:

- **`Progress`** — checkboxed granular steps. Every stopping point is documented, even
  if a partially-completed task must be split into "done" vs "remaining." Timestamps let
  you measure rate of progress.
- **`Surprises & Discoveries`** — unexpected behavior, performance trade-offs, upstream
  API surprises, test-fixture quirks that shaped your approach. Include short evidence
  (test output is ideal).
- **`Decision Log`** — every decision, with rationale and date/author. If you change
  course mid-implementation, the reason goes here and the implications go into `Progress`.
- **`Questions for the Maintainer`** — every question you put to them, entered when you
  put it, and what became of it. **A question is not a decision**, so it never goes in the
  `Decision Log`: that section is what a reviewer reads to check what was *authorised*, and
  an entry there saying nobody answered muddies the one lookup it exists for. Criterion 20
  owns the entry shape and the dispositions.
- **`Outcomes & Retrospective`** — at each major milestone and at completion: what was
  achieved, what remains, lessons learned, measured against the original purpose.

When you revise a plan, update the section that **owns** each affected fact, follow the
pointers to anything that names it, and write a note at the
bottom describing the change and why.

---

## One section owns each load-bearing fact

A plan has many sections and it is natural to restate a decision in each one that touches it —
the purpose paragraph, the milestone, `Interfaces and Dependencies`, the `Decision Log`, the
acceptance criteria. Do not. **Decide which section owns each load-bearing fact and have the
others name it rather than restate it.**

The cost is not length, it is that **every later change becomes an n-place edit** — and the
author greps for the text they just changed rather than for the fact it describes, so one copy
survives. That is how a milestone gets rewritten while `Interfaces and Dependencies` keeps
declaring the signature it abandoned, which an executor treats as prescriptive.

**The signal is a fact appearing in a third section**, not a line count. Two copies may be
deliberate; a third means nobody owns it. When you notice one, pick the owner and cut the rest
to a pointer — the same move this skill applies to itself.

## Skeleton

    # <Short, action-oriented description>

    This ExecPlan is a living document. The sections `Progress`, `Surprises &
    Discoveries`, `Decision Log`, `Questions for the Maintainer`, and `Outcomes &
    Retrospective` must be kept up to date as work proceeds. It is maintained in
    accordance with the `r-package-dev` skill's ExecPlan reference.

    ## Purpose / Big Picture

    A few sentences on what someone gains after this change and how they can see it
    working. State the user-visible behavior you will enable. If this PR resolves an
    issue whose scope was clarified in chat, paste the clarified-scope paragraph here
    verbatim.

    ## Progress

    - [x] (2026-08-09 13:00Z) Example completed step.
    - [ ] Example incomplete step.
    - [ ] Example partially completed step (completed: X; remaining: Y).

    ## Surprises & Discoveries

    - Observation: …
      Evidence: …

    ## Decision Log

    - Decision: …
      Rationale: …
      Date/Author: …

    ## Questions for the Maintainer

    - Question: … (as you put it to them)
      Asked: 2026-08-14 (re-asked 2026-08-19)
      Disposition: OPEN

    ## Outcomes & Retrospective

    Summarize outcomes, gaps, and lessons at major milestones or at completion. Compare
    the result against the original purpose.

    ## Context and Orientation

    The current state relevant to this task, as if the reader knows nothing. Key files
    and modules by full path. Every non-obvious term defined. No references to prior
    plans.

    ## Plan of Work

    In prose: the sequence of edits and additions. For each, name the file and location
    (function, module) and what to insert or change. Concrete and minimal.

    ## Concrete Steps

    Exact commands and where to run them. Where a command produces output, show a short
    expected transcript. Update as work proceeds.

    ## Validation and Acceptance

    How to exercise the system and what to observe. Acceptance phrased as behavior, with
    specific inputs and outputs. For tests: "run <command> and expect <N> passed; the new
    test <name> fails before the change and passes after."

    ## Idempotence and Recovery

    Which steps repeat safely. For risky steps, the retry or rollback path. Leave the
    environment clean.

    ## Artifacts and Notes

    The most important transcripts, diffs, and snippets as indented examples.

    ## Interfaces and Dependencies

    Be prescriptive. Name the packages, files, and functions to use and why. Specify the
    signatures, S3 methods, and roxygen tags that must exist at the end of each
    milestone. For example:

    In R/fetwfe.R, define an additional argument on the public `fetwfe()` function:

        fetwfe <- function(pdata, time_var, unit_var, treatment, response,
                           covs = c(), indep_counts = NA, sig_eps_sq = NA,
                           q = 0.5, verbose = FALSE, alpha = 0.05,
                           add_ridge = FALSE,
                           min_se = 0)         # <-- new
        { ... }

    The constructor carries roxygen `@export`, a new `@param min_se` block, and an
    updated `@examples` block. Internal helpers get `@keywords internal` + `@noRd`.

ExecPlans describe not just the *what* but the *why* for almost everything.

---

## Artifact names

The plan is one file in a folder the whole cycle writes into. **This section is where every
name in that folder is defined, and it is the only place any of them is defined.** A brief, a
checklist, a runbook, or a criterion that needs one points here instead of restating it: a name
stated in two places and corrected in one is worse than a name written down nowhere, because
the corrected copy makes it look settled.

Everything below sits in `.plans/<branch>/`, is gitignored, and is deleted when the PR merges.

| Artifact | Name | Written by |
|---|---|---|
| The ExecPlan | `plan.md` | the orchestrator |
| Plan-review findings | `plan_review.md` | the planning reviewer |
| The author's response to them | `plan_review_response.md` | the orchestrator |
| Drift check before any code is written | `sentinel_pre.md` | the drift sentinel |
| The author's response to it | `sentinel_pre_response.md` | the orchestrator |
| Drift check on the diff, before the push | `sentinel_post.md` | the drift sentinel |
| The author's response to it | `sentinel_post_response.md` | the orchestrator |
| Post-execution review findings | `post_execution_review.md` | the post-execution reviewer |
| The author's response to them | `post_execution_review_response.md` | the orchestrator |
| PR title and body, before it is posted | `<branch>_pr_description.md` | the orchestrator |
| One subagent's working files | `scratch/<role>/` | that subagent |

`<role>` is the subagent's own name, spelled as its brief spells it — `plan-reviewer`,
`implementer`, `sentinel`, `post-exec-reviewer`. A subagent creates its directory, writes only
inside it, and deletes only it.

**A later round appends `_v2`, `_v3`, … to the base name and never overwrites an earlier
round** — `plan_review_v2.md`, `sentinel_post_v2.md`, `post_execution_review_v2.md`,
`scratch/sentinel-v2/`. A response is versioned off the round it answers, so round 2's
dispositions go to `plan_review_v2_response.md`, `sentinel_post_v2_response.md` and
`post_execution_review_v2_response.md`. Criterion 14's disposition sweep greps this folder: a
round-2 file written over round 1's takes round 1's deferred items out of the sweep's reach and
leaves nothing behind to say they ever existed.

**Each pass's findings get their own response file, whoever writes the dispositions.** Folding
the sentinel's into the sibling reviewer's response is what a cycle reaches for when one agent
answers both at once, and the dispositions written that way are real work done right. What the
fold costs is reach: the sweep above and the post-execution reviewer's missing-artifact check
both look for a file by name, and neither reads prose sitting inside a sibling's. So write the
reasoning once and cite it from the second file if you like — but write the second file, since
after this row exists its absence reads as a missing artifact rather than as tidiness. **A pass
that found nothing is answered in one line** — a `Verdict: CLEAN` leaves nothing to
disposition, and its response exists so that the sweep and the missing-artifact check have a
name to find, not because there is reasoning to record.

**`_v#` means a further round of the same artifact, and nothing else.** The sentinel's
pre-implementation and post-implementation passes are different work rather than two rounds of
one thing, so they carry different base names instead of sharing one — both belong to a normal
cycle, and neither implies the other was redone. Overloading a suffix that also counts rounds
is not a labelling nicety: while the post pass was spelled as the pre pass's round 2, every
re-check that followed it numbered itself one behind the file it was written into, and one
folder ended up holding a file whose name said round 3 and whose heading said round 4.

**A role that runs a second time on the same stage is the next `_v#` of its own artifact**,
whoever spawned it and however the second one was briefed. Naming a file for the agent that
asked for it — `..._orchestrator.md` — or for the question it was asked to settle —
`audit_<topic>.md` — hides it from the sweep, from the missing-artifact check, and from the
next reviewer told to read the highest-numbered round. Both spellings feel more informative
than a version number, which is why both keep getting written; a name this section does not
define is a name nothing downstream looks for, and how informative it reads does not change
that. The topic belongs in the file's heading, where naming it costs nothing.

**A name an agent reaches for unprompted is the name that survives.** Each of these was chosen
against what real cycles actually wrote, and where a prescribed name and a produced name
disagreed, the produced one won. That is also why every brief states its own output name
outright rather than deriving it from the plan's basename or from its own heading: a name the
reader has to construct is a name some readers construct differently, and the plan-review
findings landed under a different spelling in cycle after cycle because of it.

---

## The standard acceptance criteria

Every PR is expected to leave the package CRAN-ready. Include these in the plan's
`Validation and Acceptance` section verbatim or close to it. Substitute the profile's
actual commands where the shape differs (for example, a litr package builds from a
source `.Rmd` and passes `document = FALSE` to `check`).

**The plan's copy localizes a criterion; it never replaces it.** What a copy adds is this PR's
own items under it — the named test file whose non-regression this diff has to re-run — and
what gets worked is still the criterion as written here. A shortened copy drops whatever the
person copying did not think to include: a hand copy of criterion 17 kept the opening
instruction and the checklist's first items and dropped the rest, including the part that
would have caught the defect that shipped.

1. **`devtools::check(error_on = "note")` exits cleanly — `0 errors ✔ | 0 warnings ✔ | 0 notes ✔`.**
   This is the unconditional per-PR gate — not just for release-flavor PRs. Plain
   `check()` is implied. **A package that is not already clean cleans up first, as its own
   PR** — do not weaken this criterion to accommodate a dirty baseline, because a criterion
   that fails on the base tree can never fail *because of* your change. The only permitted
   exceptions are the ones the profile's § 3 records by name, with a reason and a date: an
   irreducible installed size, the `unable to verify current time` flake. **That accepted
   exceptions list and nothing new** — anything else is a finding.

2. **`devtools::spell_check()` finds nothing — `nrow(devtools::spell_check()) == 0`.**
   Assert the row count, not the output.
   **Bar and triage: `cran-gate.md` — search it for `spell_check()`.**

3. **`urlchecker::url_check()` flags nothing beyond the profile's accepted exceptions list.**
   Judge the set and the statuses, **never the count**. A URL *you* add that fails is
   always a blocker.
   **Bar and triage: `cran-gate.md` — search it for `url_check()`.**

4. **Vignette rebuild is covered by `check()`** — no separate gate. If
   vignettes changed *and* you want to inspect rendered HTML, use
   `tools::buildVignettes(dir = ".")`. (`devtools::build_vignettes()` still exists but has
   been soft-deprecated since devtools 2.5.0. The two are not equivalent: the devtools
   version additionally copies outputs into `doc/` and builds the vignette index, so use it
   if you want that.) Optional, not gating.

5. **All tests pass, and new tests fail before the source change and pass after.**
   Confirm from the `[ FAIL n | … ]` summary line, never from an empty failure-grep.
   **`WARN` and `SKIP` on that line are part of the criterion**, each at the count in the
   profile's accepted exceptions list — quote the numbers rather than skipping past them.
   "Pre-existing" is a disposition owed to criterion 14, not a reason to stop reading the line.
   **Bar and triage: `cran-gate.md` — search it for `Any new skip is a finding`.**

   **A suite-level count is an observation, not an assertion.** A number that moves because
   the source changed is not evidence that any assertion *observes* the change. The red side
   is discharged by reverting the **source** hunks against the final test file and naming
   which assertion fails — if none does, the criterion is not met however the counts moved.
   One cycle's acceptance evidence was `WARN 64 → 0` with the suite green, and reverting both
   source-side arguments would have left **every assertion green**, because nothing in the
   suite referenced the warning the fix silenced. Five review passes accepted it; a human
   caught it.

   **Re-measure the red side against the *final* test file.** A red-green count taken at the
   implementation commit goes stale the moment a review round adds an assertion — and it goes
   stale silently, because the green side and the suite total both stay correct. If the test
   file changed after you measured, measure again:

       git archive <base-sha> | tar -x -C <tmp> && cp tests/testthat/<new-test>.R <tmp>/tests/testthat/

   then run the suite there. A number in the PR body that was true two commits ago is stale
   evidence presented as current evidence.

6. **`devtools::document()` is idempotent** — running it twice produces no diff. The
   regenerated `man/*.Rd` and (if exports changed) `NAMESPACE` are staged in the same
   commit as the source change.

7. **A PR with a user-visible change has a `NEWS.md` bullet under the development header**,
   and the version is a development version — in `DESCRIPTION`, or wherever
   the profile's § 4 **Version lives in:** names. **A purely internal PR — a refactor with
   no user-visible change, a doc fix, dev tooling — needs neither, but says so in this plan
   and in the PR description** — the plan because the post-execution reviewer runs before a
   PR description exists, the PR description so the maintainer can confirm the judgment
   rather than assume the step was skipped. **Bullet form, the `.9000` bump, when the bullet
   is written, and what waits for submission time: `git-and-pr.md` — search it for
   `NEWS.md`.**

8. **`inst/CITATION` reports the right version — structurally, not by hand.** `CITATION` is
   evaluated with `meta` bound to the package's `DESCRIPTION` metadata, so

       note = paste("R package version", meta$Version)

   cannot drift. **If the repo hard-codes the version string instead, fix that first** — it
   deletes this criterion and the recurring finding behind it. Until it is fixed, the
   hard-coded string must be updated in the same commit as the version bump —
   `inst/CITATION` is the one that gets forgotten, because it is the one nobody opens. Skip
   entirely if the repo has no `inst/CITATION`; the profile says which.

9. **Every declaration named in `Interfaces and Dependencies` appears in
   `git diff origin/main` with a matching signature, and no unplanned exports appear.**

10. **The plan's `Surprises & Discoveries` / `Decision Log` / `Outcomes & Retrospective`
    are current** with any deviation from the original plan.

11. **If the change touches the domain math or the behavior the authority document
    specifies, the PR description (or a comment in the affected source file) cites the
    exact equation, lemma, or section** it implements. **The comment form is a line that
    cites** — the equation's address, not a paragraph restating what it says. A restatement is
    a second copy of the authority document, kept where nothing checks it against the original.

12. **PR title and body drafted** in the PR-description file
    [Artifact names](#artifact-names) defines, under `# Suggested title` / `# Suggested body`
    headings, **rewritten to match the branch's final scope**. Only the text under
    `# Suggested body` becomes the PR body.

13. **Post-execution review subagent and drift sentinel invoked before pushing.** The
    implementation is already committed on the branch by this point; nothing is published
    until both converge. **Every round of every pass leaves a findings file and the author's
    response beside it**, under the names [Artifact names](#artifact-names) defines — round 2
    owes a response as much as round 1 does, and the sentinel owes one as much as its sibling
    does. Blockers fixed in follow-up commits on the same branch, convergence (no blockers)
    reached before the PR opens. **What may be downshifted for a small change, and what may
    not, is the skill's downshift table — this criterion does not restate it, and dropping a
    stage outright is the maintainer's call rather than the orchestrator's.** (The
    post-execution review is on the never-downshift side of that table: it is the only pass
    that always reads the diff.)

14. **Every deferred item ends the cycle with a definitive disposition** — (a) file an
    issue, (b) don't defer, or (c) drop with reasoning; no fourth limbo option, captured in
    both the PR description and a separate chat message. The sweep is greppable:

        grep -rniE "out of scope|follow-?up|defer|future PR|future RFC|back burner|pre-?existing|already (there|present)|not (mine|ours|this PR)" .plans/<branch>/

    **"Pre-existing" is a disposition, not an exemption.** It is the most dangerous phrase in
    this list because it does not read as a deferral — it reads as a *resolution*, so it leaves
    the cycle without ever entering the sweep. The first cycle to observe a pre-existing defect
    **files it** (disposition (a)); every later cycle **names it and quotes its current
    count**, so drift is visible. One suite's leaked warnings sat behind "pre-existing, `main`
    reports the same" in cycle after cycle while the count climbed from 58 to 64 with an issue
    already open the whole time — nobody was lying, and nobody was watching either.

    The strictness is earned: one item was flagged "low priority, defer" in three consecutive
    periodic reviews before anyone closed it, and another was raised by both reviewers of a PR
    and survived only as a parenthetical at the end of a thirty-line wrap-up. Indefinite
    phrasing — "future follow-up," "natural file-touch opportunity" — is limbo dressed as a
    decision.

15. **Queue upkeep.** If the PR closes an issue, remove its line from the repo's queue
    doc; if the head order shifted, re-rank in the same pass.

16. **Plan-artifact cleanup — promote, then delete.** `.plans/` is working state, not a
    record. It is gitignored, so it lives on exactly one machine with no backup: anything
    simultaneously too cluttered to track and too valuable to lose is in an incoherent
    position. Resolve it by promoting what is durable, then deleting the rest.

    Promotion paths, all of which already exist:

    - A lesson any R package could hit → the skill's own failure-mode catalogue.
    - A gotcha specific to this package → `.workflow/PROFILE.md` § Gotchas.
    - A deferred item → a GitHub issue, per the (a)/(b)/(c) trichotomy in criterion 14.
    - A finding about the codebase → a GitHub issue.

    **The test is "has everything durable been promoted?", not "how old is this?"** When the
    answer is yes, the folder is spent: `rm -rf .plans/<branch>/` when the PR merges or the
    branch is abandoned, and sweep `.plans/` for already-merged branches at the *start* of
    each cycle. Do not keep a distilled summary — the PR body, `NEWS.md`, and the filed
    issues already are one, and a fourth copy is the drift problem this workflow exists to
    prevent.

17. **Every claim a command settles, re-derived at the final commit — as a list, not a
    glance.** Review findings land in follow-up commits *after* the post-execution review has
    run, so no reviewer has checked them yet. Checking *some* of them is the
    failure mode: one cycle re-verified its call-site counts and not its suite total, and the
    suite total was the stale one; another re-derived the gate, said out loud it would
    re-derive the red side, and did not.

    **The boundary is whether a command settles it, not whether it holds a number.**
    "Mutating the sort fires `A1`, `A3` and `A6`", "this test covers the length-2 case",
    "nothing else regressed" are each a measurement someone declined to take, and they are
    what actually ships wrong: in the cycles behind this rule every defect was a false claim
    in prose rather than wrong code, and each was caught by running the mutation, never by
    rereading the sentence. **Prefer deleting such a claim to re-deriving it** — a test-file
    header says what the file is for, and which assertions a mutation fires belongs in the PR
    body beside the run that produced it. A claim no command settles — a rationale, a
    judgement, a prediction — cannot go on this list at all: write it as what it is,
    attributed or marked unverified, never flat.

    **Re-running the same command is not re-deriving.** A figure that depends on session state
    — `object.size()` on a fitted object is the case that bit — reproduces perfectly from a
    fresh session, so a repeat *confirms* an unstable number rather than testing it. Vary the
    order or the surrounding work, and if the figure moves, delete the claim rather than
    substituting a better number: the movement is the finding. A timing is the same rule from
    the other side — there the movement is expected, so averaging it is only substituting a
    better number under another name, and successive passes reporting 16.4%, 16.7% and 18.8%
    for one cell have measured that the claim's precision exceeds the method's, not that the
    answer is 17%.

    **A measurement copied into a comment, a header, `NEWS.md` or the PR body has a shelf life
    of one commit.** It was taken against a tree, and any later commit on the branch can
    falsify it without touching the sentence — so the list above reconciles the copies, by
    `grep` over the branch's touched files for the number, the assertion names and the file
    names, rather than only re-running the command. **If two copies of a claim disagree, that
    alone is a finding**, and cheaper to spot than checking either copy on its own.

    **Write the measured value next to each item, not a tick.** A box you check yourself is
    unfalsifiable from the inside — it records that you intended to, which is the same
    conflation as accepting a review finding versus applying it. A pasted number is a claim
    someone else can re-run.

    - [ ] red-side count, against the **final** test file, not the one you first measured
    - [ ] green-side count and the full-suite total
    - [ ] gate status line, and any note you called environmental
    - [ ] every file, site, or occurrence count you quoted, and anything written as "N of M"
    - [ ] the PR body's own word and section count
    - [ ] every claim about what a test, an assertion, or a guard **covers** — re-run the
          mutation against the final tree, write on **this list** which assertions went red,
          then find every place that figure is already stated: delete any copy in a comment or
          roxygen, and reconcile the rest against it. Re-running proves the figure; reconciling
          catches the copy that has gone stale, and that is the half people skip
    - [ ] the **shipped** wording of a coverage claim you are correcting a second time — in a
          comment or roxygen, delete it; in the PR body or `NEWS.md`, change its **form**
          rather than its content, so it states the rule the assertions enforce, positively
          and once, with no enumeration left to be wrong; then measure the new form too
    - [ ] every "nothing else changed" — no regression, no other caller affected — run on
          both trees, rather than recalled from the run that produced the change
    - [ ] **anything you took from a reviewer rather than measured yourself**, before it
          enters the plan, the code, or the PR body. Not just its *findings* — its
          **recommendations** too, and any **code it proposes**. "Use `helper()` instead of
          hand-rolling it" is the right principle and may still be the wrong helper, and an
          assertion a review hands you may be one that cannot fail:
          `expect_true(is.list(x))` passes on a `data.frame`, because a `data.frame` **is** a
          list, so it green-lights exactly what it was written to catch. Run it against that
          thing before you adopt it. Each arrives with the authority of a review, and none of
          them is a measurement you made.

    **The list is not all the final commit owes: read the text your commits landed in.**
    A diff shows what changed and hides what the change now sits beside, so a hunk correct
    against the brief it was written for can restate the paragraph above it or name a
    mechanism this file already calls something else. The trigger is mechanical —
    `git log --oneline origin/main.. -- <path>` naming more than one commit — and what you
    read is the unit its reader arrives at whole, start to finish: the rendered help page,
    the development section of `NEWS.md`, the enclosing `##` section of a prose file.
    Record, for each, **where that text already covers what you added**: a lookup, not a
    recollection, and "nowhere" is an answer someone else can grep. The edits behind this
    paragraph were each made against a brief narrower than the file they landed in, and the
    defects had no other shape — a term introduced under a second name, a hazard restated
    without its mechanism, a bar asserted a few lines from the sentence disclaiming it.

18. **PR body within budget, counted rather than judged.** `wc -w` and `grep -c '^## '`:
    ~400 words, **at most three `##` sections**, per
    [git-and-pr.md](git-and-pr.md#pr-description-style). Overflow is almost always the gate
    transcript, the review narrative, or a restatement of the diff — all already in
    `.plans/<branch>/`, none of which change a merge decision. **Re-count after every edit to
    the body** — a body trimmed to budget once and then refreshed twice more drifts back over
    it, and the count from the first trim is what gets quoted.

19. **Every durable finding gets exactly one home — and "none" is the default.** A cycle that
    taught you something ends with the same kind of decision as a deferred work item, and the
    options are ranked:

    - **(a) A check.** A gate, an acceptance criterion, a reviewer or sentinel bullet. Always
      preferred: a lesson that is only written down recurs anyway, and the check fires whether
      anyone read it or not.
    - **(b) A profile gotcha.** Specific to this package and expensive to re-derive. The
      test: would this sentence still be true in a different R package? Then it is (a) or
      (c), and what goes in the profile is the one clause naming the repo fact that makes it
      bite here.
    - **(c) A lesson** in the skill's catalogue. What you write when it applies to any package
      **and** you cannot mechanize it. A lesson is an admission that no check exists, not a
      trophy.
    - **(d) Nothing.** The default. Most of what a cycle surfaces was surprising once and will
      not recur.

    **Before (c), ask: does this replace something, or only add to it?** If only add — is the
    failure it guards against worth the line, given that every future reader must get past it
    to reach everything else? The catalogue grew by a third in one week under exactly this
    pressure, and nothing but a deliberate prune ever reversed it. Adding to a shared document
    is a cost paid by everyone who reads it afterward, forever; the finding has to be worth
    that.

20. **Every question you put to the maintainer ends the cycle with a dated disposition, and
    "no answer" is one of them.** Entries live in the plan's `Questions for the Maintainer`,
    one per question, whatever stage you were in when you asked — clarifying scope, answering
    a review round, closing the loop. **Write the entry in the same action as asking.**
    Asking now and recording later is the failure this criterion exists to prevent, and it has
    already happened to a section that *is* read: a stage downshift stated plainly in chat
    never reached the `Decision Log`, whose only downshift entry was dated the day before and
    said "no downshift", so a reviewer following its instructions concluded the full pass ran.

        - Question: <as you put it to them>
          Asked: 2026-08-14 (re-asked 2026-08-19)
          Disposition: OPEN

    **Re-asking appends a date to the entry you already have.** A second entry for the same
    question is how "asked three times" comes to read as three unrelated asks, each of which
    is easy to let go on its own.

    Dispositions, each carrying the date it was reached:

    - **Answered** — the answer, in a sentence. If it changed the plan, the decision goes in
      the `Decision Log` and this entry names it rather than restating it.
    - **Withdrawn** — the work settled it, or it stopped mattering. Say what settled it.
    - **Unanswered — proceeded on `<assumption>`** — asked, no answer, and this is what the
      cycle assumed instead. Where something already built depends on the answer, say what
      the other answer would have changed.

    **`Unanswered` is a legitimate ending, and it has to stay cheap.** Make an answer the only
    acceptable outcome and the next agent stops asking, or quietly demotes the question into
    an assumption nobody can see — strictly worse than today, where the question at least gets
    asked out loud. What may not survive the handoff is `OPEN`. The sweep:

        grep -nE "Question:|Disposition:" .plans/<branch>/plan.md

    Read the output as pairs. A `Question:` with no `Disposition:` under it is an entry nobody
    finished; any `Disposition: OPEN` is a question the handoff was about to swallow.

    **Every `Unanswered` entry goes in the handoff chat message**, beside criterion 14's
    disposition sweep, in the words the question was put — that message is the only thing that
    makes the silence visible to the person who was silent. It goes in the PR description as
    well **where the assumption is load-bearing for the change being merged**, and not
    otherwise: criterion 18's budget is real and most assumptions do not change a merge
    decision.

    **At cleanup, an entry still `Unanswered` is a deferred item like any other** and takes
    criterion 14's (a)/(b)/(c). That is the way out of asking into a void across cycles: a
    question filed as an issue is one the next cycle meets among the repo's open issues, at
    the start of the session, instead of re-asking it.

    Nine questions across two runs went unanswered, and every one vanished into chat
    scrollback. The two that would have bounded the work were the two asked more than once — a
    scope question asked twice, and a cleanup sweep asked three times across both runs.
    **Re-asking is what an unanswered question does instead of being recorded**, and it is
    invisible from inside: nothing in either run held two asks of one question in one place.

**Deferred to CRAN-submission time, not per-PR gates:** `devtools::check_win_devel()` and
`check_mac_release()` (slow remote round-trips), `revdepcheck::revdep_check()` (only
meaningful with reverse-deps and an imminent release), and the `cran-comments.md` rewrite.

---

## Conventions every plan should encode

Adhere by default; call out any deviation in the `Decision Log`.

**Export policy.** The *classification* below is the same in every object system; the
*mechanism* for making something public is not — S4 needs `exportClasses`/`exportMethods`
plus `export()` for the generic, R6 exports only the generator, S7 needs
`methods_register()` in `.onLoad`. See [object-systems.md](object-systems.md), and name the
registration mechanism (not just the signature) in `Interfaces and Dependencies`.

Classify each new function up front as one of:

- *File-local helper* — used only inside one `R/*.R` file. No `@export`; use
  `@keywords internal` + `@noRd`.
- *Cross-file internal* — used in several files but not public. No `@export`; other files
  reach it through the package namespace.
- *Public API* — a function users call directly. `@export` plus complete roxygen
  including `@examples`. Confirm the new export is consistent with the profile's stated
  public surface, and **bring that surface with it**: updating the profile's § 8 is part of
  this plan's deliverable rather than a later tidy-up, because § 8 is the list the
  post-execution review checks unplanned exports against, and an export landed without it
  leaves that check reading a list that predates the change. **Re-derive § 8 with the
  command § 8 itself names; never type it.** A new `Imports:` or `Suggests:` entry owes
  § 10 the same treatment, derived the same way — a stale dependency list disarms the
  reviewer's unguarded-`Suggests:` check.

When in doubt: `grep -rn "<function_name>" R/ tests/ --include="*.R"` to enumerate callers
before deciding.

**Roxygen on every function.** Public or internal, every function in `R/` gets a roxygen
block with a one-line title, `@param` for each argument, and `@return`. Public functions
add `@examples` with runnable code (`\donttest{}` only when the example exceeds CRAN's
time budget — bias toward fast, runnable examples). Internal helpers add
`@keywords internal` + `@noRd`, and may take a shared argument's `@param` from a sibling
with `@inheritParams`.

*Exception:* S3 methods registered for another package's generic (`print.foo`,
`summary.foo`, `coef.foo`) carry only `#' @export`. The parent generic owns the
`@param` / `@return` contract; restating it in slightly different words is a cosmetic
finding. This applies only to method registrations, not to internal helpers that happen
to share the file.

**Direct tests for what the plan adds.** For every function this plan adds — under `tests/`
as well as `R/` — that no test calls directly, ask what a wrong-in-the-quiet-direction bug in
it would do to the tests that *do* reach it. If they would still pass, it needs a direct test,
or a stated reason it does not. The quiet direction is the one that makes a check see less: a
primitive that under-reports makes the guardrail built on it find fewer sites, and a guardrail
that finds fewer sites passes.

The case this exists for is a `tests/testthat/helper-*.R` primitive — auto-sourced across the
whole suite, its own contract asserted nowhere, exercised only through the assertions of tests
aimed at something else. Keep the answer to one clause per function, a test name or the reason
there is none, so that a plan adding many of them still answers in a sentence apiece.

**Error style, verbose output, formatting, indentation** — the profile states these.
Don't introduce a new error-handling library or a second formatter mid-stream.

**Version bookkeeping is part of the deliverable.** Any plan changing user-visible
behavior includes the `NEWS.md` bullet, the version bump, and the `inst/CITATION`
update as explicit steps.

## PR scope guidance

The default is **one bug fix or one self-contained feature per PR**. Process docs,
planning artifacts, and personal workflow notes are gitignored and should not appear in
PR diffs at all.

Past roughly **250 lines** of source (excluding regenerated `man/*.Rd`), stop and ask the
question explicitly — but a large diff is not itself the finding.

Note the genuine tension with fixing the bug *class* rather than the instance: it means
fixing every site the pattern appears, which legitimately produces a bigger diff than fixing
the one instance you tripped over — and that is the right call. A 220-line PR that applies
one guard at every door it belongs on is one logical change; a 90-line PR that fixes a bug
*and* renames a helper is two.

Ask: would the reviewer want these as separate PRs?

**Ask it once every pre-implementation pass this cycle is running has landed and its findings
are applied** — before implementation begins. A pass this cycle is not running is not a pass
to wait for, and the skill's downshift table says which of them run at a given depth: where it
leaves the sentinel post-only, the moment is when plan review converges; where it drops the
plan review as well, nothing is left to land and the drafted plan is the moment.

At full depth it is not the first draft. The review rounds routinely *expand* a plan, so an
answer written then is an answer about a document that is about to grow, and the drift
sentinel's pre-implementation pass expands it on the same argument — a helper it finds already
written, an acceptance section it sends back to be stated as an assertion, a rename it finds
colliding with something in scope. Once the passes this cycle runs have landed, the plan has
stopped moving and nothing has been built, which is the cheapest point there is, because
splitting is still just editing a document. The answer goes in the plan's `Decision Log`
whichever way it comes out — not in `Questions for the Maintainer`, which exists because a
question is not a decision, and this produces one. Name the outcome in the entry's opening
words, so that reading it back is a lookup.

**What decides it is why each block the plan gained is there, not how far the plan grew.**
Take every part of the plan the issue did not ask for, and ask what its reason for existing
is:

- **The same defect wearing another shape** — another site the pattern reaches, another route
  into it, a second layout of the same input, the consumer downstream of the value being
  fixed, a test pinning any of that. **One PR**, however large. A defect whose extent the
  issue misjudged is still one defect, and splitting it lands a half-fixed wrong answer on
  `main`.
- **A reason of its own** — a helper extracted so that the *next* change can use it, a second
  bug noticed in passing, a rename, a refactor that makes the fix read better. **A candidate
  to split**: it carries a justification a reviewer can accept or reject without ruling on
  the fix, so bundling it puts two questions in front of them at once.

A candidate is settled by one more question: could it land first, on its own, with the defect
still unfixed and the tree coherent? If yes, split it out. If pulling it out would leave one
PR's tests asserting behavior the other one changes, it was one change after all — say that
and proceed.

**Keep the one-PR answer to a sentence.** A check that costs a paragraph on every ordinary
cycle stops being read, and most cycles are ordinary.

Before opening, run `git diff --stat origin/main`; if top-level docs appear alongside the
code change, ask whether to split.

## Failure modes a plan should pre-empt

The skill's failure-mode catalogue is the full list. The ones that most often need
planning-time defenses:

- **NAMESPACE drift** — roxygen edits without re-running `document()`. Call `document()`
  out as an explicit step alongside any roxygen edit.
- **Drift from the authority document** — any change to the domain math must be
  reconciled against the profile's authority, and the PR must cite the equation/lemma.
- **Unguarded matrix inversion** — new code that calls `solve()` on a possibly
  rank-deficient Gram matrix must state its rank-handling strategy: ridge fallback,
  `NA` standard errors with a `verbose`-gated `message()`, or delegation to existing
  rank-handling code.
- **`Suggests:` packages used as if `Imports:`** — guard with
  `requireNamespace("...", quietly = TRUE)` and degrade gracefully. Tests and examples
  using them need the same guard or `\donttest{}`.
- **Stale `@inheritParams`** — after any signature change,
  `grep -rn "@inheritParams <name>" R/` and confirm the inherited parameters still exist.
- **CRAN-NOTE-introducing patterns** — examples over ~5 seconds; writes outside
  `tempdir()`; non-ASCII in identifiers; `T`/`F` instead of `TRUE`/`FALSE`;
  un-namespaced calls to base `stats` functions.
- **New-option interaction matrix** — when a PR adds a new fit-time option, enumerate the
  existing options it interacts with and specify at least one test per real combination.
  Not all combinations matter; enumerating forces the question.
- **Row-order invariants** — when a method binds computed values back onto user-supplied
  data (augment-, predict-, fitted-style), specify the row-order invariant in
  `Interfaces and Dependencies` *and* a test that locks it under input-row permutation.
  Round-trip identity tests do **not** lock row order — they hold by construction.
- **Slot-inventory changes** — adding or removing a slot in a class's expected-slot list
  must propagate to every hand-built mock fixture in the test suite, or the validator
  rejects the mock at test time.

## Idempotence with respect to upstream

- State the `main` SHA the plan was drafted against.
- State the versions of any upstream package whose behavior the plan depends on.
- **Never address anything by line number** — not a sibling file the executor can't control,
  not a source file a profile points into. Name the function, or give a string to search for.
  A line number is a count of the lines above it, and the count rule above governs it,
  exemptions included.
- Treat any rebase from `origin/main` as a checkpoint requiring a re-run of `document()`
  and `check()` before continuing.
