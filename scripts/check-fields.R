#!/usr/bin/env Rscript

# Checks that every field templates/PROFILE.md defines is named somewhere in the skill's own
# prose.
#
# Run from anywhere:  Rscript scripts/check-fields.R
# Exit status 0 if clean, 1 if the template requires an operative field nothing names. The
# subject is always the skill this script sits in, so it takes no argument but the flag
# below; anything else is named and exits 1, rather than being dropped so that the ordinary
# check can report OK in its place.
#
# Why this exists: scripts/check-profile.R derives what a profile must contain from the
# template at run time, so a field the template defines is enforced against every adopting
# repo from the moment it is written. Nothing enforced the other direction. When
# references/cran-gate.md replaced "check `air --version` against the minimum the profile
# names" with `air format --check .`, which compares against the tree and needs no profile
# data, the field that instruction had read stayed in the template and stayed required --
# with check-profile.R's self-test passing throughout, because a fixture derived from the
# template agrees with the template about everything, orphans included. Both adopting repos
# dutifully answered "none named", which is the correct answer to a question nothing asks.
#
# It is the inverse of scripts/check-briefs.R: that one finds a pointer that reaches
# nothing, this one finds a field nothing points at. Neither can see the other's class.
#
# Design: the field list comes from check-profile.R's parser, source()d rather than copied,
# so this check and that requirement can never disagree about what a field is -- if they
# could, this could report clean on a field that script still enforces. The corpus is every
# markdown file the skill ships except the template: a field named only where it is defined
# is the orphan condition, so the template cannot be its own evidence. The scripts are out
# too, because the only field names in them are check-profile.R's self-test fixtures, and a
# fixture is not an instruction.
#
# What decides the false-positive rate, and what that choice gives up:
#
#   * The unit is a paragraph, not a file. Over a file, "minimum" from one section and
#     "version" from another read as a mention of a field neither is about, and the orphan
#     this exists to catch survives. Over a paragraph, words co-occur because they name the
#     same thing. Code is dropped, fenced and 4-space-indented alike -- this repo writes
#     most of its examples the indented way -- because a field name in a command example
#     illustrates, it does not read the field. Which lines are code is check-profile.R's
#     code_lines(), for the same reason the matcher below is that script's.
#   * Matching is check-profile.R's own tokens()/covers() -- the matcher that already
#     decides whether a heading in a profile names a template field. Instructions name
#     fields loosely ("a known-flaky job (the profile lists them)") and an exact-phrase test
#     reported most of the template as orphaned, which is the noise level that gets a
#     checker ignored.
#   * Only names that reduce to more than one content word can be judged. `Command`,
#     `Tool`, `Naming`, `Channel`, `Matrix` are satisfied by any paragraph using that
#     ordinary word, so for those neither a hit nor a miss is evidence; they are listed as
#     not checked rather than passed, so that a field renamed into a common word is visible
#     instead of silently leaving the run.
#   * Only fields the template marks **[switch]**, or that sit under a heading it marks,
#     gate. The template says why: "Several fields below don't just describe the repo, they
#     switch parts of the process." An instruction that branches on such a field reads it by
#     name, because a parameter has no section-level paraphrase. Descriptive fields are
#     routinely reached through their section instead -- "the profile's § 3 accepted
#     exceptions list" -- so a name miss there is reported and not gated.
#
# So it misses: an orphan whose name is one ordinary word; an orphan among the descriptive
# fields, which is reported but never fails the run; and any field an instruction consumes
# by concept under a different name is reported as unnamed even though something reads it.
# That last one is deliberate -- the claim being checked is that the template's names are
# the names the skill uses, which is what makes a grep for a field land anywhere at all.
#
# Run the negative control first: Rscript scripts/check-fields.R --self-test
# It builds a small skill holding one of each defect class and, beside each, the construct
# that mimics it and is correct. A checker with only a positive control is satisfied by
# flagging everything; this repo has shipped one that reported a clean tree that was not,
# and another that reported a clean tree as broken.

## ---- locating the skill ----------------------------------------------------
script_path <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(f[1], mustWork = FALSE) else ""
}

skill_root <- function() {
  s <- script_path()
  if (!nzchar(s)) "." else dirname(dirname(s))
}

sibling_script <- function(name) {
  s <- script_path()
  if (!nzchar(s)) file.path("scripts", name) else file.path(dirname(s), name)
}

## The single owner of what the template defines. Its main block is guarded, so nothing runs
## or exits on the way in -- but it has a run() and a self_test() of its own, and letting
## those land beside this file's would make which one wins depend on the order of two lines.
profile_checker <- new.env(parent = globalenv())
sys.source(sibling_script("check-profile.R"), envir = profile_checker)

## Everything borrowed, named once. The markdown shredding, the code-context predicate and
## the tokens()/covers() matcher have to be the same ones check-profile.R uses, or the two
## could disagree about what a field is and this check could report clean on one that script
## still enforces. Listing them also means a rename over there fails here loudly instead of
## at some later call -- inherits = FALSE is what makes that structural rather than luck,
## since without it a name that happened to exist in globalenv or on the search path would
## be picked up silently in place of the missing one.
for (borrowed in c("read_md", "drop_switch_tag", "SWITCH_RE", "headings", "parse_label",
                   "is_field_label", "parse_template", "code_lines", "tokens", "covers")) {
  assign(borrowed, get(borrowed, envir = profile_checker, inherits = FALSE))
}

TEMPLATE_REL <- "templates/PROFILE.md"

## ---- what the template defines ---------------------------------------------
## Lines inside a subsection whose heading carries the marker, plus any line carrying it
## itself -- the template writes Method-entry preconditions the second way.
switch_scope <- function(raw) {
  tagged <- grepl(SWITCH_RE, raw, perl = TRUE)
  h <- headings(drop_switch_tag(raw))
  scope <- tagged
  for (k in seq_len(nrow(h))) {
    if (!tagged[h$line[k]]) next
    nxt <- h$line[h$line > h$line[k] & h$level <= h$level[k]]
    end <- if (length(nxt)) nxt[1] - 1L else length(raw)
    scope[h$line[k]:end] <- TRUE
  }
  scope
}

## Where each bolded field label sits, reduced exactly the way parse_template() reduces it so
## the two can be matched up. parse_template() decides which of them are requirements -- it
## drops conditional and delete-if-inapplicable ones -- and only those are asked about here.
label_sites <- function(raw) {
  clean <- drop_switch_tag(raw)
  scope <- switch_scope(raw)
  out <- list()
  for (i in seq_along(clean)) {
    p <- parse_label(clean[i])
    if (is.null(p) || !is_field_label(p$label)) next
    out[[length(out) + 1L]] <- list(
      label = trimws(sub("[:.]$", "", trimws(gsub("`", "", p$label)))),
      line = i, switched = scope[i])
  }
  out
}

template_names <- function(path) {
  raw <- read_md(path)
  tpl <- parse_template(path)
  required <- unique(trimws(vapply(tpl$fields, `[[`, "", "label")))

  out <- list(); seen <- character(0)
  for (s in label_sites(raw)) {
    if (!s$label %in% required || s$label %in% seen) next
    seen <- c(seen, s$label)
    out[[length(out) + 1L]] <- s
  }
  ## A [switch] subsection's heading is a field name in its own right, and these are the
  ## names the skill's prose uses most often, so leaving them out would drop the part of the
  ## check with the strongest claim.
  h <- headings(drop_switch_tag(raw))
  for (sw in tpl$switches) {
    nm <- trimws(sw$name)
    if (nm %in% seen) next
    k <- which(trimws(h$text) == nm)
    seen <- c(seen, nm)
    out[[length(out) + 1L]] <- list(label = nm,
                                    line = if (length(k)) h$line[k[1]] else 1L,
                                    switched = TRUE)
  }
  out
}

## A slash in a label joins alternative names for one field ("Class validators /
## expected-slot lists"), so naming either half is naming the field -- and the weakest
## alternative decides whether the name can be judged at all.
name_alternatives <- function(label) {
  alts <- unique(c(label, trimws(strsplit(label, "[[:space:]]+/[[:space:]]+")[[1]])))
  Filter(length, lapply(alts, tokens))
}

## ---- the skill's own prose -------------------------------------------------
corpus_files <- function(root) {
  md <- suppressWarnings(system(sprintf("git -C %s ls-files '*.md'", shQuote(root)),
                                intern = TRUE, ignore.stderr = TRUE))
  if (!length(md)) md <- list.files(root, pattern = "\\.md$", recursive = TRUE)
  md <- setdiff(md, TEMPLATE_REL)
  md[file.exists(file.path(root, md))]
}

## One paragraph, one list item, or one run of table rows. A blockquote is prose with a
## marker on it -- the briefs address the orchestrator that way -- so the marker is stripped
## rather than the line dropped. check-briefs.R carries a richer splitter for a different
## job; it is not shared because source()ing that file would install a second, different
## tokens(), and the one this check needs is check-profile.R's.
prose_units <- function(root, files) {
  out <- list()
  for (p in files) {
    lines <- drop_switch_tag(read_md(file.path(root, p)))
    code <- code_lines(lines)
    buf <- character(0); first <- NA_integer_
    flush <- function() {
      if (length(buf)) {
        out[[length(out) + 1L]] <<- list(file = p, line = first,
                                         text = paste(buf, collapse = " "))
      }
      buf <<- character(0); first <<- NA_integer_
    }
    for (i in seq_along(lines)) {
      if (code[i]) { flush(); next }
      l <- sub("^[[:space:]]*>[[:space:]]?", "", lines[i])
      if (!nzchar(trimws(l))) { flush(); next }
      if (grepl("^[[:space:]]*(?:[-*+]|[0-9]+\\.)[[:space:]]", l) ||
          grepl("^#{1,6}[[:space:]]", l)) flush()
      if (!length(buf)) first <- i
      buf <- c(buf, trimws(l))
    }
    flush()
  }
  out
}

## ---- the check -------------------------------------------------------------
check_fields <- function(root, tpl_path) {
  units <- prose_units(root, corpus_files(root))
  have <- lapply(units, function(u) tokens(u$text))

  orphans <- character(0); advisory <- character(0); unjudged <- character(0)
  for (f in template_names(tpl_path)) {
    needs <- name_alternatives(f$label)
    ## One content word is unjudgeable, and none at all -- a label made entirely of
    ## stopwords, which `Do not run` is one rename away from -- is more so. Both belong in
    ## the same list: skipping the emptier case would let exactly the field whose name has
    ## least left to match on leave the run without appearing anywhere.
    if (!length(needs) || min(vapply(needs, length, 1L)) < 2L) {
      unjudged <- c(unjudged, f$label)
      next
    }
    if (any(vapply(have, function(h) any(vapply(needs, covers, logical(1), have = h)),
                   logical(1)))) next
    where <- sprintf("%s:%d  **%s**", TEMPLATE_REL, f$line, f$label)
    if (f$switched) orphans <- c(orphans, where) else advisory <- c(advisory, where)
  }
  list(orphans = orphans, advisory = advisory, unjudged = unjudged)
}

run <- function(root, tpl_path, quiet = FALSE) {
  r <- check_fields(root, tpl_path)
  if (!quiet) {
    if (length(r$orphans)) {
      cat("\nFIELDS NOTHING READS -- defined by the template, named nowhere in the skill\n")
      cat(paste0("  ", r$orphans, collapse = "\n"), "\n", sep = "")
      cat("\nBROKEN: the template requires a field no instruction in the skill names.\n")
      cat("check-profile.R will go on demanding an answer for it from every adopting repo.\n")
      cat("Either name it in the instruction that reads it, or delete it from the template.\n")
    } else {
      cat("OK: every operative field the template defines is named in the skill's prose.\n")
    }
    if (length(r$advisory)) {
      cat("\nADVISORY (human judgement required; does not affect exit status)\n")
      cat("  Descriptive fields the skill's prose never names. These carry no [switch], and\n")
      cat("  the skill reaches such sections by number as readily as by field name, so a\n")
      cat("  miss here is not evidence on its own. Read each one before acting on it.\n")
      cat(paste0("  ", r$advisory, collapse = "\n"), "\n", sep = "")
    }
    if (length(r$unjudged)) {
      cat("\nNOT CHECKED (no rule ran through these)\n")
      cat("  Each of these names reduces to at most one ordinary word, which any paragraph\n")
      cat("  using it satisfies, so neither a hit nor a miss says anything. Renaming a\n")
      cat("  field into this list disarms the check, which is why they are printed:\n")
      cat(paste0("    ", strwrap(paste(r$unjudged, collapse = ", "), width = 84),
                 collapse = "\n"), "\n", sep = "")  # 84, i.e. 88 less the four spaces
      ## prepended here, which fall outside strwrap's budget. Every other line in this block
      ## is hand-wrapped to fit inside that column; the field list is the only one that
      ## could run past it, because its length is whatever the template happens to hold.
    }
  }
  r
}

## ---- what the caller asked for ---------------------------------------------
## This checker's subject is the skill root it sits in, never a path handed to it, so every
## argument other than the flag below is a request it cannot honour. Discarding one used to
## run the ordinary check and exit 0, and `--selftest` -- one hyphen from the flag this
## file's header sends every reader to first -- took exactly that path, so the reader saw an
## OK line and concluded the negative control had passed. An argument is not an orphaned
## field, so it enters no list here: it says the run the caller asked for never happened.
KNOWN_FLAGS <- c("--self-test")

argument_problems <- function(args) {
  sprintf("Unrecognised argument: %s", setdiff(args, KNOWN_FLAGS))
}

## ---- negative control ------------------------------------------------------
## The fixture plants one of each defect class and, beside each, the construct that looks
## identical and is correct. Both halves are required: a checker with only a positive
## control is satisfied by flagging everything, and this repo has shipped one that was.
write_fixture <- function(d) {
  dir.create(file.path(d, "templates"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "references"), showWarnings = FALSE)
  w <- function(p, x) writeLines(x, file.path(d, p), useBytes = TRUE)

  w(TEMPLATE_REL, c(
    "# PROFILE - <repo name>", "",                                              # 1, 2
    "## 1. Identity", "",                                                       # 3, 4
    "- **Package:** `<name>`.",                                                 # 5
    "- **Default branch:** `main`.", "",                                        # 6, 7
    "### CI **[switch]**", "",                                                  # 8, 9
    "- **`none`** - no CI.",                                                    # 10
    "- **`gating`** - CI must be green.", "",                                   # 11, 12
    "- **Workflows:** `<paths>`",                                               # 13
    "- **Known-flaky jobs:** *(any job that fails for reasons unrelated)*",      # 14
    "- **Status command:** `gh pr checks <n> --watch`",                         # 15
    "- **Handoff note:** *(what the PR description has to say)*",               # 16
    "- **Retry budget:** *(how often a red job may be re-run)*",                # 17
    "- **Escalation window:** *(how long to wait before asking the maintainer)*", # 18
    "- **Rebuild trigger:** *(what forces a full rebuild)*",                    # 19
    "- **Coverage floor:** *(what the suite may not drop below)*", "",          # 20, 21
    "### Object system(s) **[switch]**", "",                                    # 22, 23
    "Which of `S3`, `S4` the package uses, and where each applies.", "",        # 24, 25
    "### Cache policy **[switch]**", "",                                        # 26, 27
    "Whether a build reuses the previous run's intermediates.", "",             # 28, 29
    "## 2. Version bookkeeping", "",                                            # 30, 31
    "- **Version lives in:** `DESCRIPTION`'s `Version:`.",                      # 32
    "- **Other files that must match:** `NEWS.md`, `inst/CITATION`.",           # 33
    "- **Class validators / expected-slot lists:** *(name them)*",              # 34
    "- **Smoke snippets:** *(a fast call that exercises the package)*"))        # 35

  ## The prose. Every mention here is loose, lowercase and inflected, the way the skill's
  ## instructions really name profile fields.
  w("references/gate.md", c(
    "# Gate", "",
    "Triage any red as your change, a known-flaky job (the profile lists them), or",
    "pre-existing breakage on the base branch.", "",
    "The other files that must match a release version are named in the profile.", "",
    "The class validators the profile names must track their hand-built fixtures.", "",
    "Run the smoke snippet before you push.", "",
    "> The handoff note the profile asks for goes in the PR description.", "",
    "The escalation the profile names is the maintainer's call, not yours.", "",
    "A rebuild is cheap; the window for one is not.", "",
    "```",
    "# the rebuild trigger the profile names",
    "```", "",
    "Most examples in this repo are indented rather than fenced, like this one:", "",
    "    # the coverage floor the profile names"))

  w("SKILL.md", c(
    "# Demo skill", "",
    "Read the profile's status command before you watch a run.", "",
    "The workflows, the package, and the default branch are all recorded there.", "",
    "Which object system the package uses selects the checks the reviewer applies.", "",
    "Every command the profile gives runs from the repo root."))
  invisible(NULL)
}

self_test <- function() {
  d <- file.path(tempdir(), "check-fields-selftest")
  unlink(d, recursive = TRUE); dir.create(d, showWarnings = FALSE)
  write_fixture(d)
  r <- run(d, file.path(d, TEMPLATE_REL), quiet = TRUE)
  orph <- r$orphans; adv <- r$advisory

  want <- c(
    "**Retry budget**" =
      "a [switch] field the prose never names -- its own definition does not count",
    "**Escalation window**" =
      "words of a field name that occur only in separate paragraphs are not a mention",
    "**Rebuild trigger**" =
      "a field named only inside a code fence, where nothing reads it",
    "**Coverage floor**" =
      "a field named only inside a 4-space-indented block, this repo's usual code style",
    "**Cache policy**" =
      "a [switch] subsection heading, which is a field name in its own right")
  hit <- vapply(names(want), function(w) any(grepl(w, orph, fixed = TRUE)), logical(1))

  ## Reported, but deliberately not as a failure. Each of these is a way the check could be
  ## silently wrong rather than noisy: gating on them would put permanent entries in the one
  ## list a change is obliged to keep empty, and it would stop being read.
  reports <- c(
    "a descriptive field outside any [switch] is advisory, never a failure" =
      any(grepl("**Version lives in**", adv, fixed = TRUE)) &&
        !any(grepl("**Version lives in**", orph, fixed = TRUE)),
    "a one-word name is listed as unjudged rather than passed or failed" =
      all(c("Package", "Workflows") %in% r$unjudged) &&
        !any(grepl("**Package**", c(orph, adv), fixed = TRUE)),
    "a switch enumeration's values are not fields and enter no list at all" =
      !any(grepl("gating", c(orph, adv), fixed = TRUE)) &&
        !any(c("none", "gating") %in% r$unjudged),
    ## The arguments. The failure guarded here is a reader running --selftest, reading OK and
    ## exit 0, and concluding the negative control passed -- this file being the control they
    ## never ran. Each case names its own argument: one built from KNOWN_FLAGS would agree
    ## with the implementation whatever either of them said.
    "an argument one hyphen off the flag the header sends readers to is named" =
      any(grepl("Unrecognised argument: --selftest", argument_problems("--selftest"),
                fixed = TRUE)),
    "a path argument is named too, since this checker takes none" =
      any(grepl("Unrecognised argument: templates/PROFILE.md",
                argument_problems("templates/PROFILE.md"), fixed = TRUE)))

  clean <- c(
    "a field named by a loose, inflected paraphrase in prose" =
      !any(grepl("**Known-flaky jobs**", c(orph, adv), fixed = TRUE)) &&
        !any(grepl("**Smoke snippets**", c(orph, adv), fixed = TRUE)),
    "a field named in a file other than the one that parameterizes it" =
      !any(grepl("**Status command**", c(orph, adv), fixed = TRUE)),
    "a field named inside a blockquote, which is prose with a marker on it" =
      !any(grepl("**Handoff note**", c(orph, adv), fixed = TRUE)),
    "either half of a slashed label satisfies it" =
      !any(grepl("**Class validators", c(orph, adv), fixed = TRUE)),
    "a [switch] subsection heading the prose does name" =
      !any(grepl("Object system", c(orph, adv), fixed = TRUE)),
    "a descriptive field the prose does name" =
      !any(grepl("**Other files that must match**", c(orph, adv), fixed = TRUE)) &&
        !any(grepl("**Default branch**", c(orph, adv), fixed = TRUE)),
    "the flag this checker does know is not an unrecognised argument" =
      !length(argument_problems("--self-test")) && !length(argument_problems(character(0))))

  cat("self-test: planted every defect class above, plus the constructs that mimic them\n")
  for (w in names(want)) {
    cat(sprintf("  [%s] catches: %s\n", if (hit[[w]]) " ok " else "MISS", want[[w]]))
  }
  for (n in names(reports)) {
    cat(sprintf("  [%s] reports: %s\n", if (reports[[n]]) " ok " else "MISS", n))
  }
  for (n in names(clean)) {
    cat(sprintf("  [%s] ignores: %s\n", if (clean[[n]]) " ok " else "FALSE+", n))
  }
  ok <- all(hit) && all(reports) && all(clean)
  if (!ok) {
    cat("\n  the fixture raised:\n")
    cat(paste0("    ", c(orph, adv, paste("unjudged:", paste(r$unjudged, collapse = ", "))),
               collapse = "\n"), "\n", sep = "")
  }
  cat(if (ok) "self-test PASSED - the checker detects the defects it claims to.\n"
      else "self-test FAILED - do not trust a clean run from this checker.\n")
  unlink(d, recursive = TRUE)
  ok
}

## ---- main ------------------------------------------------------------------
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  bad <- argument_problems(args)
  if (length(bad)) {
    cat(paste0(bad, collapse = "\n"), "\n", sep = "")
    cat("Usage: Rscript scripts/check-fields.R\n")
    cat("       Rscript scripts/check-fields.R --self-test\n")
    quit(status = 1L)
  }
  if ("--self-test" %in% args) quit(status = if (self_test()) 0L else 1L)

  root <- skill_root()
  tpl <- file.path(root, TEMPLATE_REL)
  if (!file.exists(tpl)) {
    cat(sprintf("Cannot find the template at %s.\n", tpl))
    quit(status = 1L)
  }
  quit(status = if (length(run(root, tpl)$orphans)) 1L else 0L)
}
