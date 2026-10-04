---
name: r-package-dev
description: >
  Guides development of statistical and numerical R packages — those implementing an
  estimator, a model, or an algorithm against a documented methodology, where a subtly
  wrong number is worse than a crash. Use when working inside such a package (a DESCRIPTION
  + R/ tree) and the request is to start a piece of work on it (e.g. "let's work on issue #123",
  a bug to fix, a feature to add).
---

# R package development workflow

This skill is the **single source of truth** for the process. Each repository carries only
its own facts, in a thin profile at `.workflow/PROFILE.md`.

**What it's for.** R packages that implement statistical or numerical methodology — an
estimator, a model, an inference procedure, an algorithm with a correctness proof. The 
distinguishing property is that **a wrong answer
looks exactly like a right answer**: there is no crash, no failing type check, and often no
failing test, because the test was written from the same derivation as the bug. Much of
what follows exists to defend against that.

These rules govern everything below:

- **You do not decide when work lands.** What you *are* allowed to do at the end of a
  cycle is set by the profile's **Governance** field. The default —
  `solo-maintainer-reviews` — is the most conservative: you branch, implement, gate, open
  the PR, and hand off at "ready to merge." You never commit to `main` and never merge.
  Under `solo-self-merge` you may merge once green; under `team` you wait for human
  approval; under `outside-contributor` you work on a fork and `CONTRIBUTING.md` outranks
  this skill. **If the profile is silent, assume the default and say that you are.**
- **The workflow is mandatory and you may not self-authorize a skip.** "It's a
  one-liner," "it's only doc tooling," and "a previous PR skipped this" are not
  authorization. If a skip seems warranted, *ask for it explicitly, per issue*, and
  wait. Running a stage at reduced *depth* is the lighter bar — state it in chat so it can
  be vetoed, then proceed. (Lesson 1 — the cautionary tale is real.)

---

## Step 0 — read the repo profile, every session

Before any work, in this order:

1. **`.workflow/PROFILE.md`** in the current repo — the build/test/gate commands, the
   methodology authority, the conventions, the repo-specific gotchas, the public API.
   If it is missing, see [Bootstrapping a repo](#bootstrapping-a-repo) below.
2. Any other `.workflow/` docs the profile names (typically prioritization/queue docs,
   which stay repo-local by design).
3. The repo's open issues, and whatever authority document the profile names
   (a methodology paper, a spec, a reference implementation).

**Then validate the profile, every session**:
`Rscript <skill-root>/scripts/check-profile.R .workflow/PROFILE.md`. **`<skill-root>` is the
absolute path of the directory holding this file** — resolve it now, once, because every
command below and every subagent brief needs it. It derives what a profile
must contain from the current `templates/PROFILE.md`, so a field the template gained since the
profile was written is otherwise invisible. Unconditional on purpose: the profile carries no
version stamp, the template forbids dated sections, and it is gitignored so it has no history
— "does this one predate the installed skill?" is not a question you can answer, and deciding
costs more than running.

Do not reconstruct the workflow from memory, and do not feel "already oriented" from a
prior session's summary. This step exists because it has been skipped before.

**Confirm `gh` is installed, authenticated, and pointed at a GitHub remote** —
`gh auth status && gh repo view --json nameWithOwner`; the first alone passes against a GitLab
or Bitbucket `origin`. PR creation, CI watching, and the disposition sweep's "file an issue"
path all shell out to it; if either command fails, surface it to the maintainer rather than
working around it.

---

## The standard cycle

**Copy this checklist into your response and tick each stage off as you finish it.**

```
- [ ] 1. clarify scope with the maintainer
- [ ] 2. create the feature branch, then the ExecPlan in .plans/<branch>/
- [ ] 3. plan-review subagent + drift sentinel (pre-implementation)
  - [ ] plan review: iterate to convergence
  - [ ] drift sentinel: the pre-implementation pass, once
  - [ ] plan expanded by a pre-implementation pass? → plan review again, scoped to it
  - [ ] then, before implementing: one PR or more? → Decision Log
- [ ] 4. implementer subagent (or inline for small work)
- [ ] 5. the per-PR CRAN gate
- [ ] 6. post-execution review subagent + drift sentinel (post-implementation)
  - [ ] iterate to convergence
- [ ] 7. close the loop and open the PR
  - [ ] disposition sweep → PR description draft → draft review → push → open PR targeting main
  - [ ] watch CI, and hold for green only if the profile's CI is `gating`
  - [ ] hand off per the profile's Governance field
- [ ] 8. answer the maintainer's review round, whenever it arrives
```

Each stage has a reference below. The *depth* of each scales with the change (see
[Downshifting](#downshifting)); dropping one altogether takes the maintainer's yes.

**Before invoking any subagent, read
[references/harness-notes.md](references/harness-notes.md)** — how your harness spawns them,
and the rule that matters most, which is its § "Absolute paths, always". A brief that a
subagent cannot resolve is a common failure mode.

**Don't edit an artifact a pass is currently reading.** At stage 6 the passes run at once; at
stage 3 they run one after the other over the same plan. Either way — and whenever a finding
arrives from elsewhere while a pass is still running — hold the revision until that pass lands
and apply every finding as one pass. A reviewer whose input changed mid-read produces findings
against a document that no longer exists, and you cannot tell which of its points still apply.

### 1. Clarify scope

Issues in a solo-maintained package are often underspecified — the maintainer
writes them as reminders to themselves, not as scoped tickets. **The issue text is a starting
point, not a specification.** Drafting a plan from the issue text alone is a
common cause of wasted work here.

The protocol — the ambiguities to enumerate, how to ask, where each outcome is recorded, and
the check that the work is not already done — is in `references/scope-clarification.md`;
search it for `List the ambiguities explicitly`.

### 2. Write the ExecPlan

**Create the feature branch first.** It names the plan's folder, and every stage after this
one assumes it is checked out; the command, the branch-name convention, and why `--no-track`
matters are in
[references/git-and-pr.md](references/git-and-pr.md#before-writing-any-code). Then the plan
goes in that branch's `.plans/` folder, per
**[references/execplan.md](references/execplan.md)** — the format, the mandatory
living-document sections, the skeleton, and the standard acceptance criteria every plan is
measured against. It also owns
[what every file in that folder is called](references/execplan.md#artifact-names), for this
file and for every brief that has to name one.

**The plan's first content is stage 1's questions.** No plan existed when you put them, so
`Questions for the Maintainer` gets every one of them as the opening act of drafting — in the
words you used, dated the day you asked, carrying whatever became of it. Stage 1 is the one
place criterion 20's write-the-entry-as-you-ask rule cannot be followed literally, and this
transcription is what closes it; from here on it applies as written.

### 3. Review the plan *before* writing code

A **plan-review subagent** pass per
**[references/subagents/plan-reviewer.md](references/subagents/plan-reviewer.md)**,
plus the **drift sentinel** pre-implementation pass per
**[references/subagents/sentinel.md](references/subagents/sentinel.md)**.

Skipping the plan-review is the specific failure this checklist exists to prevent. It
catches design bugs paper-reading misses, and it re-checks the facts a scope decision
rests on — including whether the acceptance criteria measure the right observable
behavior.

**Every findings file this stage produces gets a response beside it, named off the round it
answers** — under the names [references/execplan.md](references/execplan.md#artifact-names)
defines. Write them the way [stage 6](#6-review-the-implementation) writes its own: from the
findings files item by item, never from a subagent's returned summary, with every numbered
item dispositioned. What the converging round leaves is what the post-execution reviewer
later looks for by name.

**Settle the plan's PR count before implementing — one PR or more than one — and write the
answer into the `Decision Log`.** Which passes the moment waits on is set by the depth this
cycle is running at; that, the test to apply, and the shape of the entry are in
[references/execplan.md](references/execplan.md#pr-scope-guidance).

### 4. Implement

Delegate to an **implementer subagent** per
**[references/subagents/implementer.md](references/subagents/implementer.md)** when the
change is ≥ 50 lines, multi-file, or would generate ≥ 5000 tokens of tool output.
Implement inline for ≤ 10-line fixes, small surgical round-2 fixes, and exploratory
work where the spec is emerging as you go. When you write the code yourself, the comment rules
in [implementer.md](references/subagents/implementer.md#what-a-comment-may-assert) bind you as
they bind the subagent.

**Check the brief's `The comment rules, applied` item before accepting a delegated report.**
Open § "What a comment may assert" and compare: the item must name the rules that section
states, not plausible substitutes, and each `file:line` it cites must be a line the diff
changes that says what the item claims. A failing item is not fixed by re-running the
implementer: it commits as it goes, so a second run has nothing to apply and reports clean.
Spend a [narrow round](#6-review-the-implementation) instead, asking which of that section's
rules the branch's comments and roxygen break. Hand the implementer its brief's path, never
the rules: the receipt proves reading only while the launch prompt does not carry them.

Version bookkeeping for a user-visible change — the `NEWS.md` bullet, the version bump, the
`inst/CITATION` update — belongs to this stage, not to stage 7; see
[references/git-and-pr.md](references/git-and-pr.md#while-working).

**The profile's Public API and Dependencies sections are yours in this stage too**, on the
PRs that move them — a new export, a new `Imports:` or `Suggests:` entry. The implementer may
not edit `.workflow/`, so you re-derive § 8 and § 10 with the commands those sections name and
never type either list. Why they are the plan's deliverable rather than a later tidy-up is in
[references/execplan.md](references/execplan.md#conventions-every-plan-should-encode).

### 5. Run the per-PR CRAN gate

Per **[references/cran-gate.md](references/cran-gate.md)** — the exact commands come
from the profile, but the shape is invariant:

    format → document → test → check → spell_check → url_check

Every PR must leave the package CRAN-ready.

### 6. Review the implementation

A **post-execution review subagent** pass per
**[references/subagents/post-exec-reviewer.md](references/subagents/post-exec-reviewer.md)**,
plus the **drift sentinel** post-implementation pass. Both read the diff directly — never
via the implementer's summary.

The sentinel's `Verdict: BLOCKED` gates the **push**, not the commit — the implementer
commits on the branch as it works, and nothing is published until both reviewers converge.
If the sentinel blocks and the post-exec reviewer says LGTM, **the sentinel wins**: hold the
push until its BLOCKERs are addressed with follow-up commits.

**When a specific suspicion outlives a round** — a claim corrected before, a header wrong
twice, an assertion whose reach nobody has measured — spend the next round on that question
rather than on another full pass. Brief the role you would otherwise re-spawn with the
suspicion as one or two falsifiable questions about a single artifact, name the tree to run
in, and say that **a null result is reportable**: a battery where nothing goes red is a
finding about the assertions, not the absence of one. Its output is that role's next `_v#`,
per the [roster](references/execplan.md#artifact-names) — and it is not a stage, so no cycle
owes one, not running one is not a finding, and the checklist gains no line.

**Write the response files — the ones
[references/execplan.md](references/execplan.md#artifact-names) names, one answering the
post-execution review and one answering the sentinel's post-implementation pass — from the
findings files, item by item, never from a subagent's returned summary.** A summary is
organised around what you asked; a findings file is organised around what the reviewer found,
and they diverge exactly where you did not think to look. Items have been lost in that gap
while the plan recorded them as applied. Every numbered item gets a disposition, "applied"
included; a deferral gets criterion 14's (a)/(b)/(c).

**Version each response like the findings file it answers, and never overwrite an earlier
one** — `references/execplan.md`, search it for `A later round appends`.

### 7. Close the loop and open the PR

Per **[references/git-and-pr.md](references/git-and-pr.md)**. Before pushing, work the
acceptance criteria from
[references/execplan.md](references/execplan.md#the-standard-acceptance-criteria) rather than
from memory — these are the ones this step turns on:

- **Alignment check** — *not* an acceptance criterion; it lives in
  [post-exec-reviewer.md](references/subagents/post-exec-reviewer.md). Does the PR resolve the
  *clarified-scope paragraph*, not a related case? Green tests and an unresolved issue can
  coexist.
- **Disposition sweep** (criterion 14). Every item flagged out-of-scope gets **exactly one**
  of: **(a)** file an issue, **(b)** don't defer — do it now or in a *named* upcoming PR,
  **(c)** drop with reasoning. No fourth, limbo option. Captured in the PR description **and**
  a separate chat message, so the maintainer can override per item.
- **Unanswered-question sweep** (criterion 20). Every question you put to the maintainer
  carries a dated disposition by now, and the ones ending unanswered go in the same chat
  message as the disposition sweep.
- **Re-derive every claim a command settles at the final commit** (criterion 17) — as a
  checklist, not a glance, and a claim about what a test *covers* is on it beside the numbers.
  Review fixes land *after* the last review ran, so no reviewer has checked them yet.
- **Count the PR body** (criterion 18), and re-count after every edit to it.
- **Decide where each durable finding goes** (criterion 19): a check, a profile gotcha, a
  lesson, or **nothing** — which is the default. Prefer a check; a lesson is what you write
  when you *cannot* mechanize something.

Draft the body in the PR-description file
[references/execplan.md](references/execplan.md#artifact-names) names, under
`# Suggested title` / `# Suggested body`, rewritten to match the branch's *final* scope; pass
only the text under `# Suggested body` to `--body-file`. Then queue and artifact upkeep —
closed issues out of the queue doc, merged branches' `.plans/<branch>/` folders removed.

**Before pushing, get the draft reviewed.** Spawn a fresh post-execution reviewer over the
PR-description draft and every commit made after the last review pass. Brief it with the draft,
the range of those commits, and one question: does each claim in them that a command settles
hold at the final commit, and do its copies elsewhere agree? Its output is the post-execution
review's next `_v#`, answered as stage 6 answers a round, and a fix it prompts gets the same
review before the push. Every cycle owes this pass.

Then push and open the PR targeting `main`.

**If the profile's CI is not `none`**, watch it to completion — `gh pr checks <n> --watch`.
Under `gating`, green is the handoff condition; under `advisory`, report what failed and hand
off anyway, because holding there holds the PR against the profile.

A green local check is evidence about one platform, one R version, and one BLAS; CI is where
cross-platform numeric tolerance, locale-dependent
ordering, and oldrel syntax failures surface. Triage any red explicitly as *your change*,
*a known-flaky job*, or *pre-existing breakage on the base branch* — see
[references/cran-gate.md](references/cran-gate.md#continuous-integration).

Then hand off per the profile's **Governance** field.

### 8. Answer the maintainer's review round

Under the default `solo-maintainer-reviews` the handoff is not the end: comments and requested
changes land on nearly every non-trivial PR, and the commits that answer them are written
*after* every review pass in this cycle has already run. Work them on the same branch:

- **Address the comments there** — one commit per point, and say what you did on each thread,
  including the ones you are disagreeing with and why. Never a new branch, never a force-push
  over what the maintainer was reading.
- **Re-run the per-PR CRAN gate.** It does not downshift here either.
- **Re-derive every claim a command settles at the new final commit** (criterion 17).
  Everything in the PR body was measured at a commit that is no longer the tip; re-count the
  body itself (criterion 18) if you edited it, and correct any number that moved.
- **A correction to a comment may not lengthen it.** Delete the claim; failing that, replace
  it in place. Count it on the correction commit rather than judging it — `--numstat` has no
  notion of a comment, so filter: `git show <sha> -- '*.R' | grep -c '^+[[:space:]]*#'`
  against the `^-` equivalent. Corrections usually run net-positive, and the exceptions
  changed a claim's *form* rather than its content.
- **Then ask whether a fresh post-execution pass is owed.** The bar is what the new commits
  touched: **anything under `R/` earns one**, and so does anything under `tests/` — that code
  has been read by nobody, and a small change made under review pressure is exactly what the
  post-execution review exists for. Commits confined to prose — documentation, `NEWS.md`, the
  PR body, a comment — do not. When one is owed, run the sentinel's post-implementation pass
  alongside it, converge as stage 6 does, then push. When the new commits answer a claim that
  has now been corrected more than once, the round to ask for is
  [the narrow one stage 6 describes](#6-review-the-implementation), not another full pass.
- **Hand back again rather than merging.** A review round does not change the Governance
  field.

---

## Working cadence

- **Planning is the maintainer's to close.** In a "what should I work on next?"
  discussion, converge on the plan and let them make the **explicit pick** before you
  touch code. Don't start implementing mid-discussion.
- **Once a target is picked, keep going.** Don't pause for a go-ahead between phases or
  PRs. Execute the whole roadmap — implement → gate → open PR → next phase — stacking
  branches when a dependency isn't merged yet. Commit and push to the PR branch on green
  **without** asking (staging only the relevant files). Review happens at PR-submission time,
  not mid-work.

---

## Downshifting

A lighter cycle for a genuinely small or dev-tooling PR comes at one of the two bars the
governing rules at the top of this file set — reduced depth, or not running the stage at
all — and conflating them is how the gates get skipped. Neither bar is cleared by the table
below: `ask to drop` marks a request you may make, not permission already granted.

**Either way, record it in the ExecPlan's `Decision Log` with the date** — which stage, which
of the bars above, and for a drop, the maintainer's yes. The post-execution reviewer checks
that a thinned or dropped stage was authorized, and it reads the log rather than the chat the
announcement happened in; without an entry there it cannot tell an authorized drop from a
stage nobody ran.

| Change | Plan review | Sentinel | Implementer | Post-exec review | CRAN gate |
|---|---|---|---|---|---|
| Trivial one-liner: no math, no exports, no S3 contracts, no error handling | ask to drop | ask to drop; else post only | inline | **always** | **always** |
| Small fix (≤ 10 lines) touching behavior | yes | post only | inline | **always** | **always** |
| Anything else | yes | yes (×2) | subagent if ≥ 50 lines | **always** | **always** |

**The CRAN gate and the post-execution review never downshift, and there is no lighter
version to ask for.** The post-exec pass reads the actual diff rather than the plan; the
sentinel is the only other pass that does, so once the maintainer grants the trivial row's
drop, the post-exec pass is the only look anyone takes at what landed.

---

## Where things live

| Path | Lifetime | Tracked? | Contents |
|---|---|---|---|
| `.workflow/PROFILE.md` | persistent | gitignored | this repo's facts: commands, authority, conventions, gotchas |
| `.workflow/*.md` (other) | persistent | gitignored | repo-local prioritization / queue / project notes |
| `.plans/<branch>/` | per-branch | gitignored | ExecPlan, review rounds, PR-description draft — [execplan.md](references/execplan.md#artifact-names) names each one |
| `.plans/<branch>/scratch/` | per-branch | gitignored | one subdirectory per subagent, each deleting only its own — never in `R/` or `tests/` |
| `.plans/code-review-<date>/` | per-review | gitignored | periodic-review agent reports; keep the latest, prune the rest |
| `.plans/code-review-<date>/scratch/` | per-review | gitignored | one subdirectory per lens agent, each deleting only its own — never in `R/` or `tests/` |
| `.plans/follow-ups/` | until filed | gitignored | issue drafts awaiting filing — delete each once its issue exists |
| `AGENTS.md` / `CLAUDE.md` | persistent | **tracked, or gitignored** — see below | repo entry point; points here and at the profile |

Branch `feat/s3-class-16` → folder `.plans/feat-s3-class-16/` (slashes become dashes).

**`.workflow/` and `.plans/` are gitignored, so nothing in them has a history.** Copy
`.workflow/PROFILE.md` somewhere safe before anything that removes ignored files, such as
`git clean -x`: a deletion there is permanent.

**Whether `AGENTS.md` / `CLAUDE.md` is tracked is the repo's choice, so read the repo's
`.gitignore` before you decide which rule applies to an edit** — `references/adoption.md`,
search it for `Whether that file is tracked is the repo's choice`. Editing a tracked one is a
branch and a PR like any other tracked file.

**On `main`.** This skill writes `main` throughout for the default branch, because that is
what most R packages use. **Wherever it appears in a command, substitute the profile's
actual default branch** — `master` and `devel` are both common, and Bioconductor's model
depends on it.

Keep every persistent doc in a **single present-tense state**. Don't bolt on dated
"refreshed YYYY-MM-DD" sections — they go stale immediately and force the reader to
reconcile old body against patch. A past PR that anchors a principle gets folded into
the prose ("PR #47 illustrates Tier 0…"). "What's currently in flight" belongs in the
issue tracker, not in a process doc.

---

## Reference map

| Read this, or run it | When |
|---|---|
| **[references/scope-clarification.md](references/scope-clarification.md)** | Turning an underspecified issue into a confirmed scope paragraph, before any plan exists |
| **[references/execplan.md](references/execplan.md)** | Drafting or revising an ExecPlan; checking acceptance criteria |
| **[references/cran-gate.md](references/cran-gate.md)** | The R edit/test loop, the per-PR gate, formatting, CI, test discipline, export discipline, decoding R errors, code-vs-spec drift |
| **[references/git-and-pr.md](references/git-and-pr.md)** | Branching, committing, NEWS conventions, PR description style, stacked PRs, branch-protection contexts, git foot-guns, what Governance changes |
| **[references/subagents/plan-reviewer.md](references/subagents/plan-reviewer.md)** | Briefing the pre-implementation plan reviewer |
| **[references/subagents/implementer.md](references/subagents/implementer.md)** | Briefing the implementer |
| **[references/subagents/sentinel.md](references/subagents/sentinel.md)** | Briefing the drift sentinel (both passes) |
| **[references/subagents/post-exec-reviewer.md](references/subagents/post-exec-reviewer.md)** | Briefing the post-execution reviewer |
| **[guides/periodic-review.md](guides/periodic-review.md)** | Running the quarterly codebase sweep — occasional, opt-in |
| **[guides/litr.md](guides/litr.md)** | Only if the package is built from a source document rather than `R/` |
| **[references/object-systems.md](references/object-systems.md)** | Any work touching classes, methods, dispatch, or validators — S3, S4, R6, or S7 |
| **[references/harness-notes.md](references/harness-notes.md)** | Once per session, before spawning any subagent — how your harness spawns them, the absolute-path rule, and the known harness bugs |
| **[references/lessons.md](references/lessons.md)** | Something surprising just happened; or pre-empting known failure modes in a plan |
| **[references/adoption.md](references/adoption.md)** | Setting the skill up in a new package — deriving the profile field by field |
| **[templates/PROFILE.md](templates/PROFILE.md)** | The profile form itself |
| **[scripts/check-profile.R](scripts/check-profile.R)** — *run it, don't read it* | Checking a filled-in profile against the current template — every session, as the last act of Step 0, and again at adoption once the profile is filled in |

---

## Bootstrapping a repo

If the current R package repo has no `.workflow/PROFILE.md`, **follow
[references/adoption.md](references/adoption.md)** — search it for `bootstrap-repo.sh`. It
owns the scaffold command together with the tracked files that command edits and the commit
the maintainer has to land, a per-field table of the command that derives each profile answer a
command can settle, the rule that anything you couldn't derive gets marked as inherited rather
than stated, and a first-run verification pass to do before any real cycle. Several of this
workflow's serious failures came from a profile that was wrong; deriving it is the job, and
guessing at it is the failure.

---

## Hard prohibitions

- **Never commit directly to the default branch.** Every change goes through a branch and
  a PR — even a one-liner. Whether you may *merge* that PR is the profile's **Governance**
  field; when it is silent, you may not.
- **Never hand-edit generated files** — `man/*.Rd` and `NAMESPACE` come from roxygen;
  in a litr package, the entire built package directory and site come from the source
  `.Rmd`. Edit the source and re-run the generator.
- **Never change the repo's formatting regime as a side effect of another change**, and
  never install or upgrade a formatter without an explicit yes. A whitespace-only reformat is
  its own deliberate PR, or it doesn't happen.
- **Never claim tests pass from an empty failure-grep, and never from a missing summary line
  either.** (Why a missing line is a finding, and what to read instead, are in § Test
  discipline in `cran-gate.md`.)
- **Never let a deferred item end the cycle without an (a)/(b)/(c) disposition.**
- **Never introduce a new dependency casually.** CRAN reviewers scrutinize them; adding
  one is a decision to confirm with the maintainer, not a convenience.
- **Never add to the public API "just in case."** For a CRAN package, an export is a
  one-way door.
