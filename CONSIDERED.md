# Considered and set aside

Changes to this skill that a review proposed and the maintainer decided against, for now. Add
one when the maintainer sets it aside. When one comes up again, add a dated line under its
entry instead of writing a new one. An entry that keeps collecting dates is a candidate to
adopt after all.

Each entry says what the change would be and why it was set aside, then lists each time it came
up. Bare issue and PR numbers refer to `gregfaletto/fetwfePackage`. Write any other repo's as
`owner/repo#N`.

## Seed dependence in criterion 17

Add "or a seed, such as a CV fold assignment" to criterion 17's paragraph saying that
re-running a command is not re-deriving it. Set aside because a reviewer's own experiment found
it, and sweeping seeds is expensive.

- 2026-10-01, PR #493

## "Executable lines" in stage 8's fresh-pass bar

Replace "anything under `R/` … `tests/`" in SKILL.md stage 8 with "any change to an executable
line under `R/` or `tests/`". Set aside because both #493 sessions already read it that way,
and the prose commits that went unreviewed now get stage 7's draft review before the push.

- 2026-10-01, PR #493

## A reviewer session's own folder

Have a second session that reviews an open PR write into `.plans/<branch>/` as the next `_v#`,
instead of its own `.plans/pr-NNN-review/` folder. Set aside because nothing was lost in #493,
where every brief named both folders, though criterion 14's sweep reads only
`.plans/<branch>/`.

- 2026-10-01, PR #493

## A mechanical receipt check

In SKILL.md stage 4, run the coverage-phrase grep over the implementer's commits, so that a hit
the comment-rules item doesn't account for fails it. Set aside because the post-execution
reviewer runs the same grep at stage 6.

- 2026-10-01, PR #493

## Measured ranges in the scope paragraph

In `scope-clarification.md`, have a factual claim the scope paragraph rests on state the range
it was measured over, or say it is unverified. Set aside because plan review re-checks those
facts before any code exists, and did so in #493.

- 2026-10-01, PR #493

## A rule on comment volume

Cap or otherwise limit how many comment lines a PR adds. Set aside because, under the comment
rules, #493 added far fewer comment lines per line of code than #482 or #487.

- 2026-10-01, PR #493

## A smaller ExecPlan

Trim the living-document sections, or the rule to add a revision note, so `plan.md` stays
smaller. Set aside because the plan was about a tenth of the subagents' tokens in #493, and its
living sections are what let the cycle recover after an interruption.

- 2026-10-01, PR #493

## Older claims to follow-up issues

When a PR's review finds false claims in older text the PR touched, file them as issues instead
of fixing them in the PR. Set aside because fixing them shrinks the backlog, the PR had made
several of them false, and the fixes were cheap.

- 2026-10-01, PR #493

## Counting words in comment corrections

Have stage 8's "a correction to a comment may not lengthen it" count words, not lines. Set
aside because the corrections that failed went wrong in what they said, not in how long they
were.

- 2026-10-01, PR #493

## Lower token use per cycle

Spawn reviewers fresh instead of resuming them, hand subagents sections instead of whole files,
or set a budget. Proposed because #493's cycle reached the account's weekly usage limit. Set
aside because each option gives a subagent less to work from.

- 2026-10-01, PR #493
