# r-package-dev-skill

A rigorous development workflow for **statistical and numerical R packages** (the kind that
implement an estimator, a model, or an algorithm against a documented methodology), packaged as
a skill for coding agents.

The idea is that the input to the skill is a reasonably well-defined issue for an R package, and the output is a PR solving the issue ready for your review.

## The cycle

    clarify scope  →  ExecPlan  →  plan review + sentinel  →  implement
                  →  CRAN gate  →  post-exec review + sentinel
                  →  disposition sweep  →  PR to main

The cycle combines subagents, review before and after implementation, and one unconditional
CRAN gate. The agent never commits to the default branch; whether it may merge is set by the
profile's `Governance` field, which defaults to "no."

## Design notes

The skill uses a *profile* (more details below) that characterizes the package instead of parameters because the repo-specific surface is smaller
than it looks. It consists of build commands, the authority document, the naming and error
conventions, the public API, and a handful of gotchas that cost real time to re-derive.
Everything else generalizes.

Some profile fields switch the process in addition to describing it. The table in
[USAGE.md](USAGE.md#your-first-cycle-is-cleaning-the-gate) lists which fields these are and
what each one switches, and the template marks them **[switch]** where they are filled in.

The lessons keep their stories and their real names, because anonymizing them would make them
vaguer without making them more general. Instead, the provenance is disclosed once up front and
the specifics are left intact. The catalogue is indexed for skimming and cross-linked to
wherever the operational detail is documented.

Target selection and prioritization (tier ordering, heuristics, the queue) deliberately stayed
repo-local. Those are genuinely per-package, because the tiers are calibrated to one package's
bug history and one methodology's constraints.

## What you need first

Check these before you start:

- **A coding-agent harness with subagents.** The skill assumes subagents are available for reviewing. A harness without subagents can still run this manually;
  see [`harness-notes.md`](references/harness-notes.md).
- **R, plus `devtools`, `testthat`, `urlchecker`, and `spelling`.** The last two are separate
  CRAN packages rather than part of devtools, and the gate calls both. Install the packages
  with `install.packages(c("devtools", "urlchecker", "spelling"))` (or ask your agent to do it when you load the skill).
- **A formatter, or a deliberate `none`.** The profile records whether the package uses [`air`](https://tidyverse.org/blog/2025/02/air/) (preferred)
  or `styler`, and `none` is a valid answer that stops the agent introducing one.
- **`gh`, authenticated, against a GitHub remote.** PR creation, CI status, and the
  disposition sweep's "file an issue" path all shell out to `gh`. GitLab and Bitbucket have
  no path here today.
- **Willingness to gitignore `.workflow/` and `.plans/`.** `bootstrap-repo.sh` adds them,
  along with `.claude/`, to your tracked ignore files. (Or you can specify you don't want them ignored if you want.)
- **Optional: a `UserPromptSubmit` hook.** It works around a Claude Code bug that silently
  suppresses subagents, at the cost of hand-editing `~/.claude/settings.json` and running a
  script on every prompt in every repo; see [`harness-notes.md`](references/harness-notes.md).

If you are installing somewhere other than Claude Code, set `AGENT_SKILLS_DIR` (by default
`~/.claude/skills`) to wherever your harness looks for skills.

## Install

You can do the below yourself or just ask your coding agent to do it.

```bash
git clone https://github.com/gregfaletto/r-package-dev-skill.git
cd r-package-dev-skill
bash scripts/install.sh          # symlinks it where your agent looks for skills
```

`SKILL.md` is the entry point and router, and everything substantive is in
[`references/`](references/). The workflow requires subagents, but beyond that it is plain
markdown; see [`references/harness-notes.md`](references/harness-notes.md) for the mapping onto
a specific agent harness.

Then, in any R package repo that doesn't have one yet:

```bash
bash scripts/bootstrap-repo.sh   # run from the package's repo root
```

That scaffolds `.workflow/` and `.plans/`, copies in the profile template, and adds the
gitignore entries, plus the matching `.Rbuildignore` regexes when a `DESCRIPTION` is present.

Expect your first cycle to be cleaning the CRAN gate--the skill will want your package to be CRAN-ready after each PR, sothe first step may be getting your current package CRAN-ready.
[USAGE.md](USAGE.md#your-first-cycle-is-cleaning-the-gate) owns what that involves. The skill also needs basic information about your package, called a *profile*. Direct your coding agent to follow
[`references/adoption.md`](references/adoption.md) to derive the profile for your package field by field.

[USAGE.md](USAGE.md) is the human's guide. It covers what a session looks like, what you'll be
asked for, how to steer it faster or slower, which output files are worth reading, and what to
do when something goes wrong. Everything else in this repo is written for the agent.

## Scope

The skill is written for R packages implementing statistical or numerical methodology, usually
CRAN-published (or at least CRAN-ready). Plain devtools packages and literate/generated ([litr](https://jacobbien.github.io/litr-project/)) packages are both in
scope, as are roxygen2, testthat, and each of S3, S4, R6, and S7. The formatter may be `air`,
`styler`, or none, and CI may be present or absent.

The skill is also usable outside that target, with substitutions. The planning format, the
subagents, the review discipline, the git workflow, the object-systems reference, and most of
the lesson catalogue transfer unchanged to a non-numerical package, such as a web client, a
data-wrangling or visualization package, or developer tooling. The periodic-review lenses,
which are organized around estimator cores and shared math machinery, do not transfer
unchanged, and neither do the rank-deficiency and variance-convention checks in the reviewer or
the simulation-study discipline. Substitute your own lenses rather than applying those
vacuously.

Governance models other than a single maintainer who reviews and merges everything are
supported but thinly tested. The `team` and `outside-contributor` paths are written down, but
the workflow was derived from single-maintainer repos. Where a repo's `CONTRIBUTING.md` or
branch protection rules disagree with the skill, they win.

The skill does not yet cover Bioconductor (different branch model, `BiocCheck`, six-month
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

## Editing this skill

One file owns each rule, and everything else points at it. `cran-gate.md` owns the gate bars,
`execplan.md` the acceptance criteria and the name of every file the cycle writes,
`git-and-pr.md` the PR and NEWS conventions, and `object-systems.md` the per-system checks.
Each subagent is briefed with the files it needs, listed in its brief's Orchestrator block,
precisely so that the briefs can point rather than restate.

That structure is recent. Before it, briefs restated rules because a clean-context subagent
cannot follow a relative link. Three separate times, a rule was corrected in one file while
another kept the old wording, which is worse than missing the correction entirely, because the
corrected file makes it look done. If you add a rule, decide which file owns it and point from
everywhere else. Before committing a change to any gate bar, check for stragglers:

```bash
grep -rn "spell_check\|url_check\|error_on\|FAIL 0\|NEWS\|test_file\|edition" \
  --include="*.md" . | grep -v '\.git'
```

Read every hit and decide whether it states the bar or merely names the command. The same
duplication this skill exists to remove between two repos is present inside the skill for a
reason. The briefs must be self-contained, so the duplication is managed rather than
eliminated.

The artifact names have their own sweep, because they went wrong in the way this section
describes. They were prescribed in one file, derived rather than stated in a brief, and written
under a different spelling by every cycle that ran:

```bash
grep -rn "plan_review\|sentinel_pre\|sentinel_post\|post_execution_review\|_pr_description" \
  --include="*.md" . | grep -v '\.git'
```

Every hit must be the one spelling `execplan.md` § "Artifact names" defines, and every file
naming one must point there. A name that appears only in a brief is a name the brief owns by
accident.

Prose wraps at 95 characters, and `awk` is the wrong tool to check it. This corpus is full of
em-dashes, `§` and `→`, all multi-byte, and macOS `awk` has no multibyte support at all.
`awk 'BEGIN{print length("—")}'` prints 3 in every locale, `C` and UTF-8 alike, so no locale
setting fixes it. The obvious sweep therefore names lines that are not over the limit, and
rewrapping those lines leaves the paragraph worse than it started. Count characters:

```bash
python3 - <<'EOF'
import glob, io
for f in glob.glob('**/*.md', recursive=True):
    for i, l in enumerate(io.open(f, encoding='utf-8'), 1):
        if len(l.rstrip('\n')) > 95: print(f"{f}:{i}: {len(l.rstrip())}")
EOF
```

Tables, fenced code, and rows that are mostly one link are exempt and will be named every time;
the wrap is a rule about prose. When a real overflow does turn up, rewrap the whole paragraph,
because moving one word off the end only pushes the overflow onto the next line.

Run `Rscript scripts/check-docs.R` before you commit. It resolves every relative link and every
`#anchor`, and checks `## Contents` blocks in both directions. Anchors have broken silently
here before. Because GitHub's slugger does not collapse whitespace, a heading with a spaced
em-dash yields a double hyphen. `--self-test` runs it against planted defects and planted valid
constructs. Use it if you change the script, since a checker that shares the generator's bug
reports zero problems and is worse than none.

Run `Rscript scripts/check-briefs.R` too. Each brief's `> **Orchestrator:**` block names the
files that subagent is handed. A clean-context agent cannot follow a pointer out of that set,
whether it is a relative link or a prose pointer like "search it for `X`" or "§ Test
discipline". `check-docs.R` cannot see prose pointers at all, because they are not links.
`check-briefs.R` resolves every such pointer in each brief and in every file that brief hands
over.

It exits 0 on a clean tree, and both `BROKEN` and `CHECKER CANNOT DO ITS JOB` decide that
status. Every line in `BROKEN` is a pointer your change made unfollowable, and that list is the
obligation. A `CHECKER CANNOT DO ITS JOB` block means a brief never entered the run, and
nothing else in the output means anything until it is fixed. The `UNCLEAR` block is the only
one that never gates. It names a pointer no rule could run through, so read it and judge rather
than contorting prose to empty it. `--self-test` covers the script the same way.

The script takes the set of files a pointer may name from `SKILL.md`'s Reference map, so a new
reference file needs its row there before anything pointing at it is checked. The files it
expects to be briefs are declared rather than recognized by their contents: everything under
`references/subagents/`, plus the names in the script's `BRIEFS_OUTSIDE_SUBAGENTS`. That list
holds `guides/periodic-review.md`, because a runbook that contains a brief looks like any other
guide. A brief added outside that directory needs its name there, or nothing notices when it
stops being one.

A pointer addressed to the orchestrator is exempt, because the orchestrator holds the whole
skill and can follow any link. The exemption covers anything inside a `> **Orchestrator:**`
block. In a runbook that contains a brief (the way `guides/periodic-review.md` hands over only
its lens sections), it also covers everything from a
`> **Orchestrator through the end of this section.**` line down to the next heading, whatever
its level. Use that marker when the checker flags prose you hold rather than hand over, and do
not add the file to that brief's "Brief it with" list instead. Adding it there silences the
report by claiming a subagent receives something it does not, and it disarms every check that
ran through that file.

Run `Rscript scripts/check-fields.R` when you change an instruction or the template. It is the
inverse of `check-briefs.R`: that checker finds a pointer reaching nothing, and this one finds
a field nothing points at. `check-profile.R` derives what a profile must contain from
`templates/PROFILE.md` at run time, so a field written there is demanded of every adopting repo
forever, including one whose only reader was an instruction you just rewrote. That is how a
field for the minimum formatter version outlived the sentence that read it, while every
self-test stayed green.

The `FIELDS NOTHING READS` list is the obligation. The `ADVISORY` and `NOT CHECKED` blocks
below it never gate, so read them and judge rather than contorting prose to empty them. A field
has to clear both of the following before it can fail the run. It must be **operative**,
meaning that the field has its own **[switch]** tag or appears anywhere under a heading the
template marks. As a result, most fields that gate do so by position rather than by a tag of
their own. The field's name must also reduce to more than one content word. `Governance`, `CI`,
and `Formatter` are each one ordinary word that any paragraph using it satisfies, so the
switches with the shortest names are listed in `NOT CHECKED`. They never fail the run, which is
why that block is printed. Everything else is advisory. The reasoning, and what those bars give
up, is in the script's header. `--self-test` covers it the same way as the others.

`execplan.md`'s ban on counting occurrences covers this repo's own text. Phrases such as
"Catches three specific drift classes", "the four subagent briefs" and "19 acceptance criteria"
have all appeared here, and all went stale. Describe what a file does, and never state how many
things are in it. Nothing checks the ban, and nothing should. A detector for the form shipped
here for a while and spent more edits on its own upkeep than it ever saved. That upkeep is the
same cost the rule exists to avoid. The rule is guidance for whoever is writing, and it costs
nothing to state.

## License

MIT; see [LICENSE](LICENSE).

`references/execplan.md` derives its structure from the OpenAI Cookbook's
[ExecPlans article](https://github.com/openai/openai-cookbook/blob/main/articles/codex_exec_plans.md)
(MIT, Copyright (c) 2025 OpenAI); see [NOTICE](NOTICE) for what is derived and what is not.
