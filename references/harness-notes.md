# Harness notes

## Contents

- [The one hard requirement](#the-one-hard-requirement)
- [Mapping the briefs onto your harness](#mapping-the-briefs-onto-your-harness)
- [Absolute paths, always](#absolute-paths-always)
- [Have subagents write as they go](#have-subagents-write-as-they-go)
- [Entry points](#entry-points)
- [Install location](#install-location)
- [Known harness bugs — dated, verify before acting](#known-harness-bugs--dated-verify-before-acting)

---

Everything else in this skill is plain markdown that any coding agent can follow. This file
holds the one part that isn't: **how you actually spawn a subagent**, and what to do when
your harness names things differently.

Read it once at the start of a session, then use whatever your harness provides.

## The one hard requirement

**Subagents.** The cycle spawns a plan reviewer, an implementer, a post-execution reviewer, and
the drift sentinel on both its pre-implementation and its post-implementation pass; the
periodic review fans out one agent per lens, all at once, which is the concurrency your harness
has to supply. This is not decoration — it is the mechanism:

- The **plan reviewer must not be the plan's author.** A reviewer that shares the author's
  context inherits the author's blind spots and agrees with itself.
- The **post-execution reviewer reads the diff directly**, not the implementer's summary. A
  summary is the implementer's account of what it did; the diff is what it did.
- The **implementer runs in a clean context** so the orchestrator's context isn't consumed by
  diff and test output. This one is an efficiency argument rather than a correctness one, so
  it degrades gracefully — see below.

A harness with no subagent primitive can still run this workflow, but the correctness points
have to be preserved manually: start a fresh session, paste the brief, and hand back the
output file. That works. It is slower, and it puts the burden on you rather than the
orchestrator, which is exactly the kind of friction that leads to skipped steps — so if your
harness has subagents, use them.

**A harness bug currently defeats this requirement silently.** See
[Known harness bugs](#known-harness-bugs--dated-verify-before-acting) — quarantined there
because it will stop being true.

## Mapping the briefs onto your harness

Each brief in [`subagents/`](subagents/) opens with an **Orchestrator** block
saying when to spawn, what to brief with, and when *not* to. That content is
harness-agnostic. What varies is the call:

| The brief says | You need |
|---|---|
| "spawn a subagent" | Your harness's subagent/task primitive, with a general-purpose or default agent type |
| "brief it with X, Y, Z" | Those paths in the prompt — **absolute paths**, see below |
| "spawn one agent per lens, concurrently, in one batch, in the background" | Whatever concurrency your harness offers; sequential works, it is just slower |
| "the sentinel's `Verdict: BLOCKED` gates the push" | Read the verdict line out of the output file; the string is deliberately greppable |

**Claude Code:** the `Agent` tool, `subagent_type: general-purpose`, and
`run_in_background: true` for the periodic review's fan-out.

**Other harnesses:** use the equivalent primitive. Nothing in the briefs depends on a
specific tool name.

## Absolute paths, always

**A subagent starts with a clean context. It has not loaded this skill, and the relative
links inside these files mean nothing to it.**

Resolve the skill root once at the start of a session — the directory containing `SKILL.md`
— and pass absolute paths in every brief. A brief pointing at an unresolvable path produces
a subagent that reviews from priors and reports confidently, which is indistinguishable from
a real review and worse than no review at all, because it manufactures false assurance.

If you cannot state the absolute path of the brief you are handing over, find it before
spawning.

**Pass every file a brief's Orchestrator block names, not just the brief.** Each brief lists
the files that own the rules it checks against — the gate bars, the acceptance criteria, the
object-system checks. They are listed because a brief that *pointed* at them without being
given them would point at nothing, and the alternative — copying the rules into each brief —
is how the same rule ends up stated in five files and corrected in three. Every brief also
opens by checking what it received and reporting anything missing, so an omission surfaces as
"NOT PERFORMED" rather than as a bar reconstructed from priors.

## Have subagents write as they go

**Each brief that produces a review file tells its own subagent to create that file on its
first finding and append as it works, headed `IN PROGRESS` until it finishes** — the planning
reviewer's, the sentinel's, and the post-execution reviewer's, each in the section that already
owns where its output goes. The instruction lives in the brief rather than in your prompt
because the brief is handed over every time; an orchestrator asked to retype a reliability rule
into every spawn eventually does not, and the post-execution reviewer's expectation that a live
sentinel pass is "still headed `IN PROGRESS`" would then be a claim about a header nothing
wrote. The implementer's analogue is its own rule to commit on the branch as it goes. You do
not need to repeat any of it.

A reviewer that composes its whole file at the end loses everything if it is killed mid-run —
by a usage limit, a timeout, or a crash — including the expensive measurements it already made.
Partial findings you can read are worth far more than a clean slate, and a stale `IN PROGRESS`
header is an unmistakable signal that the pass did not complete and its checks are not covered.

## Entry points

The same content has more than one front door, and they are pointers, not copies:

- **`SKILL.md`** — for harnesses that load skills from a skills directory with YAML
  frontmatter, on demand, when the description matches.
- **`AGENTS.md`** — for harnesses that read a repo-root agent file, usually always-loaded.
  Deliberately short for that reason, and it defers to `SKILL.md` rather than restating it.

If you add one for another harness, make it a pointer too.

## Install location

`scripts/install.sh` symlinks the repo into `$AGENT_SKILLS_DIR`, defaulting to
`~/.claude/skills`. Override it for another harness:

```bash
AGENT_SKILLS_DIR=~/.config/your-agent/skills bash scripts/install.sh
```

Nothing else in the skill depends on where it lives, as long as the orchestrator can resolve
that path and pass it on.

---

## Known harness bugs — dated, verify before acting

*Vendor bugs, recorded because they defeat this workflow silently. Each is dated; re-check
before working around it, and delete the entry once it is fixed.*

**Claude Code on Opus 5 and Opus 5.5** injects a model-gated system-prompt section reading *"Do
not call the AgentTool unless the user requested it."* It is not a user setting, there is no
local opt-out, and it is not announced — the visible symptom is an agent that reports it
"carries a standing instruction not to spawn subagents," then does every stage inline. Every
subagent check in this skill silently becomes self-review. (Observed on 2.1.220 with Opus 5,
and with Opus 5.5 in September 2026;
[claude-code#80988](https://github.com/anthropics/claude-code/issues/80988),
[#82371](https://github.com/anthropics/claude-code/issues/82371). Check whether it still
applies before working around it.)

The instruction has its own escape clause — *unless the user requested it* — so the fix is to
make the request, in the user's voice, where the agent will read it:

- **In the repo's entry point** (`AGENTS.md` / `CLAUDE.md`), as a standing request that
  **names the occasions**: the plan review, both sentinel passes, delegated implementation,
  the post-execution review. Phrasing matters more than it should. A policy-shaped rule
  ("delegate multi-file work") is read as advice and loses to the system prompt; a request
  that enumerates when to spawn survives. Add "if you decide not to delegate here, say so and
  say why" — it converts a silent failure into a visible one.
- **Optionally, a `UserPromptSubmit` hook** emitting the same text. Hook output arrives as
  user-side context on every turn, which is a stronger match for the escape clause than a file
  the agent may or may not re-read. Costs ~150 tokens per turn. A working script lives at
  `scripts/delegation-standing-request.sh`; copy it to `~/.claude/hooks/`, `chmod +x` it, and
  add this to `~/.claude/settings.json`, merging into whatever that file already contains
  rather than replacing it:

      "hooks": {
        "UserPromptSubmit": [
          { "hooks": [ { "type": "command",
                         "command": "sh \"$HOME/.claude/hooks/delegation-standing-request.sh\"" } ] }
        ]
      }

  Settings are re-read per prompt, so it takes effect on the next message rather than the next
  session. **The suppression does not fire every session** — two sessions minutes apart on the
  same version behaved differently, one asking permission and one delegating freely. So a
  single clean session does not prove the hook worked, and a single hedging session before you
  install it does not prove you need it.

**Do not reach for `CLAUDE_CODE_SIMPLE=1`.** It is an alias for `--bare`: it removes the
Agent tool outright, disables hooks — including the workaround above — and stops reading
`CLAUDE.md`. It solves the message by removing the capability.

**On 2026-10-01 the Claude Code desktop app's PR monitor did not relay a review comment that
another session had posted under the maintainer's account**, and the session answering reviews
waited about two hours for it. The cause is unconfirmed. When reviews can arrive that way, poll
`gh pr view <n> --json comments,reviews` instead of relying on the monitor.
