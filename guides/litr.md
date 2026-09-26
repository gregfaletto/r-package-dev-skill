# Generated / literate packages (litr and similar)

Read this only if the package is built from a source document rather than edited directly in
`R/`. Everything here is optional for a plain devtools package. Treat this as a starting
point for your own profile's Gotchas, derive what you can, and date what you measure.

## Contents

- [What changes in the process](#what-changes-in-the-process)
- [The failure mode that costs the most time](#the-failure-mode-that-costs-the-most-time)
- [Fixtures](#fixtures)
- [Landing concurrent PRs](#landing-concurrent-prs)
- [What goes in your profile](#what-goes-in-your-profile)

---

## What changes in the process

**There is no `load_all()` fast loop.** You rebuild. The profile's § 2 records the build
command and its clear-the-intermediates prelude.

**A green build means the woven tests passed**, because the renderer executes each test chunk
during the render. That changes what a green run is evidence *of* — it is a test result, not
just a successful build.

**Never hand-edit the generated tree.** The package directory and any generated site are
output. An edit there is overwritten on the next build, silently.

**`devtools::check()` on the generated subdirectory needs `document = FALSE`.** A plain check
re-runs roxygen and rewrites the generated man-page headers, corrupting the diff. Note this
applies to `devtools::check()` specifically — `R CMD check` never documents, so do **not**
carry the flag into a CI workflow. *(Reported, not independently reproduced.)*

**The formatter may be no step at all.** `air` does not format `.Rmd` — measured on air
0.9.0: it rewrote `y<-c(1,2,3)` in a `.R` file and left the identical line inside an `.Rmd`
chunk untouched (2026-09-04). So running it at the repo root reaches only the generated tree,
where the next build discards the result, while the source of truth stays unformatted. A litr
repo may therefore record its profile's **Formatter** command as `none` and match the
source's indentation by hand. That is a property of the toolchain, not a lapse in discipline,
and it is why a repo-local `air.toml` does not rescue it: pinning the style only makes the
wrong target deterministic.

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
behind. Clear them before each run.

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
merged source rather than hand-merge anything generated.

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
