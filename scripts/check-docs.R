#!/usr/bin/env Rscript

# Checks every markdown file for links that cannot be followed, and for list structure a
# scripted edit has broken:
#   * in-page  [text](#anchor)     -> a heading in the same file
#   * cross-file [text](path#anchor) -> a heading in that file
#   * relative [text](path)        -> a file on disk
#   * "## Contents" blocks         -> one entry per heading, and no entry without one
#   * "- - item"                   -> a list marker in front of a line that already had one
#   * "text [ ] item"              -> a checkbox no list marker introduces
#
# Run from anywhere:  Rscript scripts/check-docs.R
# Exit status 0 if clean, 1 if anything is broken. An argument this script cannot honour --
# an option it does not know, a filename that is not on disk -- is named and exits 1 too,
# rather than being dropped so that a check of something else can report OK in its place.
#
# Run the negative control first: Rscript scripts/check-docs.R --self-test
# A checker that shares the generator's bug reports zero problems and is worse
# than no checker, because it manufactures assurance. That has happened here.

## ---- GitHub's slugger ------------------------------------------------------
## Lowercase; drop everything that is not alphanumeric, underscore, space or
## hyphen; turn each whitespace character into its own hyphen. It does NOT
## collapse runs, so a heading with " - " (spaced em-dash) yields a double
## hyphen. Duplicate headings get -1, -2, ... in order of appearance.
slugify <- function(text) {
  s <- tolower(trimws(text))
  s <- gsub("`", "", s, fixed = TRUE)
  s <- gsub("\\*\\*?([^*]+)\\*\\*?", "\\1", s, perl = TRUE)   # **bold**, *em*
  s <- gsub("\\[([^]]*)\\]\\([^)]*\\)", "\\1", s, perl = TRUE) # [text](url)
  s <- gsub("[^[:alnum:]_[:space:]-]", "", s, perl = TRUE)
  gsub("[[:space:]]", "-", s, perl = TRUE)
}

disambiguate <- function(slugs) {
  seen <- new.env(parent = emptyenv())
  vapply(slugs, function(s) {
    n <- if (is.null(seen[[s]])) 0L else seen[[s]]
    seen[[s]] <- n + 1L
    if (n == 0L) s else paste0(s, "-", n)
  }, character(1), USE.NAMES = FALSE)
}

## Lines inside ``` or ~~~ fences are not markdown.
fenced_lines <- function(lines) {
  open <- FALSE
  vapply(lines, function(l) {
    if (grepl("^[[:space:]]*(```|~~~)", l)) { open <<- !open; return(TRUE) }
    open
  }, logical(1), USE.NAMES = FALSE)
}

## ---- one file --------------------------------------------------------------
check_file <- function(path, headings_by_file) {
  lines <- readLines(path, warn = FALSE)
  if (!length(lines)) return(character(0))
  fenced <- fenced_lines(lines)
  problems <- character(0)
  add <- function(ln, msg) problems <<- c(problems, sprintf("%s:%d  %s", path, ln, msg))

  own <- headings_by_file[[normalizePath(path, mustWork = FALSE)]]

  for (i in seq_along(lines)) {
    if (fenced[i]) next
    m <- gregexpr("\\[([^]]*)\\]\\(([^)]+)\\)", lines[i], perl = TRUE)[[1]]
    if (m[1] == -1) next
    starts <- as.integer(m); lens <- attr(m, "match.length")
    for (k in seq_along(starts)) {
      whole  <- substr(lines[i], starts[k], starts[k] + lens[k] - 1L)
      target <- sub("^\\[[^]]*\\]\\((.*)\\)$", "\\1", whole, perl = TRUE)
      if (grepl("^(https?:|mailto:)", target)) next
      target <- sub("[[:space:]]+\"[^\"]*\"$", "", target)   # [t](path "title")

      if (startsWith(target, "#")) {
        anchor <- substring(target, 2)
        if (!anchor %in% own$slug) add(i, sprintf("anchor #%s has no heading in this file", anchor))
        next
      }

      parts  <- strsplit(target, "#", fixed = TRUE)[[1]]
      relpath <- parts[1]
      anchor  <- if (length(parts) > 1) parts[2] else NA_character_
      full <- normalizePath(file.path(dirname(path), relpath), mustWork = FALSE)
      if (!file.exists(full)) { add(i, sprintf("link target does not exist: %s", relpath)); next }
      if (!is.na(anchor)) {
        tgt <- headings_by_file[[full]]
        if (is.null(tgt)) {
          add(i, sprintf("cannot check #%s: %s is not a checked markdown file", anchor, relpath))
        } else if (!anchor %in% tgt$slug) {
          add(i, sprintf("anchor #%s has no heading in %s", anchor, relpath))
        }
      }
    }
  }

  ## List structure a scripted edit has broken. Both shapes have shipped here: a rewrap that
  ## prepended "- " to lines that already carried a marker, and a replacement that grabbed a
  ## greedy line span and merged two checklist bullets into one. Each message quotes the line,
  ## because a message that only names the rule leaves the negative control green by
  ## construction -- the same trap the `clean` vector below is annotated for.
  for (i in seq_along(lines)) {
    if (fenced[i]) next
    ## A thematic break -- "* * *", "- - -", "___" -- is one marker repeated and nothing else,
    ## and reads as a doubled marker without this.
    if (grepl("^[[:space:]]*([-*_])([[:space:]]*\\1){2,}[[:space:]]*$", lines[i], perl = TRUE)) next
    if (grepl("^[[:space:]]*[-*+][[:space:]]+[-*+][[:space:]]+[^[:space:]]", lines[i], perl = TRUE))
      add(i, sprintf("doubled list marker: %s", lines[i]))
    ## Per occurrence, not per line: the merged-bullet shape keeps the first bullet's marker
    ## and swallows the second one's, leaving that "[ ]" mid-line.
    box <- gregexpr("\\[[ xX]\\]", lines[i], perl = TRUE)[[1]]
    if (box[1] != -1L) {
      introduced <- grepl("^[[:space:]]*[-*+][[:space:]]+\\[[ xX]\\]", lines[i], perl = TRUE)
      if (length(box) > as.integer(introduced))
        add(i, sprintf("checkbox with no list marker: %s", lines[i]))
    }
  }

  ## Contents block: bidirectional
  hidx <- grep("^##[[:space:]]+Contents[[:space:]]*$", lines)
  hidx <- hidx[!fenced[hidx]]
  if (length(hidx)) {
    start <- hidx[1]
    nxt <- own$line[own$level == 2L & own$line > start]
    end <- if (length(nxt)) nxt[1] - 1L else length(lines)
    block <- lines[(start + 1L):end]
    listed <- unlist(regmatches(block, gregexpr("\\(#([^)]+)\\)", block, perl = TRUE)))
    listed <- gsub("^\\(#|\\)$", "", listed)
    expected <- own[own$level == 2L & tolower(trimws(own$text)) != "contents", ]
    for (j in seq_len(nrow(expected))) {
      if (!expected$slug[j] %in% listed) {
        add(expected$line[j], sprintf("heading is missing from the Contents block: %s", expected$text[j]))
      }
    }
  }
  problems
}

harvest <- function(paths) {
  out <- list()
  for (p in paths) {
    key <- normalizePath(p, mustWork = FALSE)
    lines <- readLines(p, warn = FALSE)
    if (!length(lines)) {
      out[[key]] <- data.frame(line = integer(0), text = character(0),
                               level = integer(0), slug = character(0))
      next
    }
    fenced <- fenced_lines(lines)
    idx <- grep("^#{1,6}[[:space:]]+", lines)
    idx <- idx[!fenced[idx]]
    txt <- sub("^#{1,6}[[:space:]]+", "", lines[idx])
    txt <- sub("[[:space:]]*#+[[:space:]]*$", "", txt)
    lvl <- nchar(sub("^(#+).*$", "\\1", lines[idx]))
    df <- data.frame(line = idx, text = txt, level = lvl,
                     slug = disambiguate(slugify(txt)), stringsAsFactors = FALSE)
    ## Explicit <a id="x"> / <a name="x"> anchors are real link targets too.
    aidx <- grep("<a[[:space:]][^>]*\\b(id|name)[[:space:]]*=", lines, perl = TRUE)
    aidx <- aidx[!fenced[aidx]]
    if (length(aidx)) {
      ids <- unlist(regmatches(lines[aidx],
        gregexpr("<a[[:space:]][^>]*\\b(?:id|name)[[:space:]]*=[[:space:]]*[\"']([^\"']+)", lines[aidx], perl = TRUE)))
      ids <- sub(".*[\"']", "", ids)
      df <- rbind(df, data.frame(line = rep(aidx, length.out = length(ids)), text = ids,
                                 level = 0L, slug = ids, stringsAsFactors = FALSE))
    }
    out[[key]] <- df
  }
  out
}

run <- function(paths, quiet = FALSE) {
  h <- harvest(paths)
  probs <- unlist(lapply(paths, check_file, headings_by_file = h), use.names = FALSE)
  if (!quiet) {
    if (length(probs)) {
      cat(paste0("  ", probs, collapse = "\n"), "\n", sep = "")
      cat(sprintf("\nBROKEN: %d problem(s) across %d file(s).\n", length(probs), length(paths)))
    } else {
      cat(sprintf("OK: every link and anchor resolves and no list marker is doubled or missing, across %d file(s).\n",
                  length(paths)))
    }
  }
  probs
}

## ---- what the caller asked for ---------------------------------------------
## Both of these used to be dropped in silence. An option the parser did not know was
## discarded, so `--selftest` -- one hyphen from the flag this file's header sends every
## reader to first -- ran the ordinary check and exited 0, which reads exactly like a
## negative control that passed. A filename that was not on disk was filtered out by
## file.exists(), so a typo left OK printed over whatever else was on the command line.
## Neither is a defect in the tree, so neither belongs in the problem list: they say the run
## never happened. check-profile.R already names a path it cannot open; that is this message.
KNOWN_FLAGS <- c("--self-test")

argument_problems <- function(args) {
  flags <- args[startsWith(args, "--")]
  paths <- args[!startsWith(args, "--")]
  c(sprintf("Unrecognised option: %s", setdiff(flags, KNOWN_FLAGS)),
    sprintf("No such file: %s", paths[!file.exists(paths)]))
}

usage <- function() {
  cat("Usage: Rscript scripts/check-docs.R [<file.md> ...]\n")
  cat("       Rscript scripts/check-docs.R --self-test\n")
}

## ---- negative control ------------------------------------------------------
## Plant defects that have actually shipped here and confirm each is caught.
self_test <- function() {
  d <- file.path(tempdir(), "check-docs-selftest"); dir.create(d, showWarnings = FALSE)
  f <- file.path(d, "a.md"); g <- file.path(d, "b.md")
  writeLines(c(
    "# A", "", "## Contents", "",
    "- [Good](#good)",
    "- [Spaced dash](#known-bugs-dated-verify)",   # BAD: slugger keeps both hyphens
    "- [Ghost](#no-such-heading)",                 # BAD: dangling entry
    "- [Explicit](#hand-written)",                 # ok: <a id> target, not a heading
    "", "## Good", "text", "",
    "## Known bugs - dated, verify", "text", "",
    "## Orphan", "not in the Contents block",      # BAD: missing from Contents
    "", "### A subheading not in Contents", "ok: Contents lists ## only", "",
    "<a id=\"hand-written\"></a>", "", "## Explicit", "text", "",
    "", "See [b](b.md#real) and [b](b.md#fake) and [gone](nope.md).",
    "", "See [sub](#a-subheading-not-in-contents).",
    "", "```", "[fenced](#not-a-real-anchor)", "```",
    "", "- - **Doubled**",                         # BAD: a marker in front of a marker
    "- [ ] merged first item [ ] merged second item",  # BAD: second bullet lost its marker
    "", "- [ ] a real checklist item",             # ok: one checkbox, one marker
    "  - nested item",                             # ok: indentation, not a second marker
    "- -1 is the sentinel",                        # ok: no space after the "-"
    "", "* * *"                                    # ok: thematic break, not a list
  ), f)
  writeLines(c("# B", "", "## Real", "text"), g)

  probs <- run(c(f, g), quiet = TRUE)
  want <- c("no-such-heading", "known-bugs-dated-verify",
            "missing from the Contents block", "#fake", "nope.md",
            "doubled list marker: - - **Doubled**",
            "checkbox with no list marker: - [ ] merged first item [ ] merged second item")
  missed <- want[!vapply(want, function(w) any(grepl(w, probs, fixed = TRUE)), logical(1))]
  ## Valid constructs the checker must NOT flag. A checker with only a
  ## positive control is satisfied by flagging everything.
  ## Each string has to be one an emitted message could actually contain, or the control
  ## is green by construction: "# A" was, and stayed green under every mutation of the rule
  ## it names, because no problem message quotes a heading with its hashes on. The Contents
  ## messages quote the heading text after "Contents block: ", so that is what to grep for.
  clean <- c("not-a-real-anchor",              # link inside a code fence
             "hand-written",                   # <a id> anchor, not a heading
             "a-subheading-not-in-contents",   # ### target: a real anchor, not an orphan
             "Contents block: A",              # the H1 title is never in Contents
             "- [ ] a real checklist item",    # a checkbox its own marker introduces
             "  - nested item",                # nesting, not a doubled marker
             "- -1 is the sentinel",           # the second "-" starts a value, not a bullet
             "* * *")                          # thematic break, not a list
  spurious <- unlist(lapply(clean, function(c) grep(c, probs, fixed = TRUE, value = TRUE)))

  ## Invocation errors, which are about the request rather than about the corpus. A control
  ## here is not optional: the failure this guards is a reader running --selftest, reading
  ## OK and exit 0, and concluding the negative control passed -- so the control for it is
  ## the only thing standing between that reader and a checker they never actually ran.
  ## Each case names the argument it passes, because a case built from KNOWN_FLAGS would
  ## agree with the implementation no matter what either of them said.
  argcases <- c(
    "catches an option one hyphen off the flag the header sends readers to" =
      any(grepl("Unrecognised option: --selftest", argument_problems("--selftest"),
                fixed = TRUE)),
    "catches a filename argument that is not on disk, beside one that is" =
      any(grepl("No such file: no-such-file.md",
                argument_problems(c(f, "no-such-file.md")), fixed = TRUE)),
    "ignores the option it does know" = !length(argument_problems("--self-test")),
    "ignores a filename argument that is on disk" = !length(argument_problems(f)))

  cat("self-test: planted", length(want), "defects and", length(clean), "valid constructs\n")
  for (w in want) {
    cat(sprintf("  [%s] catches: %s\n", if (w %in% missed) "MISS" else " ok ", w))
  }
  for (c in clean) {
    hit <- any(grepl(c, probs, fixed = TRUE))
    cat(sprintf("  [%s] ignores: %s\n", if (hit) "FALSE+" else " ok ", c))
  }
  for (n in names(argcases)) {
    cat(sprintf("  [%s] arguments: %s\n", if (argcases[[n]]) " ok " else "WRONG", n))
  }
  ok <- !length(missed) && !length(spurious) && all(argcases)
  cat(if (ok) "self-test PASSED - the checker detects the defects it claims to.\n"
      else    "self-test FAILED - do not trust a clean run from this checker.\n")
  unlink(d, recursive = TRUE)
  ok
}

## ---- main ------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
bad <- argument_problems(args)
if (length(bad)) {
  cat(paste0(bad, collapse = "\n"), "\n", sep = "")
  usage()
  quit(status = 1L)
}
if ("--self-test" %in% args) quit(status = if (self_test()) 0L else 1L)

paths <- args[!startsWith(args, "--")]
if (!length(paths)) {
  ## With no arguments the subject is this repo, not whatever directory the caller happens to
  ## be in -- from anywhere else that silently checked an unrelated tree and reported on it.
  ## Moving to the root, rather than prefixing every path, keeps the reported paths relative.
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) setwd(dirname(dirname(normalizePath(f[1], mustWork = FALSE))))
  paths <- suppressWarnings(system("git ls-files '*.md'", intern = TRUE))
  if (!length(paths)) paths <- list.files(".", pattern = "\\.md$", recursive = TRUE)
  ## git lists a tracked file that has been deleted without the deletion being staged, and
  ## the run is over what is on disk. Only the discovered set is filtered: a path the caller
  ## typed is checked above instead, because dropping one of those hides a typo.
  paths <- paths[file.exists(paths)]
}
if (!length(paths)) { cat("No markdown files found.\n"); quit(status = 1L) }
quit(status = if (length(run(paths))) 1L else 0L)
