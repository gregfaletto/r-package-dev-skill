# Using this skill

This guide is written for you instead of the agent. Everything else in this repo is written
for Claude to read, and this file explains how you drive it.

---

## Setup, once

```bash
git clone https://github.com/gregfaletto/r-package-dev-skill.git
cd r-package-dev-skill
bash scripts/install.sh
```

[`install.sh`](scripts/install.sh) symlinks the repo into `~/.claude/skills/r-package-dev`,
which means edits to the repo take effect immediately, without a reinstall. Verify with
`bash scripts/install.sh --check`.

## Setup, once per package

From the package's repo root:

```bash
bash "${AGENT_SKILLS_DIR:-$HOME/.claude/skills}/r-package-dev/scripts/bootstrap-repo.sh"
```

[`bootstrap-repo.sh`](scripts/bootstrap-repo.sh) creates `.workflow/` and `.plans/`, copies in
the [profile template](templates/PROFILE.md), and adds the gitignore entries. It is idempotent
and safe to re-run, and it never overwrites an existing profile.

Then fill in `.workflow/PROFILE.md`. This is the one piece of real work, and every serious
failure in this workflow has come from it and not from the process.

Instead of asking Claude to improvise, point it at the procedure by telling it to "follow
[`references/adoption.md`](references/adoption.md) in the r-package-dev skill and fill in
`.workflow/PROFILE.md` for this repo." That file has a per-field table of the command that
derives each answer, so the profile is measured and not guessed. The procedure also requires
anything that couldn't be derived to be marked as inherited.

Then read what it wrote and correct it. It will get commands and layout right and guess at
conventions, which aren't facts about the repo but your decisions.

### Your first cycle is cleaning the gate

Run the gate once. If it doesn't meet the bars in
[`references/cran-gate.md`](references/cran-gate.md#expected-results-and-triage) § "Expected
results and triage" (that file is the only place they are defined), fixing that is the first
PR, before any feature work.

Every cycle after it is measured against a clean gate, so a package that starts dirty makes
those criteria permanently unfalsifiable. Because they fail on the base tree, they can never
fail as a result of a change, yet they still read as verification.

Cleaning the gate is also usually worth doing on its own merits. On a package with no
`inst/WORDLIST`, `spell_check()` routinely returns dozens of words, and the triage surfaces
real documentation errors. `url_check()` finds citations that have rotted, and
`no visible binding for global variable` is an unqualified name that will fail at runtime on
some path.

Get the gate as close to clean as you can, and put what really won't move in the profile's § 3
by name, with the reason and the date. From then on the bar is that the gate flags only what is
on that accepted exceptions list, and that bar is falsifiable again. An empty list is the goal
and a common answer.

Several fields change what the agent does in addition to describing the repo. Get these right
and the rest is cosmetic:

| Field | What it controls |
|---|---|
| **Governance** | Whether the agent may merge. Defaults to no. |
| **CI** | Whether a green local check is the claim, or just pre-flight. |
| **Object system(s)** | Which dispatch/export/validator checks the reviewer applies. |
| **Formatter** | `air`, `styler`, or none. With `none`, the agent won't introduce one. |
| **Method-entry preconditions** | Sets the drift sentinel's second check to blocking or advisory. |

The bootstrap step commits nothing, but it does modify the tracked `.gitignore`. It also
modifies the tracked `.Rbuildignore`, but only when there is a `DESCRIPTION` at the repo root.
So a package generated from a source document gets the gitignore lines alone. Land whichever it
wrote yourself in a small commit before starting feature work. The agent won't do it, because
it's forbidden from committing to your default branch.

---

## Day to day

You don't invoke the skill, because Claude loads it when it sees an R package. If it doesn't,
say "use the r-package-dev skill."

A normal session looks like this:

> **You:** Let's work on issue #42.
>
> **Claude:** *reads the profile, reads the issue, comes back with three or four narrow
> questions*: should this affect `etwfe()` too, or just `fetwfe()`? Is this a breaking
> change or an opt-in argument? What should happen when there are no covariates?
>
> **You:** *answers*
>
> **Claude:** *restates the scope in one paragraph*
>
> **You:** Yes.
>
> From here it runs without stopping: plan → plan review → implement → gate → review → PR.
> It comes back when the PR is ready.

Expect one more round after that, in which your own review comments are answered on the same
branch, with the gate re-run and every claim a command settles re-derived at the new tip.
Stage 8 of `SKILL.md` defines what that round owes you.

The pause before "yes" is the most important part, because most of the value in this workflow
is in getting the scope right before any code exists. If you find yourself saying "yes, and
also…" a lot, tell it that its questions were too narrow.

### What you'll be asked for

- **A scope confirmation**, once, at the start. Required.
- **A separate message listing deferred items**, at the end, each marked as *filed as an
  issue*, *folded into a named next PR*, or *dropped, because…*. Confirm or override them. This
  exists because deferred work otherwise vanishes.
- **Occasionally, a blocking question** about a design decision the plan didn't anticipate.

### What you shouldn't have to do

- Approve each step. Once you've picked the target, it runs the whole cycle.
- Remind it to run the check, update `NEWS.md`, or regenerate docs.
- Review a plan yourself. A subagent does that first, and you review the PR.

---

## Steering it

Smaller is better, because the workflow works best on a well-scoped bug fix or one
self-contained feature. If a task touches three unrelated areas, split it yourself before
starting—the agent will suggest splitting, but it's cheaper to decide up front.

To go faster on something that really is trivial, say so: "This is a one-line doc fix—skip the
plan review." The skill does not allow the agent to decide that on its own, because the gates
get skipped on the grounds that "this is obviously trivial." You can make that decision
yourself, one issue at a time. When the agent runs a stage more thinly, for example with a
shorter plan or with only the post sentinel pass, it announces that rather than asking. Veto
that if you'd rather it didn't.

To go slower on something risky, say "Run the plan review twice" or "benchmark this before
committing to it." The extra rounds are worth their cost on math-touching changes and
performance claims.

If a review round feels like a formality, tell the agent, because it probably is one. Two
rounds is normal for a non-trivial PR, but three usually means the design is wrong, and the
skill says so.

---

## Reading the output

Work goes in `.plans/<branch>/`, all gitignored: the ExecPlan, a findings file from each review
pass (the drift sentinel's passes included) with the author's response beside it, and the PR
body before it is posted. The name of each of those files is defined in exactly one place,
[`references/execplan.md` § Artifact names](references/execplan.md#artifact-names), and every
brief the agent hands its subagents takes the name from there and doesn't restate it.
Subagent working files go in a `scratch/` subdirectory apiece.

A one-round cycle stops after the first response to each review, and a `_v2` on any of them
means a second round ran. No round ever overwrites an earlier one, because the agent's own
end-of-cycle sweep for deferred items works by grepping this folder.

Because the sentinel's pre-implementation and post-implementation passes have separate names
instead of a shared one with a suffix, a missing post pass is visible. `SKILL.md` makes that
pass the gate on pushing, and a full cycle produces it every time. If it is not there, the push
gate did not run.

If you read one file, read the ExecPlan, specifically the following sections. Read
`Purpose / Big Picture` to see whether this matches what you asked for, and `Decision Log` to
see what it decided without you. Read `Questions for the Maintainer` to see what it asked you
that you never answered, and what it assumed instead. Since the unanswered ones are repeated
to you in the handoff message, nothing there should be a surprise. They stay findable in that
section afterwards.

If you read two, add the post-execution review, whose "What I did NOT verify" section is the
honest part.

Delete the folder when the PR merges. It's scratch.

---

## When something goes wrong

If the PR is bigger than you expected, scope crept. Say so and ask for a split; the skill asks
that question explicitly past roughly 250 lines of source.

If the check won't go green on a pre-existing NOTE, tell the agent to verify the NOTE exists on
the default branch too, then note it in the PR description and move on. The skill says
pre-existing NOTEs on the default branch aren't the PR's problem, but `error_on = "note"` will
still fail the run.

If a review keeps finding the same thing, ask the agent to stop iterating and re-plan, because
three rounds means a structural problem that patching will not fix.

If it's slow on something small, that is because the full cycle is heavy by design. Downshift
explicitly (above), or batch several small fixes into one PR and say that's what you're doing.

If it claims work it didn't do, ask to see the review files. Since everything the workflow
produces is gitignored, nothing in the PR proves the reviews ran.

---

## Keeping the skill current

When a cycle teaches you something that would have saved time if it had been written down, the
destinations for it are ranked below, best first. This is
[acceptance criterion 19](references/execplan.md#the-standard-acceptance-criteria), and the
agent should already be proposing a disposition without waiting to be asked.

- **A check**: a gate, an acceptance criterion, a reviewer or sentinel bullet. Always
  preferred, because it fires whether anyone read it or not.
- **A profile gotcha** → `.workflow/PROFILE.md`, § 12, when it's specific to this package.
- **A lesson** → [`references/lessons.md`](references/lessons.md), when it both applies
  anywhere and can't be mechanized. Writing one means admitting that no check exists.
- **Nothing**, which is the default. Most of what a cycle surfaces was surprising once and
  won't recur.

The ranking matters more than the destinations. A lesson that's only written down recurs
anyway, and that's the subject of the skill's own lesson 1. Ask what gate would have caught
this, and write it down only if the answer is "none, and I can't build one."

---

## What this doesn't do

It won't submit to CRAN for you, because there's no submission runbook yet. It won't manage
your issue tracker, decide what to work on next (that's deliberately per-repo), or work across
two repos at once.
