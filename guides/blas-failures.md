# Failures on an alternative BLAS

CRAN also checks packages against other BLAS libraries, and a failure there can carry a removal
deadline while every regular flavor stays green. Start from the log: what its text can tell you
is in [cran-gate.md](../references/cran-gate.md#the-failure-class-that-has-no-local-analogue).
Then show the failure on your own machine. In the case behind this guide, R-hub never
reproduced it.

**One comparison.** Compute one side under `options(matprod = "internal")` and the other under
the default. The option reaches base `%*%`, `crossprod()` and `tcrossprod()` on plain matrices,
other packages' calls included, but not `Matrix`'s methods. It has to be one-sided: with both
sides under it, a whole suite can pass and show nothing.

**The whole suite.** Put [`templates/mkl-emulator.R`](../templates/mkl-emulator.R) in `R/` of a
`git archive` copy, and run the suite with `MKL_EMUL=1`, then with it unset as the control. It
permutes the summation order of the package's own `%*%`, `crossprod()` and `tcrossprod()` calls
on plain numerics, so it misses anything that depends on LAPACK or on another package.

- **Prove it can fail first.** Two identical fits must differ with it on and be identical with
  it off.
- **Run it more than once.** Which lines fail depends on the call counter, so repeat it with
  different values of `MKL_EMUL_START`. A line that stays green is unproven, not safe.
- **Expect more failures than CRAN reported.** Any exact comparison of a result that is not
  exact by construction is at risk, and one CRAN run shows only the ones that moved that day.

**R-hub's `mkl` platform.** A green job counts as evidence about MKL only when a control ran
the unpatched code beside it, on the same image and actions, and failed on the comparisons the
patch relaxes. Anything else is a smoke test, and a control is one draw of run-to-run
variation.

- Compare the MKL version in the job's `BLAS/LAPACK:` line with the one in
  [CRAN's README](https://www.stats.ox.ac.uk/pub/bdr/Rblas/README.txt). On 2026-11-05 R-hub had
  2025.3, against CRAN's 2026.2.0.
- R-hub rebuilds `ghcr.io/r-hub/containers/<platform>:latest` daily, so compare the
  `Digest: sha256:…` line printed before `Status: Downloaded newer image for` that image, and
  the `Download action repository 'r-hub/actions@v1' (SHA:…)` line. The `setup` job prints a
  digest of its own.
- R-hub's `run-check` passes no `error-on`, so a green job can carry NOTEs. Read the log.
