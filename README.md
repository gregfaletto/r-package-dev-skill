# r-package-dev-skill

This is a rigorous development workflow for **statistical and numerical R packages** (the kind
that implement an estimator, a model, or an algorithm against a documented methodology),
packaged as a skill for coding agents.

The idea is that the input to the skill is a reasonably well-defined issue for an R package,
and the output is a PR solving the issue ready for your review.

## The cycle

    clarify scope  →  ExecPlan  →  plan review + sentinel  →  implement
                  →  CRAN gate  →  post-exec review + sentinel
                  →  disposition sweep  →  PR to main

The cycle combines subagents, review before and after implementation, and one unconditional
CRAN gate. The agent never commits to the default branch. Whether it may merge is set by the
profile's `Governance` field, which defaults to "no."

## Design notes

The skill uses a *profile* (more details below) that characterizes the package instead of
parameters because the repo-specific surface is smaller than it looks. It consists of build
commands, the authority document, the naming and error conventions, the public API, and a
handful of gotchas that cost real time to re-derive. Everything else generalizes.

Some profile fields switch the process in addition to describing the package. The table in
[USAGE.md](USAGE.md#your-first-cycle-is-cleaning-the-gate) lists which fields these are and
what each one switches, and the template marks them **[switch]** where they're filled in.

I kept the lessons' stories and real names, because anonymizing the lessons would make them
vaguer without making them more general. The catalogue is indexed for skimming and cross-linked
to wherever the operational detail is documented.

I deliberately kept target selection and prioritization (tier ordering, heuristics, the queue)
repo-local. They really are per-package, because the tiers are calibrated to one package's bug
history and one methodology's constraints.

## What you need first

Check these before you start:

- **A coding-agent harness with subagents.** The skill assumes subagents are available for
  reviewing. A harness without subagents can still run this manually (see
  [`harness-notes.md`](references/harness-notes.md)).
- **R, plus `devtools`, `testthat`, `urlchecker`, and `spelling`.** The last two aren't part of
  devtools. They're separate CRAN packages, and the gate calls both. Install the packages with
  `install.packages(c("devtools", "urlchecker", "spelling"))` (or ask your agent to do it when
  you load the skill).
- **A formatter, or a deliberate `none`.** The profile records whether the package uses
  [`air`](https://tidyverse.org/blog/2025/02/air/) (preferred) or `styler`, and `none` is a
  valid answer that stops the agent from introducing one.
- **`gh`, authenticated, against a GitHub remote.** PR creation, CI status, and the disposition
  sweep's "file an issue" path all shell out to `gh`. GitLab and Bitbucket have no path here
  today.
- **Willingness to gitignore `.workflow/` and `.plans/`.** `bootstrap-repo.sh` adds them, along
  with `.claude/`, to your tracked ignore files. (Or you can specify you don't want them
  ignored if you want.)
- **Optional: a `UserPromptSubmit` hook.** It works around a Claude Code bug that silently
  suppresses subagents. The cost is hand-editing `~/.claude/settings.json` and running a script
  on every prompt in every repo (see [`harness-notes.md`](references/harness-notes.md)).

If you're installing somewhere other than Claude Code, set `AGENT_SKILLS_DIR` (by default
`~/.claude/skills`) to wherever your harness looks for skills.

## Install

You can do the below yourself or just ask your coding agent to do it.

```bash
git clone https://github.com/gregfaletto/r-package-dev-skill.git
cd r-package-dev-skill
bash scripts/install.sh          # symlinks it where your agent looks for skills
```

`SKILL.md` is the entry point and router, and everything substantive is in
[`references/`](references/). The workflow requires subagents, but beyond that it's plain
markdown; see [`references/harness-notes.md`](references/harness-notes.md) for how it maps onto
a specific agent harness.

Then, in any R package repo that doesn't have one yet:

```bash
bash scripts/bootstrap-repo.sh   # run from the package's repo root
```

That scaffolds `.workflow/` and `.plans/`, copies in the profile template, and adds the
gitignore entries, plus the matching `.Rbuildignore` regexes when a `DESCRIPTION` is present.

Expect your first cycle to be cleaning the CRAN gate—the skill will want your package to be
CRAN-ready after each PR, so the first step may be getting your current package CRAN-ready.
[USAGE.md](USAGE.md#your-first-cycle-is-cleaning-the-gate) explains what that involves. The
skill also needs basic information about your package, called a *profile*. Direct your coding
agent to follow [`references/adoption.md`](references/adoption.md) to derive the profile for
your package field by field.

[USAGE.md](USAGE.md) is the human's guide. It covers what a session looks like, what you'll be
asked for, how to steer it faster or slower, which output files are worth reading, and what to
do when something goes wrong. Everything else in this repo is written for the agent.

## Scope

The skill is written for R packages implementing statistical or numerical methodology, usually
CRAN-published (or at least CRAN-ready). Plain devtools packages and literate/generated
([litr](https://jacobbien.github.io/litr-project/)) packages are both in scope, as are
roxygen2, testthat, and each of S3, S4, R6, and S7. The formatter may be `air`, `styler`, or
none, and CI may be present or absent.

You can also use the skill outside that target, with substitutions. The planning format, the
subagents, the review discipline, the git workflow, the object-systems reference, and most of
the lesson catalogue transfer unchanged to a non-numerical package, like a web client, a
data-wrangling or visualization package, or developer tooling. But the periodic-review lenses,
which are organized around estimator cores and shared math machinery, don't transfer unchanged.
Neither do the rank-deficiency and variance-convention checks in the reviewer, or the
simulation-study discipline. Substitute your own lenses instead of applying those vacuously.

Governance models other than a single maintainer who reviews and merges everything are
supported but thinly tested. The `team` and `outside-contributor` paths are written down, but
the workflow was derived from single-maintainer repos. Where a repo's `CONTRIBUTING.md` or
branch protection rules disagree with the skill, they win.

The skill doesn't yet cover Bioconductor (different branch model, `BiocCheck`, six-month
release cycle), non-testthat frameworks, compiled code in `src/`, or `renv` and similar project
layers. Only the gate and the release model need local adjustment there.

## What's in it

    SKILL.md                                the loop, the non-negotiables, scope, routing
    AGENTS.md                               same, for harnesses that read a repo-root file
    references/
      scope-clarification.md                stage 1 — the questions that scope an issue
      execplan.md                           format, skeleton, criteria, artifact names
      cran-gate.md                          R loop, the gate, CI, formatting, test discipline
      git-and-pr.md                         branching, PR style, stacked-PR traps
      object-systems.md                     S3 / S4 / R6 / S7 — dispatch, export, validators
      adoption.md                           setting up a new package; deriving the profile
      harness-notes.md                      spawning subagents; the absolute-path rule
      lessons.md                            indexed failure modes, with the stories
      subagents/
        plan-reviewer.md                    pre-implementation review
        implementer.md                      delegated implementation
        sentinel.md                         drift checks; its BLOCKED gates the push
        post-exec-reviewer.md               pre-merge review
    guides/
      periodic-review.md                    the quarterly codebase sweep — occasional
      litr.md                               only for packages built from a source document
    templates/
      PROFILE.md                            the per-repo contract (a form, not anyone's answers)
    scripts/
      install.sh                            symlink into your agent's skills dir
      bootstrap-repo.sh                     scaffold a repo
      delegation-standing-request.sh        UserPromptSubmit hook — see harness-notes.md
      check-docs.R                          link and anchor checker for this repo's markdown
      check-briefs.R                        every pointer a brief hands out has to resolve
      check-fields.R                        every field the template defines has to be named
      check-profile.R                       checks a repo's PROFILE.md against the template
    USAGE.md                                the human's guide — start here
    CONTRIBUTING.md                         editing the skill itself

## License

MIT; see [LICENSE](LICENSE).

`references/execplan.md` derives its structure from the OpenAI Cookbook's
[ExecPlans article](https://github.com/openai/openai-cookbook/blob/main/articles/codex_exec_plans.md)
(MIT, Copyright (c) 2025 OpenAI). See [NOTICE](NOTICE) for what's derived and what isn't.
