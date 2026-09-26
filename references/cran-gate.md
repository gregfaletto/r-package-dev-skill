# The R loop and the per-PR CRAN gate

## Contents

- [The mental shift](#the-mental-shift)
- [The fast loop](#the-fast-loop)
- [The per-PR CRAN gate](#the-per-pr-cran-gate)
- [Formatting](#formatting)
- [Continuous integration](#continuous-integration)
- [Test discipline](#test-discipline)
- [Export discipline: internal vs public](#export-discipline-internal-vs-public)
- [Error messages worth knowing](#error-messages-worth-knowing)
- [A worked failure mode: drift between code and spec](#a-worked-failure-mode-drift-between-code-and-spec)

---

## The mental shift

Your verification gate is *test coverage*, not "the file loads." Lean on `devtools::test()` and
`devtools::check()` aggressively — "I loaded the file with no errors" is much weaker evidence
in R than "I built the file" is in a compiled language.

A 30-line refactor with no test changes is suspicious.

## The fast loop

    devtools::load_all()                                  # re-source every R/*.R
    <make a change>
    <exercise it interactively on a small input>
    devtools::test(filter = "<pattern>")                  # one file, seconds
    devtools::test()                                      # full suite, when the file is green

Use the slow gate (`check()`) when you're about to commit, not on every save. The ordering
is invariant — a filtered `test()` ≪ a full `test()` ≪ `check()` — but **the skill states no
numbers, because they are per-repo, per-machine, and they go stale as the suite grows.** The
profile records the measured figures; if it doesn't, or if they are undated, measure once and
record them there before you rely on them.

A suite that tripled in size over three months turned a "1–2 minute" figure into nine minutes
without anyone noticing, and a mutation battery designed against the stale number ran for two
hours. **The number's age matters as much as the number.**

**Not `devtools::test_file()`** — it is *defunct* as of devtools 2.5.0, and calls
`lifecycle::deprecate_stop()`, so it errors rather than warning. `test(filter = …)` is the
replacement for an agent: the filter is a regex matched against test file names with the
`test-` prefix and `.R` suffix stripped, and it runs inside the package context via
`load_all()`, which bare `testthat::test_file()` does not.

Keep a smoke snippet handy — the profile names one for the repo — and re-run it whenever
you want feedback.

**Generated / literate packages differ** — no `load_all()` loop, and a green build is itself
a test result. The build command and its clear-the-intermediates prelude are in the profile's
§ 2.

## The per-PR CRAN gate

Every PR must leave the package CRAN-ready. Run it in this order — earlier failures make
later output less informative, but run them all, since categories coexist.

From a shell at the repo root — the profile's formatter command (see
[Formatting](#formatting) below; `air format .` in the examples here):

    air format .

Then from an R session at the repo root:

    # urlchecker and spelling are separate CRAN packages, not part of devtools:
    #   install.packages(c("urlchecker", "spelling"))
    # A missing one is a setup failure, not a gate finding and not part of the accepted
    # exceptions list. So is a toolchain failure: check() probes for a compiler even with no
    # src/, so a broken one kills it in seconds with `Could not find tools necessary to
    # compile a package`. Never report a gate as passing on a check() that never ran.
    devtools::document()                       # regenerate man/*.Rd + NAMESPACE
    devtools::test()                           # full testthat suite
    devtools::check(error_on = "note")         # CRAN-strict R CMD check; fails on any NOTE
    devtools::spell_check()                    # typos in DESCRIPTION/README/NEWS/man/vignettes
    urlchecker::url_check()                    # nothing beyond the accepted exceptions list
    # Optional, only to eyeball rendered vignette HTML:
    # tools::buildVignettes(dir = ".")

The profile overrides the exact invocation where a repo differs — a generated package checks
a subdirectory and has its own mandatory flags, both of which are in the profile's § 3.

### Why `error_on = "note"`, and not `args = "--as-cran"`

Defaults in `devtools::check()` that are easy to get wrong, and that make the obvious
invocation strictly worse than the one above. *Read off devtools 2.5.2, 2026-08-23; re-check
before relying on one.*

**`force_suggests` defaults to `FALSE`; bare `R CMD check` defaults it to `TRUE`.** A
`Suggests:` entry naming a package you have not installed is silent here and an ERROR there.
Install every entry before checking a changed `Suggests:` field — `force_suggests = TRUE`
raises that ERROR for a package you merely lack, and stops before the examples that catch an
unguarded call.

**`error_on` defaults to a value that lets NOTEs through.** The default is `"never"`
interactively, but the body does `if (missing(error_on) && !interactive()) error_on <-
"warning"`. So `Rscript -e 'devtools::check()'` **exits 0 on a run with NOTEs.** An agent
that treats the exit status as the verdict reports a clean gate on a package that would fail
the 0/0/0 criterion — the same empty-grep-read-as-pass shape that
[§ Test discipline](#test-discipline) below exists to prevent, moved from `test()` to
`check()`. Passing `error_on = "note"` makes the criterion enforce itself instead of relying
on you to read the output honestly.

**`args = "--as-cran"` is redundant.** `cran = TRUE` is already the default, and
`check_built()` does `if (cran) args <- c("--as-cran", args)` — so the flag is added for you,
and passing your own `args` replaces the `"--timings"` default. The timing report survives
that: `--as-cran` sets `_R_CHECK_TIMINGS_` and `do_timings` itself, both inside its own branch
in `tools:::.check_packages`. Leave `args` alone anyway — the flag is already there.

If you need CRAN's incoming-feasibility and remote checks, that is `remote = TRUE` — but
those are submission-time, not per-PR. **This is why `urlchecker::url_check()` is a separate
line in the gate:** the local check deliberately skips the remote URL checking that CRAN
runs on submission, so a local 0/0/0 is not the same verdict CRAN will give you.

### Expected results and triage

**`check(error_on = "note")` → `0 errors ✔ | 0 warnings ✔ | 0 notes ✔`, exit status 0.**
Anything else is a finding on your branch, and **every one is reported, pre-existing or not**
— the profile's § 3 accepted exceptions list changes a finding's *disposition*, never whether
your run says it fired. The maintainer would rather be annoyed by the same message every
cycle than lose a fixable warning you never reported, which is the answer to the next
proposal to trim this for noise. A NOTE that already exists on `main` is not *this PR's*
problem, but it is the package's: either it is on the accepted exceptions list with a reason
— **putting one there is the maintainer's call, not yours** — or the package skipped the
clean-up that adoption requires and the right response is to say so, not to absorb it
silently. Verify pre-existence by running the same check on the default branch **in a tree
extracted with `git archive`**, which needs no checkout and so is open to a reviewer — who is
forbidden `git checkout`, `git stash`, and `git reset`. `git archive` extracts **tracked
files only**, which is why the extracted tree matches a clean checkout. Extract it under
**your own scratch directory, never a shared path**: a subagent's is
`.plans/<branch>/scratch/<role>/`, the orchestrator's its own subdirectory under
`.plans/<branch>/scratch/`. Remove only what you made there.

```bash
mkdir -p <scratch>/base-check && git archive <default-branch> | tar -x -C <scratch>/base-check
(cd <scratch>/base-check && Rscript -e 'devtools::check(error_on = "note")')
rm -rf <scratch>/base-check
```

**`<default-branch>` is whatever the profile names as this repo's default branch** — `master`
and `devel` are both common, so substitute the real name rather than assuming `main`.

That is the verification, and say in the PR description which member of the accepted
exceptions list it is. Any *new* NOTE must be resolved before merge; `.Rbuildignore` is an
alternative only with the maintainer's explicit permission, since everything it matches is
invisible to `R CMD check`, so a pattern there silences the finding for every future run
rather than resolving it. A `checking for future file timestamps … unable to verify current
time` NOTE is an environmental flake, not a finding — and it is **nondeterministic on one
machine**, so it is not a quotable result. The same network signature has produced both the
NOTE and a clean run minutes apart, which means you cannot predict it by probing the time
services first: **diagnose the NOTE you actually see, and never report one you inferred from
a `curl`.** `curl` is the wrong instrument anyway: the check fetches with `readLines()`
against worldtimeapi over https, then the same host over http, then worldclockapi. And
`_R_CHECK_SYSTEM_CLOCK_=FALSE` skips that fetch altogether, so a run carrying it cannot
produce this NOTE — a way to sidestep the flake, never a second opinion about it (R 4.5.0,
2026-09-01). Because it can flip between the measurement and the push, describe it in the PR
body as a member of the accepted exceptions list that fires intermittently, rather than
reporting whichever way this run happened to go — otherwise the body needs correcting every
time the coin lands differently.

**`devtools::test()` → `FAIL 0`, with `WARN` and `SKIP` each at the count in the profile's
accepted exceptions list.** Those counts sit on the same line as the failure count and are
routinely ignored. They are part of the gate: a warning your diff introduced is a finding,
and a suite that leaks warnings is one where a *new* warning is invisible by construction.
Treat a non-zero baseline exactly like a pre-existing NOTE — recorded in the profile's § 3 by
name and count, dated, and carried into the adoption clean-up as its own PR.
`testthat::expect_warning()` or `suppressWarnings()` at the site that legitimately warns is
usually the whole fix; what is not acceptable is a standing number nobody owns.

**Any new skip is a finding**, and the dangerous one skips *only* under `R CMD check` — that
is the runner CI and CRAN use, so such a test runs on zero CI jobs and zero CRAN machines
while looking present in a `devtools::test()` suite. Measured: `SKIP 1` under `R CMD check`
against `SKIP 0` under `devtools::test()`, from a guardrail that reads its own package's
`R/*.R` **as text** and falls back to `system.file()`, which for an installed package has no
`R/`; where it did run, its hand-listed expectations were already stale. Enumerate through
the loaded namespace with `body()` instead. The opposite failure — `skip_on_cran()` marking a
block you believe skipped, which in fact runs in the fast loop, the gate, and every CI job —
is in [§ The tools for legitimate differences](#the-tools-for-legitimate-differences) below.

**`spell_check()` → `nrow() == 0`.** **No accepted-exceptions clause, unlike the check and
URL gates** — `inst/WORDLIST` *is* the mechanism for reaching zero, and there is no package
for which that is impossible. Assert the row count, not the output: a clean run
*prints* `No spelling errors found.`, plus a `Language` advisory when `DESCRIPTION` has no
`Language` field. **That clause is about the row count**, which a non-failing advisory does
not move — so recording such an advisory in the profile's § 3, which needs the maintainer's
explicit permission as any other non-failing gate output does, is not an exception to it.
**`use_wordlist` defaults to `TRUE`, so what comes back is the residual — the words the text
uses that `inst/WORDLIST` does not cover, and nothing in the other direction.** That is what
makes `nrow() == 0` the right assertion, and what lets an unfixed typo clear the gate, since
a word entered in the wordlist leaves the residual whether it was a domain term or a
misspelling. Read the whole flagged set with `spelling::spell_check_package(<pkg>,
use_wordlist = FALSE)`, where `<pkg>` is the path the profile's own `spell_check()` line
passes — the repo root only where the package sits there, and the package subdirectory in a
generated one; assert the gate under the default. The defaults and the residual belong to
`spelling`, not `devtools` — `devtools::spell_check()` only passes them through (spelling
2.3.1 and devtools 2.5.2, 2026-09-01). Triage anything flagged:

- Real typo in `DESCRIPTION` / `README.md` / `NEWS.md` / roxygen / vignettes → **fix it in
  source.**
  Never add typos to WORDLIST, and never let `spelling::update_wordlist()` do it for you: it
  writes every flagged word, and only its *answer* is gated on `interactive()`, so under
  `Rscript` the prompt prints and it writes anyway (spelling 2.3.1, 2026-08-23).
- Legitimate domain term (an acronym, a proper noun, a project identifier) → **append to
  `inst/WORDLIST`**, one per line, alphabetized, in the same commit as the source change
  that introduced it.

**A typo clears the gate outright when it sits in text `tools::RdTextFilter` never hands to
hunspell, and no flag brings it back.** `spelling` filters every Rd file through it, and it
drops `\examples{}` whole — comments and string literals with the code, and everything inside
`\dontrun{}` and `\donttest{}` — then, inside the sections it otherwise reads, drops the
contents of `\preformatted{}`, `\code{}` and `\eqn{}`. `\preformatted{}` is the one that
surprises: roxygen2 renders a markdown fenced code block into it, so a typo in a fenced block
under `@details` ships exactly as one in `@examples` does. The prose itself is read,
`\value{}`, `\note{}` and `\seealso{}` included, so the obligation stays narrow: when you
touch an `@examples` block or a fenced one, proofread it yourself (R 4.5.0, roxygen2 8.0.0 and
spelling 2.3.1, 2026-09-01).

**That residual is one-directional, so the wordlist rots silently.** An entry that covers
nothing is never reported, so it outlives the term it was added for — and since many entries
are exported names, a rename strands one with the gate still green. **No cheap comparison
separates a stranded entry from ordinary residue.** Comparing the wordlist against what a
`use_wordlist = FALSE` run flags turns up entries that are still earning their place next to
entries that were never in play, and says nothing about which is which. Still earning it:
hunspell accepts `Catalogue` on the strength of a lowercase `catalogue` entry but not the
reverse, so the correctly-written entry looks unused wherever the text capitalizes the word,
and deleting it turns the gate red on that very word. Never in play: an entry covering only
text the filter drops — an `\eqn{}` macro, a word living solely in `\examples{}` — is listed
but inert, and deleting it changes nothing, because that text goes unchecked either way. The
listing is a superset of the stranded entries, not a report of them, and acting on it can
delete one that was holding the gate green (spelling 2.3.1, 2026-09-01). The remedy that
needs no detector: after a rename, look up the entry named for the symbol you renamed.

Re-run after either triage action; expect `nrow() == 0`.

**`url_check()` → nothing beyond the profile's § 3 accepted exceptions list.** Judge the
**set and the statuses, never the count** — a wrong-paper DOI returning `202` and the correct
DOI returning `403` are both one flag, so a count cannot tell a fix from a no-op and will
read a *correct* result as a failure. Some publishers permanently 403 `urlchecker`'s requests
for URLs that resolve fine in a browser (`doi.org` and several journal hosts), and GitHub
serves unstable non-2xx on `/issues` paths to unauthenticated requests; those are recorded,
not fixed. The accepted exceptions list is a **triage outcome, not a default**: each flag is
either a genuinely rotted link you fix, a redirect you update to the canonical URL, or a host
block you record by name. A dead URL *you* add is always a blocker — CRAN's URL check rejects
it at submission.

**The run can read clean when it is not.** A badge's image source never enters the database:
`tools:::url_db_from_package_sources()` collects the link a badge wraps and omits the `.svg`
it displays, so a broken badge image is never checked. And the progress counter goes to
stdout, carriage-return-overwritten, while the marks go to stderr — so a run captured as
`> out.txt` keeps the counter and drops every finding (urlchecker 1.0.1, 2026-09-01).

**`nrow()` is not the number of marks**, so it cannot stand in for the count even where a
count would help. The returned object carries one row per unique URL; the printout emits one
mark per file:line site where that URL appears, so a URL cited in two man pages is one row
and two marks. And a status describes whether the URL resolved, never which paper the DOI
names. So judging the statuses settles reachability and not citation — the check can never
tell you a citation points at the article you meant, and that you settle against Crossref
(urlchecker 1.0.1, 2026-09-01).

**Vignettes** are rebuilt by `check()` as part of `R CMD check`. A
separate gate is not required. `tools::buildVignettes(dir = ".")` is for optional visual
inspection only.

**If `air format .` modified anything, stage and commit it** — the formatter's output is
part of the deliverable, not a separate concern.

Then confirm:

```bash
git diff --stat   # what's about to be staged
git status        # any uncommitted regenerated files (man/*.Rd, NAMESPACE)?
```

The common omission is editing roxygen comments without re-running `devtools::document()`,
leaving man pages and `NAMESPACE` out of sync. `R CMD check` catches it, but it wastes a
round-trip.

### What is *not* required per PR

Deferred to CRAN-submission time: `check_win_devel()` / `check_mac_release()` (slow remote
round-trips against current Win/macOS dev R), `revdepcheck::revdep_check()` (only
meaningful with reverse-deps and an imminent release), and the `cran-comments.md` rewrite.

---

## Formatting

The profile's **Formatter** field selects the tool. Two are in common use, and they are
mutually exclusive in practice.

### The rule that matters most

**Never change a repo's formatting regime as a side effect of a feature PR.** Running a
different formatter — or any formatter on a repo that has none — reformats every file it
touches and buries a 30-line change in a 4,000-line diff. It is unreviewable; it destroys
`git blame`.

Adopting or switching a formatter is a **separate, deliberate, repo-wide decision the
maintainer makes**, landing as its own PR that changes nothing but whitespace.

### Detecting what the repo uses

When the profile doesn't say:

```bash
ls air.toml .air.toml 2>/dev/null                    # air, repo-local config
grep -rl "styler" .github/ Makefile 2>/dev/null      # styler in CI or a make target
grep -rn "^Config/" DESCRIPTION                      # some repos declare tooling here
```

Failing that, read three or four files in `R/` and match what's there — tabs vs spaces, and
the width. **A consistent existing style is itself the convention**, whether or not a tool
enforces it.

### If the repo uses `air`

    air format .

Commit whatever it touches.

- **A stale air reports "clean" on code a current one would rewrite**, so a clean format run
  from one is not evidence. Ask instead whether your air reproduces the committed formatting:
  `air format --check .` from the repo root, on a clean tree — nonzero means it does not. Run
  it before you edit, or a nonzero exit cannot tell a stale air from your own unformatted
  code. Report a shortfall — **upgrading air, like installing it, is the maintainer's call.**
- **Do not run `air format <single-file>` on a file copied outside the repo root.** Air walks
  *up* the directory tree looking for `.air.toml`. Inside the repo it finds the repo-local
  config; from `/tmp/` it finds neither that nor `~/.air.toml`, and falls back to its
  space-indent default, silently converting tabs. Always invoke air from inside the repo, or
  copy the config alongside the file.
- Note the leading dot in the *search*: air looks upward for a hidden `.air.toml`, while a
  repo ships a visible `air.toml` at its root, which air honors from inside the repo. A
  `find -name "air.toml"` will not find a user-global `~/.air.toml`.
- **Do not also run `styler`** — it converts tabs to spaces and fights the baseline.

### If the repo uses `styler`

    styler::style_pkg()

- Respects `.Rprofile` / `Config/styler` settings where present; otherwise applies the
  tidyverse style (2 spaces).
- Slower than air and it *parses* rather than reformats blindly, so it can fail on code with
  syntax errors — run it after the code is loadable.
- **Do not also run `air`.**

### If the repo has neither

**Match the surrounding file's existing style and change nothing else.**

If the maintainer would benefit from one, **offer** — once, and separately from the current
work:

> This repo has no formatter configured. `air` is the fastest option and integrates with
> editors; adopting it would be a one-time whitespace-only PR, kept separate from feature
> work. Want me to set it up?
>
>     curl -LsSf https://github.com/posit-dev/air/releases/latest/download/air-installer.sh | sh
>
> Then a repo-local `air.toml`:
>
>     [format]
>     indent-style = "space"    # or "tab"
>     indent-width = 2
>
> plus `^air\.toml$` in `.Rbuildignore` to keep it out of the source tarball.

**Do not install anything without a yes.**

---

## Continuous integration

The profile's **CI** field is `none`, `advisory`, or `gating`. It changes the shape of the
gate, not just its length.

### When CI is `none`

The local gate is the only gate. Nothing changes; this is the skill's default assumption.

### When CI exists

**The local check becomes pre-flight; CI-green becomes the handoff condition.** You still run
the full local gate before pushing — catching a failure locally costs seconds, catching it in
CI costs ten minutes and a force-push — but "the local check is clean" is no longer the claim
you make at the end.

Concretely, step 7 of the cycle gains one step, and it lands *after* the PR is open:

    local gate → push → open PR → watch CI → green → hand off

**Opening the PR is what starts CI, not the push.** The stock `check-standard.yaml` triggers
on `push` to the default branch and on `pull_request`, so a feature-branch push fires no
workflow at all, and `gh pr checks` resolves its argument to a pull request, so before the PR
exists there is nothing to name either. *Trigger block read off `r-lib/actions` at `v2`,
2026-08-23; a repo that adds `branches: ['**']` changes this, and `workflow_dispatch` gives
you a manual pre-PR run rather than a push trigger, so read the triggers in the workflow the
profile's Workflows field names before assuming otherwise.*

    gh pr checks <n> --watch          # blocks until all checks settle
    gh run list --branch <branch> --limit 5
    gh run view <run-id> --log-failed # just the failing job's output

    # A check's name is a rendered matrix label, never the workflow's — grepping names for
    # it returns a false empty, so group by workflow instead of matching a literal:
    gh pr checks <n> --json workflow --jq 'group_by(.workflow)[]|"\(length) \(.[0].workflow)"'

If CI is **`gating`**, do not report "ready to merge" until it is green. If **`advisory`**,
report failures with the same triage as below but don't hold on them.

**A red CI you didn't cause is still yours to triage.** Determine whether the failure is your
change, a known-flaky job (the profile lists them), or pre-existing breakage on the base
branch — check by looking at the most recent run on `main`. Say which, explicitly. "CI is red
but I think it's unrelated" without that check is not a triage.

### The failure class that has no local analogue

This is why CI is worth more than a longer local gate: **a green check on your machine is
evidence about one platform, one R version, and one BLAS.** The following fail only elsewhere.

**Numeric tolerance across BLAS implementations.** The single most common cross-platform
failure for a statistical package. macOS links Accelerate, Linux typically OpenBLAS or
reference BLAS, and they differ in the last few digits of any matrix decomposition. A test
that passes locally at `expect_equal(x, y)` can fail on another platform.

- `expect_identical()` on computed doubles is **wrong** — it is exact. Use `expect_equal()`,
  which under testthat 3e compares via waldo at ~1.5e-8 (`sqrt(.Machine$double.eps)`).
- For anything downstream of `solve()`, `qr()`, `svd()`, or `eigen()`, set an explicit
  `tolerance =` rather than relying on the default, and pick it from the conditioning of the
  problem, not by ratcheting until the test passes.
- Eigenvector **signs** and the column order of decompositions are not guaranteed across
  implementations. Compare invariants (fitted values, subspaces, absolute values) rather than
  raw factors.
- **`tolerance = 0` is right only when both sides run the *same* operations.** Two code paths
  that compute the same *quantity* by different arithmetic — `kronecker(diag(N), A) %*% y`
  versus a `T×T` block-apply — differ in the last bits by construction, and bit-identity
  there is a property of the BLAS, not of correctness. Such a pair passed on Accelerate and
  Windows and failed on all four Linux jobs at 1–4 ULPs. **But exactness is legitimate and
  worth keeping when both sides run the same operations** — a consolidation-parity guardrail
  comparing old and new implementations of one path, or a degenerate branch where a matrix is
  exactly the identity so every cross term is exactly zero. Before writing `tolerance = 0`,
  ask which of the two you have; before widening one, ask the same, because widening a real
  invariant deletes a guard.

**`tolerance` does not mean "relative error," and its meaning shifts with magnitude.** What
to know before choosing one:

- **Which edition is running.** No `Config/testthat/edition` field in `DESCRIPTION` means
  **edition 2** (`all.equal`), not edition 3 (`waldo`), and they disagree: at
  `tolerance = 1e-4`, `expect_equal(1e-3 * (1 + 1e-3), 1e-3)` **passes** under edition 2 and
  **fails** under edition 3. The edition also changes **`expect_error`'s control flow**: on a
  message mismatch edition 3 re-raises and aborts the rest of the `test_that` block, while
  edition 2 records the failure and continues — so it decides red-side *counts*, not only
  tolerances. **A scratch directory has no `DESCRIPTION`, so measuring test behavior outside
  a package silently gives you edition 2.** Check the field before reasoning about a
  tolerance or a count, and name the edition you measured at: a correct measurement taken at
  the wrong edition refutes a correct finding, and costs a full round-trip to unpick.
- **The relative/absolute switch.** Under both editions `expect_equal(1e-3 + 9e-3, 1e-3,
  tolerance = 1e-2)` **passes** — a 900% error at a nominal 1e-2 tolerance — because
  `all.equal` falls back to absolute difference when the expected value is small. Packages
  whose quantities are small (standard errors, elasticity-scale effects, coefficients a
  penalty sets to zero) live in that regime by default, not as a corner case.

So: **measure what the assertion actually accepts at your values** rather than reasoning
about units. Perturb the expected value until it fails, and record the band. Note that
`all.equal.numeric` defaults to `countEQ = FALSE`, which averages over only the *differing*
entries — so a single bad element is not diluted across the vector, and the effective guard
is tighter than a naive reading suggests.

**Locale-dependent ordering.** `sort()` and `order()` on character vectors follow the
collation locale: `C` and `en_US.UTF-8` order case differently, so a test asserting a
particular row order passes on one runner and fails on another. Use `method = "radix"` for a
locale-independent order, or sort by a numeric key.

**Windows.** No `fork`. `mclapply()`'s Windows default is `mc.cores = 1L`, so an
unparameterized call runs serially and silently — but an explicit `mc.cores > 1` is a hard
`Error: 'mc.cores' > 1 is not supported on Windows` (same for `pvec`, `mcmapply`, `mcMap`).
Real parallelism needs a PSOCK cluster. Expect the error in CI logs, not a silent slowdown.
Path separators, `normalizePath()` differences, case-insensitive filesystem, file locking (a
test that deletes a file it still has open works on Unix, fails here), and non-ASCII handling
in older R.

**oldrel.** Language features are the usual culprit: the native pipe `|>` and the `\(x)`
lambda need R ≥ 4.1; base `%||%` needs R ≥ 4.4. If `DESCRIPTION`'s `Depends: R (>= …)` is
older than the syntax you used, CI is where you learn it. Recently-added base functions have
the same problem.

**R-devel.** Where you find out about tightened checks and new deprecations before CRAN
rejects the submission. A new NOTE on R-devel that doesn't appear on release is a *warning
about the future*, not necessarily a blocker today — but it should be recorded, not ignored.

**Randomness.** `sample()`'s algorithm changed in R 3.6.0. A test pinning exact values across
R versions needs `RNGversion()`, or better, should not pin exact draws at all.

### The tools for legitimate differences

Not every platform difference is a bug to fix. `skip_on_os("windows")`,
`skip_on_cran()` (for slow or network-dependent tests), `skip_on_ci()`,
`skip_if_not_installed()`, and `skip_if_offline()` exist for exactly this. **A skip is a
decision that needs a reason in a comment** — an unexplained `skip_on_os()` is
indistinguishable from a bug someone gave up on. **`skip_on_cran()` skips in almost nothing you
run**: it reads `NOT_CRAN`, which `devtools::test()`, `devtools::check()`, and
`r-lib/actions/setup-r` all set (devtools 2.5.2 and r-lib actions v2, 2026-08-23), so a block
you believe is skipped for being slow runs in the fast loop, in the gate, and on every CI job
— it skips only under a *bare* `R CMD check`.

### If the repo has no CI and it should

Say so, once, as a suggestion — not as work you fold into the current PR. For a CRAN package
with numerically-sensitive tests, `usethis::use_github_action("check-standard")` is the
cheapest available defense. Know what it actually covers — **five jobs, not nine**:
macOS/release, Windows/release, and Ubuntu at devel, release, and oldrel-1. So it does cover
the BLAS axis (Accelerate vs OpenBLAS), but **oldrel and R-devel are tested on Ubuntu only** —
add rows if you need macOS-oldrel or Windows-devel. **A stock workflow also holds a lower bar
than the local gate**: `r-lib/actions/check-r-package` defaults `error-on` to `'"warning"'`, so
it goes green on a PR that introduces a NOTE unless the check step passes `error-on: '"note"'`.
Adopting it is the maintainer's call. *Job list and `error-on` default read off
`r-lib/actions` at `v2`, 2026-08-23; re-check before relying on one.*

---

## Test discipline

**Count a mutation as detected on `failed + error`, not `failed`.** A mutation that makes the
code *throw* lands in the results object's `error` column and aborts its block, so `failed`
stays 0 — the row reads as SURVIVED exactly when the mutation was most destructive. Read both
columns off a run the failure cap cannot truncate — under the default reporter it stops at a
file boundary and the results object counts only the files that ran, so a mutation destructive
enough to trip it is scored SURVIVED for every file it never reached.

    r <- as.data.frame(devtools::test(reporter = "silent")); sum(r$failed) + sum(r$error)

**And run an unmutated control for every block you count.** `failed + error` over-counts in
the other direction: a block that aborts for a reason of its own — a mismatched
`expect_error()` early in a long block, a fixture that throws — produces an `error` under
*every* mutation, so the row scores DETECTED whatever you did to the code. A row is only
evidence when the control is `0 failed, 0 error` and the mutant is not. Without it the
battery agrees with itself.

**Testing a warning? `suppressWarnings()` defeats `options(warn = 2)`.** It muffles the
condition *before* the conversion to an error, so the obvious way to exercise a warning under
`warn = 2` — wrap the call, inspect the result — hides exactly the failure you are testing
for. Measured: a function that warns and returns `"VALUE"` gives an error at `warn = 2` bare,
and returns `"VALUE"` under `suppressWarnings()`. **`withCallingHandlers()` with a muffle
restart is the same trap** — it is what `suppressWarnings()` is built from, and it returns the
value identically. Use an **observe-only** calling handler (record the condition, do not
muffle), `testthat::expect_warning()`, or assert on the bare call.

**Guarding a test against a hang with `setTimeLimit()`? It has several ways of being silently
absent.** It does work: armed inside a `test_that()` block under `devtools::test()`, an
elapsed limit fires as an **error** — the `error` column, per the rule above — and aborts
the rest of the block rather than hanging. But:

- **A fired limit disarms itself.** A block that arms once and then makes *two* calls capable
  of hanging is protected only on the first — call 1 errors at the limit, call 2 then runs
  unguarded to completion. Arm before each such call, not once per block.
- **`transient` buys you nothing in a test file.** It scopes the limit to the enclosing
  *top-level* computation, and testthat sources a whole file as one — so both forms behave
  identically under `devtools::test()`, and a limit that has not fired is still armed in the
  next `test_that()` block. Disarm it yourself: a bare `setTimeLimit()` after the guarded
  call, or `on.exit(setTimeLimit(), add = TRUE)` **written in the test body**. `on.exit()`
  registers against the frame it is called in, so a helper that arms and registers there
  disarms on its own return, before your call runs.
- **A single `Sys.sleep()` is not interrupted** — measured here, though `?setTimeLimit` says
  limits are checked during it. The limit is checked when the interpreter returns to its own
  loop, which a sleeping process does not; a *loop* of short sleeps is caught. Simulate a
  hang with a spinning call.
- **The elapsed budget runs from when it was set**, not from when the guarded call began: a
  slow earlier call eats it.

**Red-green every regression and bug-fix test, then prove it bites.** A new test must fail
on the pre-fix code and pass after. Once it passes, **mutate the guarded code** — drop a
term, halve a constant, flip a sign — re-run, confirm the expected failures appear, then
revert.

The case that made this a rule: an inference suite recovered a band's standard error from
that band's own confidence interval, then re-derived the p-values from it — a round-trip — on
a family where the second variance component is identically zero, so the conservative path it
claimed to guard was vacuous. It pinned a duality and could not catch a regression in the
formula. Extracting the formula into a unit-testable helper, asserting hand-computed values,
and *running the mutation* (dropping the cross term failed four assertions; reverting restored
green) is what made it real.

**Scaling this to a battery of mutations costs more than you think — measure first.** One
mutation is one suite run. A dozen, checked against the full suite, is a dozen suite runs,
and on a mature package that is hours rather than minutes. Before designing anything that
runs the suite repeatedly:

1. **Time the full suite yourself.** Do not trust a figure in the profile without a date on
   it; a suite grows and the number rots silently.
2. **Derive a filter for the files that can actually observe the mutated code**, mechanically
   rather than by hand — e.g. `grep -lE "<the helpers, the generic, the snapshot verb>"
   tests/testthat/*.R`. A superset is the safe direction.
3. **Validate the filter once against a full run**, then iterate against the filter. The
   filter is typically an order of magnitude cheaper, which is the difference between a
   battery you run and one you abandon — but measure both on your package. This file states
   no figures on purpose.
4. **Use your harness's own backgrounding, not a shell `&`.** A long run wants to survive a
   closed laptop, but `cmd &` or `nohup cmd &` inside an agent tool call returns the *wrapper's*
   exit status — 0 — and the job is killed when the call returns, leaving an empty log that
   reads exactly like a clean run. (`nohup` in the foreground is fine; `&` is the problem.)
5. **Commit before you start, and make the loop refuse a dirty tree** —
   `git diff --quiet -- R/ || exit 1`. A harness that runs `git checkout -- R/` between
   iterations silently destroys every uncommitted change in it.

**Prefer hand-computed expected values** (or a genuinely separate computation path) over
values recovered from the function's own output — such a round-trip passes for any
implementation, correct or not.

**Read the `[ FAIL n | WARN n | SKIP n | PASS n ]` summary line.** Never infer "pass" from
an empty failure-grep — ANSI color codes or a mis-anchored filter can make a failing run
look clean:

```bash
# <scratch>: your own — a subagent's `.plans/<branch>/scratch/<role>/`, the orchestrator's
# own subdirectory under `.plans/<branch>/scratch/`. Never a shared path.
Rscript -e 'devtools::test()' 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > <scratch>/suite.txt
grep -E '\[ FAIL' <scratch>/suite.txt | tail -1   # must show FAIL 0
```

**An empty result from that grep does not mean zero failures.** Above
`testthat.progress.max_fails` (default 10) the reporter quits without ever printing the line —
`Maximum number of failures exceeded; quitting.` — **and the run still exits 0**, so a
catastrophically broken suite and a clean one produce the same empty grep *and* the same exit
status. Falling through to no output is itself a finding: re-run under
`check(error_on = "note")`, which reports the true count and exits non-zero.

**A behavior-preserving rename must rename the tests too — one consistent pass per file.**
An internal-symbol rename is byte-identical in the package, but tests call `@noRd` helpers
by name, construct fixtures with old slot names, and define test-local helpers with old
parameters. A half-renamed fixture trips a constructor validator on an
apparently-unrelated call. Pair an `identical()` sweep with the full suite **and** a
"no stray old symbol" grep — only a deliberately-kept deprecated alias should remain.

### Fixture anti-patterns

The drift sentinel's Check 3 scans new `test_that` blocks for these:

- **Round-trip tautologies.** `expect_equal(f(x) + (y - f(x)), y)` holds by construction
  regardless of correctness. Test permutation or row-order invariance, or
  comparison-to-reference, instead.
- **Fixtures that bypass the path under test.** A wrapper that passes the simulator's true
  parameters straight through cannot exercise the estimator that infers them.
- **Well-formedness-only assertions** (finite / length / type). A 50% miscalibration would
  still pass.
- **Vacuous fixtures.** A "conservative SE" assertion run on a family where the second
  variance component is identically zero tests nothing — the conservative and tight
  formulas coincide there. Choose inputs that make the thing under test non-degenerate.
- **A pattern argument that is silently a regex.** `expect_match()`, `grepl()`, and
  `expect_error()` all treat the pattern as a regex — `expect_error()` has no `fixed` formal
  of its own, and passes it through — so a literal you paste in becomes a
  regular expression. `"[pointwise 95% CI]"` is a *character class* and matches
  `"simultaneous"` output — an assertion that passes against the exact mutation it guards.
  `"(cluster-robust)"` is a capture group; `"... + 7 more cohorts."` contains a `+`
  quantifier and cannot match its own expected text. **Pass `fixed = TRUE` on every
  assertion whose pattern is meant as a literal**, and treat a bare bracket, paren, `+`,
  `*`, `.`, or `?` in an expected string as a defect until it is either escaped or fixed.
  But `fixed = TRUE` closes one hole and opens another: it makes a pattern **literal**, it
  does not make it **discriminating**. A literal that is a substring or prefix of what the
  mutation renders matches the correct output *and* the mutated one. Measured:
  `grepl("10000", "could not draw ... in 100000 attempts", fixed = TRUE)` is **TRUE**, so an
  assertion written to pin a cap of `10000` is satisfied by a mutant that changed it to
  `100000`. **Check by running `grepl(<literal>, <the mutant's rendering>, fixed = TRUE)` and
  expecting `FALSE`**, and include the surrounding delimiters so the assertion cannot match a
  longer string — with them, `"in 10000 attempts"`, it is `FALSE`.
- **Fixture hygiene that erases the signal.** A helper that saves and restores
  `.Random.seed` around each call makes two back-to-back calls agree *even when the seed
  under test silently fell back to the ambient generator* — so a test for
  seed-reproducibility passes with the bug present. To see it, vary the ambient state
  between calls (`set.seed(999); f(x)` vs `set.seed(111); f(x)`) rather than calling twice
  in a row. The general shape: whenever the fixture controls the same state the assertion is
  about, ask whether the control is hiding the failure.
- **A threshold on a random quantity, with the null never measured.** `expect_true(cor(x, y)
  > 0.3)` looks precise and may be worthless: it is a criterion only if the statistic's range
  under the bug and under correct code do not overlap at the *n* you chose. Simulate both
  before picking the cutoff. One measured case: at n = 50 the real weak correlation came in
  at 0.33 while pure independent noise reached 0.48 over 200 draws — the assertion could
  neither reliably catch the bug nor reliably pass. At n = 500 it separated cleanly, 0.53
  against a noise ceiling of 0.16. **Raise n until the distributions separate; do not move
  the cutoff until it passes.** This is the stochastic form of "prove the instrument can
  produce a negative," and it is the one anti-pattern here that a single red-green run cannot
  detect — one mutation against a random assertion is a coin flip, so repeat across seeds.

### Minimal hand-built fixtures

For helpers that read from a fitted object, build the object by hand with exactly the slots
the function reads:

    structure(list(feat_sel_mat = …, clusters = …), class = "cssr")

rather than running a full fit. Deterministic, fast, and the conditions it produces are
predictable — which matters because an `expect_error` whose message no longer matches can
halt an entire litr render.

---

## Export discipline: internal vs public

Use `@export` for these and nothing else:

1. Public functions a user calls directly.
2. S3 methods registered for another package's generic (`print.foo`, `summary.foo`,
   `coef.foo`) — they need it so dispatch finds them.

Do **not** `@export` file-local helpers or internal validation / coercion / scaffolding.
Drop the tag and use `@keywords internal` + `@noRd`.

Adding to a CRAN package's public API is a one-way door — it commits you to maintaining the
signature — so resist exporting "just in case." If it's only called inside the package and
has no standalone user utility, keep it internal.

---

## Error messages worth knowing

- **`system is computationally singular`** — in a panel package, suspect a group with too few
  units. Remedies in order: a ridge option, a rank-condition guarantee in the simulator,
  reducing model size. New code that inverts a Gram matrix must state its rank-handling
  strategy.
- **`incompatible dimensions`** — most often a mistakenly transposed transformation matrix.
  Print `dim()` of both operands at the failure site.

Anything else that costs real time to re-derive belongs in the profile's Gotchas section, but
only if it is specific to that package: would the sentence still be true in a different R
package? Then it is not a gotcha, and acceptance criterion 19 ranks where it goes instead: a
check first, always, and only failing that this list or the skill's lesson catalogue.

## A worked failure mode: drift between code and spec

When a package is the reference implementation of a documented methodology, **the spec
wins** — but the disagreement is usually subtle (an off-by-one in group indexing, a missing
variance factor, a transpose error) and may not be caught by the test suite, especially if
the test was written from the same incorrect derivation.

The trap: a change to the math passes existing tests but introduces a small bias that only
shows up over many replications.

Defenses:

1. **Cite the spec in the PR description.** Name the equation or lemma so the maintainer
   can cross-check without hunting.
2. **Add a synthetic end-to-end test.** Generate data where you know the truth, run the
   estimator, and assert the estimate is within tolerance at moderate sample size. This is
   the closest thing to a property-based test.
3. **Run a small simulation study even when not strictly required.** 50 replications at
   modest size runs in seconds and catches biased point estimates that single-shot tests
   miss.
4. **Select tuning parameters per fit the way production does — never a hand-tuned
   constant.** A hand-tuned penalty measures a fit the package never ships, and a penalty
   in a partially-infeasible region inflates coverage through the wider intervals of the
   infeasible replications.
5. **Benchmark any performance claim before shipping it.** "Vectorize into one big matrix
   op" is not automatically faster — a dense multiply against a structurally sparse operand
   trades `O(work)` for `O(work × density⁻¹)`. Bake a benchmark step into the plan with an
   explicit STOP if the "optimized" path isn't actually faster, and benchmark the
   *realistic* regime plus the adversarial one, not the toy tests.
