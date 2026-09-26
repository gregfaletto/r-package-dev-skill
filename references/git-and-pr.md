# Git and PR workflow

## Contents

- [Before writing any code](#before-writing-any-code)
- [While working](#while-working)
- [When ready to submit](#when-ready-to-submit)
- [PR description workflow](#pr-description-workflow)
- [PR description style](#pr-description-style)
- [Branches and PRs are the default — always](#branches-and-prs-are-the-default--always)
- [Gotchas learned the hard way](#gotchas-learned-the-hard-way)
- [What the profile's Governance field changes](#what-the-profiles-governance-field-changes)
- [CI](#ci)

---

The agent's job is to produce a clean, focused PR that is fast to review.

> **Read the profile's Governance field before anything below.** This file is written for
> the default, `solo-maintainer-reviews`: one maintainer owns the default branch and
> approves every PR personally, there is **no fork** (push branches directly to `origin`),
> and the agent never merges. Under `solo-self-merge`, `team`, or `outside-contributor`,
> the fork model, the review step, and who may merge all change — see
> [What the profile's Governance field changes](#what-the-profiles-governance-field-changes)
> at the end of this file, and read it *first* if the profile is anything but the default.
> A repo's own `CONTRIBUTING.md` and branch protection rules outrank everything here.

> **On branch names:** this file writes `main` throughout for the default branch. Wherever
> it appears in a command, substitute the profile's actual default branch — `master` and
> `devel` are both common.

## Before writing any code

**1. Branch off `main`, with `--no-track`.**

```bash
git fetch origin
git checkout -b <slug-or-issue-number> --no-track origin/main
```

The `--no-track` matters. The bare form silently sets the branch's upstream to
`origin/main`. Under git's modern default (`push.default = simple`) a bare `git push` from a
differently-named branch *errors* rather than pushing — but the hazard is real under
`push.default = upstream`, under pre-2.0 `matching`, and via any IDE panel or hook that
pushes the tracked ref explicitly. It has landed a refactor directly on `main` before. The
hygiene is cheap; verify with `git config --get-all branch.<branch>.merge`, which should be
empty until `git push -u`.

Branch names encode the issue number or a short slug: `fix-rank-condition-12`,
`feat/s3-class-fetwfe`, `cran-tweaks`.

**2. Confirm scope is clarified.** The issue-clarification protocol must already have
produced a one-paragraph scope statement the maintainer confirmed. That paragraph seeds
the ExecPlan's `Purpose / Big Picture`. **Do not start coding without it.**

## While working

**3. Commit small and often.** Each time the check is green, commit. One logical unit per
commit; don't bundle unrelated changes. If you edited roxygen
tags, stage the regenerated `man/*.Rd` and `NAMESPACE` in the same commit so docs and source
stay in sync.

**Re-check the branch immediately before every commit:**

```bash
git rev-parse --abbrev-ref HEAD
```

Subagents share one working tree and one HEAD. A review subagent that ran `git checkout
main` to diff and didn't restore has left a feature commit on local `main`. Recovery:
`git branch -f <feature> <sha>` → `git checkout <feature>` → `git branch -f main
origin/main`. (`origin` is never touched.)

**4. Keep the branch current.** Rebase, don't merge, while a single branch is in progress:

```bash
git fetch origin && git rebase origin/main
```

After any rebase, re-run at minimum the test suite; for non-trivial rebases, the full
check.

**5. Update `NEWS.md` as part of the change, not at submission.** Every PR with a user-visible
change adds a one-sentence, past-tense bullet naming the affected function, **under the
existing `# <pkg> <version> (development version)` header** — not under a new version header.
The version in that header is load-bearing. R's news parser drops a section whose header
carries none — `tools:::.build_news_db_from_package_NEWS_md()` on a file headed
`# <pkg> (development version)` returns nothing — so those bullets never reach the news
database, and in a file with no other version header `R CMD check` reports
`No news entries found`: a NOTE, and so a failed run under `error_on = "note"`. Write the
bullet in the implementation commit, because the later stages read it there:
`devtools::spell_check()` passes `vignettes = TRUE` to `spelling::spell_check_package()`,
which scans root `readme|news|changes|index` markdown, so the gate spell-checks the bullet,
and the post-execution review diffs `NEWS.md` against `origin/main` before any PR exists.

The package sits on a development version (`1.2.0.9000`) between releases. If it is still on a
plain released version, bump `DESCRIPTION` to `<released>.9000` once and open the development
header; otherwise leave the version alone. If the profile's § 4 **Version lives in:** names
another file, edit that one instead: a generated package's `DESCRIPTION` is build output and
loses the bump on the next build. The release number is chosen and the header finalized **at
submission time**. If `inst/CITATION` derives its version via `meta$Version`, there is nothing
to update there at all.

If the PR is purely internal — a refactor with no user-visible change, a doc fix, dev
tooling — no NEWS entry or bump is needed, but say so in the ExecPlan, which is what the
post-execution reviewer has in front of it, and **flag it in the PR description** so the
maintainer can confirm the judgment.

## When ready to submit

**6. Re-run the per-PR CRAN gate.** See [cran-gate.md](cran-gate.md). If the formatter
modified files, stage and commit those changes before pushing.

**7. Push and open a PR targeting `main`.**

```bash
git push -u origin <branch-name>
```

Link the issue with `Resolves #N` — or `Refs #N` if it's a partial resolution.

## PR description workflow

> **Orchestrator through the end of this section.** Drafting the file, extracting the body,
> and opening the PR are yours; no subagent in this cycle does any of it. The next section,
> on style, is everyone's.

**Draft the body in a local markdown file before opening the PR** — the PR-description file
[execplan.md](execplan.md#artifact-names) names, which is where every artifact this cycle
writes gets its one name — under `# Suggested title` and `# Suggested body` headings. Only
the text **under** `# Suggested body` becomes the PR body; the `# Suggested title` line
supplies `--title`. **Never pass the whole file as the body.**

**Keep the draft in sync with the branch's final scope.** A draft written after the first
commit of a planned multi-PR sequence goes stale as later commits land. Before posting,
rewrite it to match what is *actually* being merged — if a planned multi-PR sequence
collapsed into one PR (or vice versa, or extra commits landed), title and body must reflect
the final shape.

```bash
# Extract everything under the "# Suggested body" heading:
awk 'b && (s || NF) {print; s=1} /^# Suggested body$/ {b=1}' \
    .plans/<branch>/<branch>_pr_description.md > /tmp/pr_body.md

# The awk anchor is byte-exact: a trailing space after the heading, or `##` instead
# of `#`, yields an EMPTY file — and `gh pr create` accepts that with exit 0.
test -s /tmp/pr_body.md || { echo "empty body: check the '# Suggested body' heading"; exit 1; }

gh pr create --base main --title "Add ridge fallback for rank-deficient design" \
             --body-file /tmp/pr_body.md
```

Sanity-check after opening: `gh pr view <n> --json body -q .body | head -3` — it must not
start with `# Suggested title`.

## PR description style

The maintainer is the reviewer; a terse body that gets to the actual change is what they
want. **Bias toward 2–4 sentences leading with the code change.**

- **Lead with the actual code change in one sentence.** "Resolves #N. Fixes X by changing
  Y to Z because A." A reviewer should be able to stop after the first sentence and still
  know what the PR does.
- **At most three `##` sections, and only these three:** `## Behavior changes` (only if the
  PR changes existing behavior), `## Worth your attention` (only if there is a real judgment
  call for the reviewer to make), and `## Out of scope (deferred follow-ups)` (mandatory if
  anything was deferred). **No others.** Not "Summary", not "Testing", not "Gate", not
  "Review", not "What changed".
- **Budget: ~400 words.** A substantial multi-file PR may earn 600. If you are past 800 you
  are reporting your work rather than describing the change.
- **The diff already states what changed.** Don't restate "files modified: A, B, C." Use
  prose for the *why*.
- **Process reporting does not belong in the PR body.** The gate transcript, the review
  rounds, which subagent found what, the red-green counts — none of that helps the reviewer
  decide whether to merge, and all of it is already in `.plans/<branch>/`. One line is the
  ceiling: "gate clean" — or, if a step could not run, one sentence saying which and why. The
  reviewer can ask for the rest.
- **The test that decides what stays:** would the reviewer make a different merge decision
  without this sentence? If not, cut it.
- **For math/spec changes, cite the authority.** Name the equation or lemma so the
  maintainer can cross-check without hunting.
- **Note CRAN-relevance.** If the PR is meant to land before the next submission (e.g. it
  fixes an `--as-cran` NOTE), say so.
- **Keep a "Test plan" only if it tells the reviewer something non-obvious.** For routine
  PRs, "all tests pass; check clean" is enough — or omit it.

**Always include `## Out of scope (deferred follow-ups)` if any item was flagged
out-of-scope during the cycle** — out-of-scope items are exactly the things that go invisible
without an explicit callout. Each item gets exactly one of these dispositions:

    ## Out of scope (deferred follow-ups)

    - **Item A** — <one-sentence description>. Filed as #N.
    - **Item B** — <one-sentence description>. Folded into <named upcoming PR>.
    - **Item C** — <one-sentence description>. Dropped: <reasoning>.

If nothing was deferred, omit the section entirely.

**A worked example, for a small bug fix:**

    Resolves #N. The `att_se` calculation in `fetwfe()` returned `NA` when the
    Gram matrix was rank-deficient and `q < 1`; root cause was an unguarded
    `solve()` call in `core_funcs.R::estOmegaSqrtInv()`. Replaced with a small
    ridge (`solve(A + lambda*I)`; no new dependency). Existing tests cover the
    happy path; added one test for the rank-deficient case which fails on `main`
    and passes on this branch.

That's the whole body.

**A worked example, for a substantial multi-file PR** — four behavior changes, a new test
file, and three deferred items, in about 240 words:

    Closes #440 (part A3 of four from #366; A1 shipped as #438). An out-of-range
    seed now fails with the package's own message instead of base R's coercion
    warning plus an opaque error, at all ten exported doors. The range rule and
    its wording are single-sourced into two helpers in `R/utility.R` rather than
    written inline at four sites. Separately, the four `*WithSimulatedData()`
    wrappers drop nine `match.arg()` calls their cores already perform.

    Message quality only — every affected path already errored; none returned a
    wrong number. Gate clean; `url_check()` did not run (no network egress here,
    and the diff adds no URLs).

    ## Behavior changes

    - A non-integral magnitude in `(2147483647, 2147483648)` is now rejected;
      `set.seed()` used to truncate it and draw from a *different* seed.
    - `B` and `seed` above the ceiling now error at the front door.
    - `.validate_boot_args()` reports the `B` error before the `seed` error.
    - A doubly-bad wrapper call now reports the `simulated_obj` problem first.

    ## Worth your attention

    The first behavior change rejects input that previously worked. I think
    erroring is right for a reproducibility argument, but it is a real change and
    my plan asserted the opposite. One line to permit it if you disagree.

    ## Out of scope (deferred follow-ups)

    - **Spurious override notice** — pre-existing, unchanged here. Filed as #442.
    - **`seed + 1L` overflow** — this PR's guard cannot catch it. Filed as #443.
    - **Non-integral-seed divergence** — Dropped: tightening it is a breaking
      change that #440 explicitly scopes out.

Note what is *absent*: no gate transcript, no review narrative, no test-plan prose, no
restatement of the diff.

## Branches and PRs are the default — always

The maintainer may make a direct commit to the default branch for a trivial fix; that is their
prerogative. **The agent should not.** Every agent-driven change goes through
branch → commit → push → PR → review, with no exceptions — even a one-line bug fix, a
roxygen typo, or a CRAN-NOTE cleanup.

---

## Gotchas learned the hard way

**"Accept both changes" is not always safe.** GitHub's one-click conflict resolution works
only when *both* sides end with complete top-level forms. It fails silently when one side
ends with a roxygen block whose target function is outside the conflict, or a partial
function body — you get two adjacent roxygen blocks with no function between them, which
`document()` renders into broken `.Rd` (or silently drops a definition). Before clicking:
confirm each side ends with a complete `name <- function(...) { ... }` / closing brace /
`@export`-plus-definition, and that the names introduced on each side don't clash (R
silently keeps the second). If either check fails, resolve manually — delete just the three
conflict markers and arrange each function under exactly its own roxygen block.

**Commit messages with math or Unicode — avoid heredocs.** Greek and math symbols (`σ²`,
`Ω^{-1/2}`) in a message wrapped in `$(cat <<'EOF' … )` can fail with
`syntax error: unexpected end of file`. Write the message to a temp file and
`git commit -F msg.txt` — portable, handles arbitrary Unicode. Reserve heredocs for
ASCII-only messages.

**Never `git checkout <file>` to undo an edit when that file carries other uncommitted
work** (an implementer subagent's changes, for instance). It resets to HEAD and discards
all of it, not just your edit. Reverse the specific edit instead, or commit/stash first.
After any such revert, `git diff --stat` to confirm nothing was lost.

**The same rule applies with more force to anything you automate.** A script that does
`git checkout -- R/` between iterations — a mutation battery, a bisect harness, a
before/after sweep — will silently destroy every uncommitted change in that directory the
moment you run it over your own in-progress work. It has already happened: a mutation script
reverted four uncommitted review fixes, and the only tell was a mutation producing failures
that made no sense for what it changed. **Commit before running any harness that resets a
directory**, and have the harness refuse to start on a dirty tree:

```bash
git diff --quiet -- R/ || { echo "R/ is dirty — commit before running this"; exit 1; }
```

Detecting the damage by noticing an odd result is luck, not process.

**Prefer sequential single-PR-to-`main`.** Fully merge issue N's PR before starting N+1, so
there's never an unmerged predecessor to stack on.

**If you must stack PRs:** branch each phase off the previous phase's branch and target it
as the PR base, so each diff is scoped to exactly one phase. Then:

- **Merge the base PR first**, and **verify** GitHub retargeted the dependent PR to `main`
  before merging it. GitHub only auto-retargets when the base branch is **deleted** —
  merging without deleting means the dependent PR merges *into the base branch, not
  `main`*, while still showing "Merged."
- **Never delete a base branch while a dependent PR still points at it.** That *closes*
  the dependent PR, and a closed PR whose base branch is gone cannot be reopened or
  retargeted.
- Each phase PR uses **`Refs #N`**; only the final phase uses **`Closes #N`**.
- The dependent PR's body must spell out the protocol: merge the predecessor **and delete
  its branch**, *then* merge the dependent.

**"PR shows merged" ≠ "the change is on `main`."** After the maintainer says merged, and
before deleting any branch or moving on, verify the landing:

```bash
git fetch --prune
git merge-base --is-ancestor <commit> origin/main   # exit 0 means it landed
```

A merged PR number is not proof; the ancestry check is. If a change was stranded on the
wrong base, re-push the branch and open a fresh PR to `main` — the diff is exactly the
intended change and merges cleanly. Do **not** delete the mis-targeted base branch until
the corrective PR lands; it is the only on-GitHub record of the merge.

**Landing a batch of parallel PRs in a generated-artifact repo.** PRs opened off the same
default branch conflict pairwise whenever each rebuild regenerates the whole tree, even
when their *source* changes are disjoint. **The source auto-merges; only derived files
conflict — so never hand-merge a generated file.** Merge the base, clear the conflict
markers in the generated tree (its content is about to be overwritten), rebuild from the
merged source, and commit that. Do this bottom-up, one branch at a time, so each subsequent
rebuild carries the prior fixes. **Merge-then-rebuild, not rebase** — rebasing replays each
commit and re-conflicts the generated tree repeatedly.

**`gh pr merge --delete-branch` fails when `main` is checked out in a worktree** (it tries
to update local `main` and aborts). That can leave the *remote* branch undeleted — drop
`--delete-branch` and delete branches at the end.

## What the profile's Governance field changes

Everything above is written for `solo-maintainer-reviews`, the default: **no "request review
from"** (the maintainer reviews themselves). Under the other models:

- **`solo-self-merge`** — still branch and open the PR (for the reviewable diff and the
  revert point), but merge once the gate and reviews are green.
- **`team`** — request review per the repo's convention and wait for human approval.
- **`outside-contributor`** — you have no write access. Fork, push there, open a cross-repo
  PR, and follow `CONTRIBUTING.md`, which outranks this skill.

## CI

If the profile's CI field is `none`, the local check is the gate and there is nothing to
wait on. Otherwise the local gate becomes pre-flight: open the PR, then
`gh pr checks <n> --watch`, and triage any red as your change, a known-flaky job, or
pre-existing breakage on the base branch. **What a red does to the handoff is the CI field's
to say, and it says something different in each mode**:

- **`gating`** — CI-green is the handoff condition. Do not report "ready to merge" until it
  is green.
- **`advisory`** — report the failures, with the same triage, and hand off anyway. The
  profile's own words are "report failures; don't hold on them", so holding the PR here is
  holding it against the profile.

See [cran-gate.md](cran-gate.md#continuous-integration).

**If the branch has a protection rule or ruleset, its required checks are literal context
strings** — for a matrix job, the rendered job name (`ubuntu-latest (oldrel-2)`) — so renaming,
retargeting, or dropping a matrix entry leaves a required name that never reports again and
blocks every PR until someone edits the rule by hand. Any diff touching `.github/workflows/**`
therefore diffs the rule's contexts against a live PR's check names before hand-off, asking
whether the *names changed* rather than whether the two sets match — a check that is
deliberately not required belongs to only one of them.
