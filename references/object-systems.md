# Object systems: S3, S4, R6, S7

## Contents

- [S3](#s3)
- [S4](#s4)
- [R6](#r6)
- [S7](#s7)

---

S3, S4, R6, and S7 are all in active use. They differ in how methods are **registered**, how
objects are **validated**, how dispatch is **inspected**, and what **roxygen** has to say —
so every check in this skill that touches classes has a shape per system, not one.

**The profile's `Object system(s)` field selects which shape applies**, and names which files
use which when a package mixes them. Apply the wrong system's rules and you will report
findings that aren't real (an S4 method "missing `@export`" that in fact needs
`exportMethods`) and miss ones that are (an S7 package with no `methods_register()` call).

If the profile doesn't say, infer it and **ask** — don't guess silently:

```bash
grep -rlE "setClass|setGeneric|setMethod|setValidity" R/   # S4
grep -rlE "R6Class"                                  R/    # R6
grep -rlE "new_class|new_generic|S7::"               R/    # S7
grep -rlE "^\s*[a-zA-Z._]+\.[a-zA-Z._]+ <- function" R/    # S3 (weak signal; confirm)
```

---

## S3

The default assumption elsewhere in this skill.

**Export rule.** A method registered for another package's generic carries **only**
`#' @export`; roxygen emits `S3method(generic, class)`. The parent generic owns the
`@param` / `@return` contract — restating it in different words is a cosmetic finding.
Internal helpers get `@keywords internal` + `@noRd`.

**Reviewer checks.**

- The method has `#' @export`, and `S3method(...)` is in `NAMESPACE` after `document()`.
- The signature matches the generic, including `...`. Compare with `args(print)`,
  `args(summary)`.
- The class is actually set on the return value — `structure(..., class = "foo")` or
  equivalent. A stripped class is a common silent bug.
- `methods(class = "Foo")` lists everything you expect.

**Common bugs.** A method defined but not exported (works under `load_all()`, fails when
installed). A method whose first argument is named differently from the generic's. Dispatch
on a class vector where the order puts the wrong method first.

---

## S4

**Export rule.** `@export` on a `setClass` produces `exportClasses(Foo)`; `@export` on a
`setMethod` produces `exportMethods(bar)`. **The generic itself also needs `export(bar)`** if
users call it — this three-way split is the most common S4 NAMESPACE mistake. Importing from
another package's S4 needs `@importClassesFrom` / `@importMethodsFrom`, not just
`@importFrom`.

**Documentation.** Slots are documented with `@slot name description`, not `@param`. Method
docs are usually merged into the class topic with `@rdname` — so a "missing man page" for an
individual method is often correct, not a finding. Check the *class* topic instead.

**Reviewer checks.**

- `setValidity()` exists for any class with an invariant, and returns `TRUE` or a character
  message — **not** `stop()`.
- **Validity runs on `new()` but NOT on slot assignment.** `obj@x <- bad_value` silently
  produces an invalid object. Code that mutates slots must call `validObject(obj)` afterward.
  This is the single highest-yield S4 check.
- `callNextMethod()` is used where the method extends rather than replaces a parent's
  behavior.
- `setGeneric()` for a name that already exists as a non-generic function will silently
  create a default method from it — confirm that's intended.
- `isVirtualClass()` / `contains =` hierarchy matches what the docs claim.
- Dispatch verified empirically: `existsMethod("bar", "Foo")`, `showMethods("bar")`,
  `selectMethod("bar", "Foo")`.

**Common bugs.** A method added without the corresponding `exportMethods`. `@slot`
documentation drifting from the actual `slots =` list — the S4 analogue of the orphan
`@param` audit, and equally invisible to automated checks. Validity assumed to run when it
doesn't.

---

## R6

**Validation.** R6 has no validity hook; checks go in `initialize()`.

**Export rule.** Export the **generator object** (`@export` on the `Foo <- R6Class(...)`
assignment). There are no `S3method` entries and no dispatch registration. R6 objects do carry
`class(obj) == c("Foo", "R6")`, so S3 methods on them are possible — but the idiomatic place
for `print` is a `print` member inside `public`.

**Documentation.** roxygen2 (≥ 7.0) documents R6 natively: a block above the class for
`@description` / `@details` / `@examples`, `@field` for public fields, and a roxygen block
above each method inside the `public` list for its own `@param` / `@return`. The class must be
assigned at top level for roxygen to find it.

**Reviewer checks — reference semantics are the whole story.**

- **R6 objects are mutable and passed by reference.** A method that assigns `self$x <- …`
  mutates the caller's object. Any function documented as "returns a modified copy" must
  actually `$clone()`.
- `clone(deep = TRUE)` is required when the object holds other R6 objects in fields —
  a shallow clone shares them, so mutating the copy mutates the original.
- **Test fixtures are the classic failure.** An R6 object created once and reused across
  `test_that` blocks carries state between them, making the suite order-dependent and
  passing-in-isolation-but-failing-in-suite. Build a fresh object per block, or clone.
- `active` bindings that do real work on read — check they're side-effect free.
- `private` members are genuinely private; a test reaching into them via
  `obj$.__enclos_env__$private` is testing implementation, and will break on refactor.

---

## S7

The newest system; interoperates with S3 and S4.

**The registration footgun, and the first thing to check.** External generic dispatch requires

```r
.onLoad <- function(...) {
  S7::methods_register()
}
```

**Without it, methods registered against a generic owned by *another* package — an S3
generic like `print`, an S4 generic, or an S7 generic from a dependency — silently fail to
dispatch once the package is installed**, while working fine under `load_all()`, because the
source is evaluated directly. (Methods on generics the package defines itself are fine
either way.) Since registering against foreign generics is the common case, a package that
uses S7 and has no `methods_register()` in `.onLoad` is a **blocker**, not a nit — but check
what it actually registers before calling it.

**Export rule.** `@export` the class object and any generics the package defines. Methods
themselves don't need separate registration entries.

**Reviewer checks.**

- `methods_register()` present in `.onLoad` (above).
- `validator = function(self) …` returns `NULL` when valid and a character message when not —
  **not** `TRUE`/`FALSE`, and not `stop()`. Unlike S4, S7 validators **do** run on property
  assignment, so this is a genuinely stronger guarantee — don't port S4's `validObject()`
  paranoia over unnecessarily.
- Property types declared (`class_numeric`, `class_character`, a nested S7 class) rather than
  left untyped.
- `S7::method_explain(generic, class)` used to verify dispatch empirically when inheritance is
  involved.
- Where S7 classes meet existing S3 generics, confirm the S3 fallback still behaves.

---
