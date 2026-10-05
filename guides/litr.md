# Generated / literate packages (litr and similar)

Read this only if the package is built from a source document rather than edited directly in
`R/`. Everything here is optional for a plain devtools package. Treat this as a starting
point for your own profile's Gotchas, derive what you can, and date what you measure.

## Contents

- [What changes in the process](#what-changes-in-the-process)
- [The failure mode that costs the most time](#the-failure-mode-that-costs-the-most-time)
- [When litr refuses to build](#when-litr-refuses-to-build)
- [Fixtures](#fixtures)
- [Landing concurrent PRs](#landing-concurrent-prs)
- [What goes in your profile](#what-goes-in-your-profile)

---

## What changes in the process

**You rebuild instead of reloading.** `devtools::load_all()` on the generated tree loads the
last build, not your edit to the source. The profile's § 2 records the build command and its
clear-the-intermediates prelude.

**A green full build means the woven tests passed**, because the renderer executes each test
chunk during the render. That changes what a green run is evidence *of* — it is a test result,
not just a successful build. A quick build says nothing about the tests. `litr::load_all()`
renders with `minimal_eval = TRUE`, which evaluates only the chunks whose code mentions a
usethis function or `litr::document()`, so a woven test runs only if it happens to mention one.
It builds in a temporary copy and then copies the result over the package directory in your
working tree, which skips litr's check for hand edits (next paragraph) and overwrites them. Use
the full build in this workflow. Checked on litr 0.9.3 by reading `litr::load_all` and
`litr:::setup` (2026-10-04).

**Never hand-edit the generated tree.** The package directory and any generated site are
output. litr guards the package: `<pkg>/DESCRIPTION` records a `LitrId` fingerprint of every
file in the package, and `litr::render()` refuses to build over a package directory that no
longer matches it. Once the check passes, litr deletes and regenerates the directory itself. So
a build script that deletes the package directory first turns the check off, and the next build
then erases a hand edit silently. `litr::load_all()` skips the check too. To run the check
yourself, call the internal `litr:::check_unedited("<pkg>")`. On litr 0.9.3 it returned `TRUE`
on a built package and `FALSE` after a one-line edit to an `R/` file (2026-10-04).

**A fresh checkout can fail that check with no edit at all.** `litr::add_readme()` calls
`usethis::use_readme_rmd()`, which, in a git repo, writes a hook to
`<pkg>/.git/hooks/pre-commit`. Git never commits anything under a `.git` directory, but the
fingerprint covers every file in the package, hidden ones included. So a fresh clone or
worktree fails the check and the build stops. Deleting that one file during the build, after
`litr::add_readme()` runs, should keep it out of the fingerprint, which litr takes after the
last chunk runs. That fix is untested so far. Delete only that file, only if it exists, and
never a `.git` directory. Measured with litr 0.9.3 and usethis 3.2.1 (2026-10-04).

**`devtools::check()` on the generated subdirectory needs `document = FALSE`.** A plain check
re-runs roxygen and rewrites the generated man-page headers, corrupting the diff. Note this
applies to `devtools::check()` specifically — `R CMD check` never documents, so do **not**
carry the flag into a CI workflow. *(Reported, not independently reproduced.)*

**The formatter may be no step at all.** `air` does not format `.Rmd` — measured on air 0.9.0:
it rewrote `y<-c(1,2,3)` in a `.R` file and left the identical line inside an `.Rmd` chunk
untouched (2026-09-04). So running it at the repo root reaches only the generated tree, where
its changes are hand edits that the next build refuses or discards, while the source of truth
stays unformatted. A litr repo may therefore record its profile's **Formatter** command as
`none` and match the source's indentation by hand. That is a property of the toolchain, not a
lapse in discipline, and it is why a repo-local `air.toml` does not rescue it: pinning the
style only makes the wrong target deterministic.

## The failure mode that costs the most time

**A test that errors can abort the build, and the symptom points somewhere else.** An
`expect_error()` whose thrown message no longer matches, or an `expect_warning()` that
receives an unexpected error, halts the render — and it surfaces as a failure to find or
write the package directory. That is cleanup after the chunk threw, not the cause. (A plain
`expect_equal` *value* mismatch is a recorded failure and does **not** halt.)

**The most common trigger:** you changed a message, a validation order, or a return value,
and an *existing* test still asserts the old behavior. So — **when you change any
user-visible condition, grep the test chunks for the old assertion and update it in the same
edit.**

**Diagnostic.** It is almost never the environment. Stash the source edit and build the
default branch; if that succeeds, it is your edit, and the `Quitting from …[chunk-N]` line
names the offending chunk. Each failed build costs a full render, so isolate before
re-running.

The same symptom follows an interrupted or timed-out build, which leaves stale intermediates
behind. Clear them before each run, but not the package directory:
[When litr refuses to build](#when-litr-refuses-to-build) covers that one.

## When litr refuses to build

litr refuses when the package directory no longer matches its fingerprint. Its message suggests
renaming or deleting the directory, but first run `git status --porcelain --ignored -- <pkg>`.
It lists the files there that git cannot restore: output from an interrupted build, a merge or
`litr::load_all()`, a hand edit, or a stray file such as `.Rhistory`, which the fingerprint
counts too. It never lists anything under `<pkg>/.git/`. Read what it lists, move any hand edit
into the source, then delete the directory and rebuild.

If it lists nothing, the mismatch is in something git does not show or in the committed tree
itself: the `<pkg>/.git/hooks/pre-commit` file that `litr::add_readme()` writes, line endings
that git converted on checkout, or a hand edit or an unrebuilt merge that was committed.
Rebuilding in place would silently revert such a commit. So first make a clean checkout of
`HEAD` somewhere disposable, such as with `git worktree add <dir> HEAD`, delete the package
directory there, build, and diff its `<pkg>/` against yours. If they differ only in that hook
file and the `LitrId` line, delete the package directory and rebuild in place. Anything else is
a finding for the maintainer, unless a no-op rebuild produces it too.

## Fixtures

**Build minimal objects by hand** rather than running a full fit — `structure(list(...),
class = "<cls>")` with exactly the slots the function under test reads. Deterministic, fast,
and the conditions it produces are predictable, which matters more here than elsewhere:
an unexpected condition halts the entire render rather than failing one test.

**Mocking an internal helper may need a guard.** `local_mocked_bindings` on a package-internal
function can fail in a bare weave, where there is no package context. Guard it with
`if (testthat::testing_package() == "") testthat::skip(...)` so the test still runs under
`devtools::test` and `R CMD check`. Mocking an *external* package works everywhere.
*(Reported, not independently reproduced.)*

## Landing concurrent PRs

Covered in [git-and-pr.md](../references/git-and-pr.md#gotchas-learned-the-hard-way): the
source auto-merges, only derived files conflict, and the resolution is to rebuild from the
merged source rather than hand-merge anything generated. A merged tree rarely matches its
fingerprint, so expect litr to refuse that rebuild, and handle it as
[When litr refuses to build](#when-litr-refuses-to-build) describes.

One thing worth measuring for your own profile: **whether a no-op rebuild is byte-identical.**
On one package it is — the build id is a content hash, not a nonce — so only the site dirties,
on a render date. If that holds for yours, post-build cleanup after a diagnostic run is a
single `git checkout` of the site directory — **but that resets the whole path to `HEAD`, not
just the render's churn**, so guard it the way
[git-and-pr.md](../references/git-and-pr.md#gotchas-learned-the-hard-way) prescribes:

    git status --porcelain -- <site-dir>   # generated churn only, or do not run the next line
    git checkout -- <site-dir>

## What goes in your profile

Section 2 (build model), section 3 (the gate, with any mandatory flags and *why*), section 4
(**Version lives in:** the source document, never the generated `DESCRIPTION`), and section 12
(the gotchas above, restated with the exact strings your toolchain produces). Derive the rest
per [adoption.md](../references/adoption.md).
