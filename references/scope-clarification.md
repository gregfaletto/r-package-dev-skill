# Clarifying an issue's scope

Stage 1 of the standard cycle: turning an underspecified issue into a scope paragraph the
plan can be measured against, before any plan is drafted.

## The protocol

1. Read the issue end to end — description, every comment, cross-referenced commits and
   PRs. Read the relevant part of the profile's authority document.
2. List the ambiguities explicitly: scope (which functions? which estimators?), the
   behavior contract (input/output before vs after), backward compatibility (breaking
   change or opt-in argument?), edge cases, correctness authority (which equation /
   spec section?), and what test would have failed before and passes after.
3. Ask **specific, narrow questions** in chat. Not "what do you want?" but "should this
   also affect `etwfe()`, or just `fetwfe()`?" Three or four pointed questions usually
   converge in one round; two rounds is the upper end.
4. **Restate the clarified scope in one paragraph and get a yes.** Phrase it as the
   ExecPlan's `Purpose / Big Picture` section. That confirmed paragraph is the seed of
   the plan and the yardstick for the final alignment check.
5. Record the outcome: clarified scope → `Purpose / Big Picture`; decisions made during
   the dialogue → `Decision Log` with rationale; **any question that came back without an
   answer → `Questions for the Maintainer`**, dated, per acceptance criterion 20. That
   section is where a question you ask at *any* stage goes, and from stage 2 on you write
   the entry in the same action as asking. No plan exists yet at this stage, so **the plan's
   first content is stage 1's questions** — transcribing every one of them, in the words you
   used, dated the day you asked, carrying whatever became of it, is the opening act of
   drafting the plan rather than a later tidy-up.

If three rounds have not converged, stop and say the scope is still unclear. The issue
may need splitting, deferring, or rewriting before any plan is feasible.

## Confirm the work is not already done

**Before committing time, confirm the target isn't already done or in flight.** These
repos use `Refs #N` for partial PRs, so "open" issues are often already resolved or
partly resolved by a merged PR:

```bash
git fetch origin && git log --oneline --grep "#N" && git branch -a --list "*<keyword>*"
```

If fully done, propose closing the issue rather than coding it. If partly done, scope
the plan to the genuine remainder and cite the PR.
