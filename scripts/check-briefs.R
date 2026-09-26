#!/usr/bin/env Rscript

# Checks that every prose pointer a subagent is asked to follow lands on a file that
# subagent was actually handed.
#
# Run from anywhere:  Rscript scripts/check-briefs.R
# Exit status 0 if every pointer resolves, 1 otherwise. The subject is always the skill this
# script sits in, so it takes no argument but the flag below; anything else is named and
# exits 1, rather than being dropped so that the ordinary check can report OK in its place.
#
# Why this exists: each brief in references/subagents/ opens with a `> **Orchestrator:**`
# blockquote naming the files that agent must be *given*. The agent runs in a clean context,
# so a relative link is unfollowable and a prose pointer -- "search it for `X`", "the rule is
# in `git-and-pr.md`", "§ Test discipline", "the post-execution reviewer's § 4" -- reaches
# nothing unless its target is on that list. references/harness-notes.md § "Absolute paths,
# always" is where that rule is written down; this is the check for it. scripts/check-docs.R
# structurally cannot see this class: it asks whether a link resolves *on disk*, and every one
# of these does.
#
# Design: the set of files each agent receives is parsed out of that brief's own Orchestrator
# block at run time, so a brief that gains a file is covered without editing this script. The
# corpus a pointer can name is parsed out of SKILL.md's Reference map, which is the skill's
# own declaration of what its files are -- that keeps the repo-root docs out of it, which
# matters because `README.md` in a brief means the *package's* README, not this repo's.
#
# The distinction that decides the false-positive rate: a pointer *inside* the Orchestrator
# blockquote is addressed to the orchestrator, which holds SKILL.md and the whole skill. It
# may name a file the subagent never receives and be perfectly correct. Only the brief's body
# and the handed reference files are addressed to the subagent.
#
# Some files are a runbook *containing* a brief -- guides/periodic-review.md hands over only
# Step 1's lens sections -- so whole regions of them address the orchestrator without being
# blockquoted: an introduction, a cadence note, the preamble that assembles the brief itself.
# A one-line marker exempts such a region, from itself to the next heading:
#
#     > **Orchestrator through the end of this section.**
#
# It means what the Orchestrator block means and nothing more, so it adds no defect class
# here and no list below. Why a heading bounds it, and not a closing marker: see
# ORCH_SECTION_RE, which owns that reasoning.
#
# The run prints the lists below, and only the ones marked non-zero gate:
#   BROKEN     -- pointers that resolve outside the set. This is the list an edit must not
#                 add to, and the one the exit status is about.
#   CHECKER    -- the checker could not do its job: a file the run expects to be a brief --
#                 everything under references/subagents/, plus the names in
#                 BRIEFS_OUTSIDE_SUBAGENTS -- that is not on disk, has no Reference map row,
#                 yielded no recognised Orchestrator block, or carries a block that never
#                 says "Brief it with"; the subagents directory yielding no brief at all;
#                 or a Reference map row whose file is not on disk, which takes that file
#                 out of the corpus so nothing can point at it and nothing can miss it.
#                 Also non-zero, because a clean BROKEN list means nothing while one of
#                 these stands. Every silent false negative this checker has had was a file
#                 quietly leaving the run.
#   UNCLEAR    -- a name that fits more than one file, so nothing is checked through it.
#                 Advisory, and the only list here that is. Adding a file can put a name in
#                 this state and disarm a check that used to run, which is why it is printed
#                 rather than skipped.
#
# Run the negative control first: Rscript scripts/check-briefs.R --self-test
# It builds a small corpus holding one of each defect class and, beside each, the construct
# that mimics it and is correct, then confirms the checker separates them. A checker with only
# a positive control is satisfied by flagging everything; one shipped in this repo already
# reported a clean tree that was not, and a later one reported a clean tree as broken.

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

read_md <- function(path) {
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  Encoding(x) <- "UTF-8"
  x
}

## ---- markdown shredding ----------------------------------------------------
## A pointer inside a code fence is an example, not an address.
fenced_lines <- function(lines) {
  open <- FALSE
  vapply(lines, function(l) {
    if (grepl("^[[:space:]]*(```|~~~)", l)) { open <<- !open; return(TRUE) }
    open
  }, logical(1), USE.NAMES = FALSE)
}

## Indented code. A tab or four spaces, then something other than whitespace: the form
## markdown has always rendered as a code block, and the one this repo actually writes its
## examples in -- the marker example in this file's own header is written that way, and so is
## every command block in templates/PROFILE.md.
INDENTED <- "^(?:\t| {4,})[^[:space:]]"

## A fence is not the only way this repo writes an example, and for the marker below it is not
## even the usual way: most examples here are 4-space-indented blocks, which fenced_lines()
## structurally cannot see. It matters most where a marker is honoured by position: an
## indented *example* of the Orchestrator section marker, read as live, exempts every pointer
## from itself to the next heading, and the checker then reports clean over pointers nobody
## checked.
example_lines <- function(lines) fenced_lines(lines) | grepl(INDENTED, lines)

heading_texts <- function(lines) {
  idx <- grep("^#{1,6}[[:space:]]+", lines)
  idx <- idx[!fenced_lines(lines)[idx]]
  trimws(sub("^#{1,6}[[:space:]]+", "", lines[idx]))
}

## Section names are compared loosely on purpose: a pointer writes "§ Close the loop" at a
## heading titled "7. Close the loop and open the PR", and renumbering or extending a heading
## must not read as a broken pointer.
squash <- function(s) trimws(tolower(gsub("[^[:alnum:]]+", " ", s)))

norm <- function(s) tolower(gsub("[^[:alnum:]]", "", s))

tokens <- function(s) {
  t <- unlist(strsplit(squash(s), " +"))
  unique(t[nzchar(t)])
}

## ---- the corpus a pointer can name -----------------------------------------
## SKILL.md's Reference map routes to every file the skill expects an agent to read, so it is
## the corpus definition that already exists, maintained for its own sake. Deriving the corpus
## from `git ls-files` instead would pull in the repo-root docs, whose names also name files
## in the package under review, and a mention of one of those is not a skill pointer.
reference_map <- function(root) {
  p <- file.path(root, "SKILL.md")
  if (!file.exists(p)) return(character(0))
  lines <- read_md(p)
  h <- grep("^##[[:space:]]+Reference map[[:space:]]*$", lines)
  if (!length(h)) return(character(0))
  nxt <- grep("^##[[:space:]]+", lines)
  nxt <- nxt[nxt > h[1]]
  end <- if (length(nxt)) nxt[1] - 1L else length(lines)
  blk <- lines[(h[1] + 1L):end]
  tgt <- unlist(regmatches(blk, gregexpr("\\]\\([^)]+\\.md\\)", blk, perl = TRUE)))
  tgt <- sub("^\\]\\(", "", sub("\\)$", "", tgt))
  tgt <- tgt[!grepl("^(https?:|mailto:|/)", tgt)]
  keep <- file.exists(file.path(root, tgt))
  out <- unique(c("SKILL.md", tgt[keep]))
  ## A row whose file is gone used to be dropped right here, and dropping it takes the file
  ## out of the corpus -- so no pointer can resolve to it, no brief can be expected of it,
  ## and both halves of the check go quiet together over the same deletion while OK prints.
  ## The row is the skill's own claim that the file exists, so its target being absent is a
  ## corpus failure, not a pointer defect. Carried out as an attribute for the reason the
  ## ambiguity attribute below gives: every caller that only wants the corpus is unchanged.
  attr(out, "missing") <- unique(tgt[!keep])
  out
}

## Repo-relative, with `..` folded in. normalizePath() is no help here: these paths are
## resolved against the corpus listing rather than the filesystem, and it leaves `..` in place
## for anything it cannot stat.
collapse_path <- function(p) {
  out <- character(0)
  for (x in strsplit(p, "/", fixed = TRUE)[[1]]) {
    if (!nzchar(x) || x == ".") next
    if (x == "..") { if (length(out)) out <- out[-length(out)]; next }
    out <- c(out, x)
  }
  paste(out, collapse = "/")
}

## ---- "it fits more than one file" ------------------------------------------
## A name that fits several candidates resolves to nothing, and guessing would be worse. But
## resolving to nothing *silently* is its own defect: adding a file can push an existing name
## into ambiguity and disarm a check that used to run, with no signal anywhere. So the
## candidates ride along on the NA and get reported. Every caller that only asks `is.na()`
## behaves exactly as before, which is why this is an attribute rather than a new return type.
ambiguous <- function(cands) structure(NA_character_, candidates = cands)
ambiguity <- function(x) attr(x, "candidates")

## The corpus writes pointers three ways -- relative to the file they sit in, relative to the
## skill root, and as a bare filename -- so all three resolve. A bare name that fits more than
## one file names nothing resolvable, and saying nothing beats guessing.
resolve_token <- function(tok, from_dir, corpus) {
  tok <- sub("#.*$", "", tok)
  if (!nzchar(tok)) return(NA_character_)
  if (!grepl("/", tok, fixed = TRUE)) {
    hit <- corpus[basename(corpus) == tok]
    if (length(hit) == 1L) return(hit)
    return(if (length(hit) > 1L) ambiguous(hit) else NA_character_)
  }
  cand <- unique(c(collapse_path(file.path(from_dir, tok)), collapse_path(tok)))
  hit <- corpus[corpus %in% cand]
  if (length(hit)) hit[1] else NA_character_
}

## ---- pointer forms ---------------------------------------------------------
## Every length bound below is a sanity stop, not a tuned value: a quoted string or a heading
## name that long has run off the end of the construct it belongs to, and matching further
## only produces noise.
##
## A filename in prose, whether backticked, plain, or the target of a markdown link. The
## lookbehind keeps the tail of `..._response.md` and a bare `.md` out. The optional leading
## dot admits `.workflow/PROFILE.md`, which resolves to no skill file but must still be
## *seen*: a section reference after it belongs to the repo's profile, and treating the
## profile as unnamed would attribute that section to the file the pointer sits in.
FILE_RE <- paste0("(?<![A-Za-z0-9_./-])((?:\\.{1,2}/)*\\.?[A-Za-z0-9_][A-Za-z0-9_./-]*\\.md)",
                  "(?:#[A-Za-z0-9_-]+)?")

## "search it for X" names the string to grep for, which is a claim about the target's
## contents that can rot on its own even when the file is handed over.
SEARCH_RE <- paste0("search (?:it|them|this file|the file) for[[:space:]]+",
                    "(?:\"([^\"]{2,140})\"|`([^`]{2,140})`|“([^”]{2,140})”)")

## A section reference. The name has to start with a letter, so numeric ones (`§ 3`, `§§ 2,
## 3`, `§3.4`) go unchecked. Most of them address a numbered section of the repo's own
## profile, of an output format, or of the authority document, none of which this checker
## could resolve anyway. But nothing stops one addressing a section of a skill file, and one
## has: `post-exec-reviewer.md` numbered its own steps and pointed at them that way, while
## this comment claimed the form never did. So it is unchecked rather than impossible, and
## the common case is not a guarantee. Reaching it needs a rule that can tell the two apart,
## and this is not that rule.
SECTION_RE <- paste0("§[[:space:]]*(?:\"([^\"]{1,90})\"|",
                     "([A-Za-z][^,.;:|+()\\[\\]\"—–#]{0,89}))")

## "the post-execution reviewer's § 4" -- a file named by the role that owns it. Restricted to
## the possessive-plus-section form on purpose: "the sentinel's Check 1 handles copy-paste" is
## a statement about who does what, not an instruction to go and read anything.
##
## Case-insensitive, like role_mention_re() below: a sentence-initial "The post-execution
## reviewer's § 4 ..." is the same pointer as the mid-sentence form, and hardcoding lowercase
## `the` here meant the identical construct was caught in one position and missed in the other.
ROLE_POSS_RE <- "(?i)the ([A-Za-z][A-Za-z -]{2,40}?)['’]s[[:space:]]*§"

## "the git reference", "the skill's ExecPlan reference", "the skill entry" -- a file named by
## periphrasis. Case-insensitive for the same reason as ROLE_POSS_RE. `entry` is in the noun
## list because leaving it out did not merely miss a pointer: a section reference that follows
## an unrecognised periphrasis falls back to the containing file, so the checker reported a
## real defect against the wrong file.
PERIPH_RE <- paste0("(?i)the (?:skill['’]s )?([A-Za-z][A-Za-z0-9 '’-]{2,40}?)[[:space:]]",
                    "(?:reference|guide|guidance|brief|document|entry)\\b")

matches <- function(re, s) {
  m <- gregexpr(re, s, perl = TRUE)[[1]]
  if (m[1] == -1L) return(list())
  st <- as.integer(m); ln <- attr(m, "match.length")
  gp <- attr(m, "capture.start"); gl <- attr(m, "capture.length")
  lapply(seq_along(st), function(k) {
    groups <- character(0)
    if (!is.null(gp)) {
      groups <- vapply(seq_len(ncol(gp)), function(g) {
        if (gp[k, g] <= 0L) "" else substr(s, gp[k, g], gp[k, g] + gl[k, g] - 1L)
      }, character(1))
    }
    list(start = st[k], text = substr(s, st[k], st[k] + ln[k] - 1L), groups = groups)
  })
}

## An unquoted section name ends at the next delimiter, so a long one means the match ran past
## the heading into the sentence around it. Truncating rather than dropping keeps the pointer
## checkable, since the heading match is a substring test anyway.
section_name <- function(g) {
  s <- trimws(if (nzchar(g[1])) g[1] else g[2])
  s <- sub("[[:space:]]+(below|above)$", "", s)
  w <- strsplit(trimws(s), "[[:space:]]+")[[1]]
  if (length(w) > 8L) s <- paste(w[1:8], collapse = " ")
  trimws(s)
}

## A periphrasis resolves only when it names exactly one file in the corpus: "the git
## reference" -> git-and-pr.md. "the written guidance" names no file and is left alone. Two
## letters cannot identify a file either, so they are not treated as trying to.
periphrasis_target <- function(phrase, corpus) {
  p <- norm(phrase)
  if (nchar(p) < 3L) return(NA_character_)
  stems <- norm(sub("\\.md$", "", basename(corpus)))
  hit <- corpus[stems == p | startsWith(stems, p)]
  if (length(hit) == 1L) return(hit)
  if (length(hit) > 1L) return(ambiguous(hit))
  NA_character_
}

## ---- roles -----------------------------------------------------------------
## Role names come from each brief's own H1 and filename, so a renamed or added brief is
## covered without editing this script. A phrase that fits more than one brief -- "the
## reviewer's § 4" -- names nothing and is dropped rather than guessed at.
role_index <- function(briefs, root) {
  vocab <- list(); phrases <- character(0)
  for (b in briefs) {
    lines <- read_md(file.path(root, b))
    i <- grep("^#[[:space:]]+", lines)
    h1 <- if (length(i)) sub("^#[[:space:]]+", "", lines[i[1]]) else ""
    h1 <- trimws(sub("\\(.*$", "", h1))          # "Planning reviewer (pre-implementation)"
    stem <- sub("\\.md$", "", basename(b))
    vocab[[b]] <- unique(c(tokens(h1), tokens(stem)))
    phrases <- c(phrases, h1[nzchar(h1)], stem)
  }
  list(vocab = vocab, phrases = unique(phrases))
}

role_target <- function(phrase, roles) {
  t <- tokens(phrase)
  if (!length(t)) return(NA_character_)
  hit <- names(roles$vocab)[vapply(roles$vocab, function(v) all(t %in% v), logical(1))]
  if (length(hit) == 1L) return(hit)
  if (length(hit) > 1L) return(ambiguous(hit))
  NA_character_
}

## Where "search it for X" names no file, the paragraph normally names the role instead:
## "The post-execution reviewer carries ... -- search it for "...".".
role_mention_re <- function(roles) {
  alt <- paste(gsub("([^A-Za-z0-9 ])", "\\\\\\1", roles$phrases), collapse = "|")
  paste0("(?i)the (", alt, ")")
}

## ---- units -----------------------------------------------------------------
## A pointer and the file it names are routinely split across a line break, and a run of
## pointers is routinely a run of list items with no blank line between them. So the scan
## works on units -- one paragraph, or one list item -- joined into a single string with a
## character-to-line map. That way "the nearest file named before this section reference"
## means within the same item, and a reported line number is still the real one.
build_units <- function(lines, skip) {
  fen <- fenced_lines(lines)
  out <- list(); txt <- character(0); map <- integer(0)
  flush <- function() {
    if (!length(txt)) return(invisible(NULL))
    out[[length(out) + 1L]] <<- list(text = paste(txt, collapse = ""), map = map)
    txt <<- character(0); map <<- integer(0)
  }
  for (i in seq_along(lines)) {
    if (skip[i] || fen[i]) { flush(); next }
    l <- sub("^[[:space:]]*>[[:space:]]?", "", lines[i])
    if (!nzchar(trimws(l))) { flush(); next }
    if (grepl("^[[:space:]]*(?:[-*+]|[0-9]+\\.)[[:space:]]", l) ||
        grepl("^#{1,6}[[:space:]]", l)) flush()
    piece <- if (length(txt)) paste0(" ", trimws(l)) else trimws(l)
    txt <- c(txt, piece)
    map <- c(map, rep(i, nchar(piece)))
  }
  flush()
  out
}

line_at <- function(u, pos) u$map[min(max(pos, 1L), length(u$map))]

## ---- briefs and the files each agent receives ------------------------------
## The marker is matched loosely -- case-insensitively, with the colon inside the bold,
## outside it, or absent. A byte-exact marker made drift catastrophic and silent: write
## `> **Orchestrator**:` and the brief left the run entirely, taking its defects with it,
## while the run still printed OK. Loosening lowers the odds of that. What makes it *loud*
## when it happens anyway is the sweep in run() that insists every file the repo declares a
## brief yielded a block -- that is the half that matters.
ORCH_RE <- paste0("(?i)^[[:space:]]*>[[:space:]]*\\*\\*[[:space:]]*orchestrator",
                  "[[:space:]]*:?[[:space:]]*\\*\\*[[:space:]]*:?")

## Every block in the file, not just the first: a brief spawned twice per cycle plausibly
## grows a second block, and only the first used to be exempt, so the second's pointers --
## addressed to the orchestrator, which holds the whole skill -- were reported as broken.
orchestrator_ranges <- function(lines) {
  hits <- grep(ORCH_RE, lines, perl = TRUE)
  if (!length(hits)) return(list())
  out <- list()
  for (i in hits) {
    if (length(out) && i <= out[[length(out)]][2L]) next   # already inside a block
    j <- i
    repeat {
      k <- j + 1L
      ## One blank line inside the block is a continuation. A truly blank line between two
      ## `>` lines is an editing artifact, and treating it as the end both un-exempted the
      ## rest of the block and truncated the briefing list at the same point.
      if (k <= length(lines) && !nzchar(trimws(lines[k]))) k <- k + 1L
      if (k > length(lines) || !grepl("^[[:space:]]*>", lines[k])) break
      j <- k
    }
    out[[length(out) + 1L]] <- c(i, j)
  }
  out
}

## A region of a runbook that addresses the orchestrator without being a blockquote. Wrapping
## an introduction or a cadence note in `>` would misrepresent it, but leaving it bare means
## every skill pointer in it reads as a pointer some subagent cannot follow -- and the
## cheapest-looking repair for whoever hits that is to add the file to the brief's "Brief it
## with" list, which is the exact catastrophe the boundaries above exist to prevent.
##
## The marker exempts from its own line to the line before the next heading, at any level, or
## to the end of the file if none follows. Heading-bounded rather than a matched begin/end
## pair on purpose: a heading *terminates* a range instead of being swallowed by one, so a
## section added later, under a heading of its own, cannot end up silently exempt because
## somebody forgot to close a pair. Visible rather than an HTML comment for the same family of
## reason -- it reuses the `> **...**` idiom the file already uses, and it cannot rot unseen.
##
## The semantics are the ones an Orchestrator block already has and nothing more: the range
## addresses the orchestrator whichever agent happens to be holding the file. So there is no
## new structural defect class, no new list, and no change to the exit status. The one way to
## malform this is to write a marker the regex does not recognise, and then the file is simply
## scanned end to end -- today's behaviour, and loud. Matched loosely for the reason ORCH_RE
## is. Example lines are excluded for the reason every other pointer form excludes them: a
## marker inside a code block is an example of the idiom, not a use of it -- and here that
## covers the indented form as well as the fenced one, because this repo writes most of its
## examples indented and honouring one exempts a whole section on the strength of a sample.
ORCH_SECTION_RE <- paste0(
  "(?i)^[[:space:]]*>[[:space:]]*\\*\\*[[:space:]]*orchestrator[[:space:]]+through",
  "[[:space:]]+the[[:space:]]+end[[:space:]]+of[[:space:]]+this[[:space:]]+section",
  "[[:space:]]*[.:]?[[:space:]]*\\*\\*")

orchestrator_section_ranges <- function(lines) {
  ex <- example_lines(lines)
  hits <- grep(ORCH_SECTION_RE, lines, perl = TRUE)
  hits <- hits[!ex[hits]]
  if (!length(hits)) return(list())
  heads <- grep("^#{1,6}[[:space:]]+", lines)
  heads <- heads[!ex[heads]]
  lapply(hits, function(i) {
    nxt <- heads[heads > i]
    c(i, if (length(nxt)) nxt[1] - 1L else length(lines))
  })
}

BRIEF_WITH_RE <- "(?i)brief (?:it|the subagent|them) with"

## The handed set is what the "Brief it with:" sentence names. Three boundaries decide it,
## and each one was wrong in a way that was invisible from the output:
##
##   * It starts at the *match position* of the phrase, not at the start of the line holding
##     it. Every Orchestrator block names harness-notes.md in the *spawn* instruction, which
##     is addressed to the orchestrator and is not a file the subagent receives. All four
##     briefs put that instruction next to "Brief it with", so joining two lines -- a pure
##     whitespace reflow -- used to sweep it into the handed set and silently excuse every
##     unfollowable pointer at it.
##   * A blank line -- truly blank, or the bare `>` that separates two paragraphs of one
##     blockquote -- continues the list, so a file named after a separator is still handed
##     over. It used to end it.
##   * What ends the list is the next *directive*. Every block marks a new instruction to the
##     orchestrator with a bold lead-in ("**Use for:**", "**All of them are required.**",
##     "**What a small change may downshift ... `SKILL.md` § "Downshifting"**"), and those
##     paragraphs name files the orchestrator holds and the subagent does not. Reading them
##     as handed over would silently excuse every unfollowable pointer at *those*, which is
##     the same defect the first boundary exists to prevent.
##
## Returns `found` as well as the set, because a block that never says "Brief it with"
## collapses the set to the brief itself -- which is not an answer, it is the check not
## running -- and that has to be said out loud rather than inferred from the noise.
##
## The set is per *file*, and one file can be several briefs. guides/periodic-review.md hands
## each lens section to its own agent, so a file named once after "Brief them with" is handed,
## as far as this function can tell, to every one of them. references/cran-gate.md genuinely
## goes to one lens alone -- it is a runbook opening with a formatter command, and the
## refactoring lens must not receive it -- and that restriction is prose there and unenforced
## here: a pointer at it planted in another lens section passes. Known and left that way.
##
## Left that way because the signal is not in the file to read. Both files that runbook hands
## over are named, outside the regions addressed to the orchestrator, only from the same lens
## section, so no rule keyed to where a pointer sits can separate "goes in every brief" from
## "goes to one lens". Only the prose separates them, and the places that state it already word
## it differently. A regex over that prose is the detector class this checker exists not to be:
## reworded, it stops scoping with nothing to show for it, and the run goes quiet rather than
## loud. A per-lens "Brief it with" block inside each lens section would read cleanly here and
## would fail loudly, but it puts orchestrator-addressed text inside the region that runbook
## promises is nothing but the brief, which is the hazard that whole file is built around. So
## the restriction stays prose, and this paragraph is what a later reader gets instead of a
## green line that means less than it looks like.
handed_set <- function(lines, ranges, brief_rel, corpus) {
  out <- brief_rel
  found <- FALSE
  for (rng in ranges) {
    bare <- trimws(sub("^[[:space:]]*>[[:space:]]?", "", lines[rng[1]:rng[2]]))
    st <- grep(BRIEF_WITH_RE, bare, perl = TRUE)
    if (!length(st)) next
    found <- TRUE
    st <- st[1]
    end <- length(bare)
    after_blank <- FALSE
    for (k in seq_len(length(bare) - st) + st) {
      if (!nzchar(bare[k])) { after_blank <- TRUE; next }
      if (after_blank && startsWith(bare[k], "**")) { end <- k - 1L; break }
      after_blank <- FALSE
    }
    txt <- paste(bare[st:end], collapse = " ")
    m <- regexpr(BRIEF_WITH_RE, txt, perl = TRUE)
    for (mm in matches(FILE_RE, substring(txt, m[1]))) {
      r <- resolve_token(mm$groups[1], dirname(brief_rel), corpus)
      if (!is.na(r)) out <- c(out, r)
    }
  }
  list(set = unique(out), found = found)
}

## ---- one brief -------------------------------------------------------------
check_brief <- function(brief_rel, root, corpus, roles, headings_by, orch_by, orch_sec_by) {
  lines <- read_md(file.path(root, brief_rel))
  hs <- handed_set(lines, orch_by[[brief_rel]], brief_rel, corpus)
  set <- hs$set
  mention_re <- role_mention_re(roles)

  structural <- if (hs$found) character(0) else sprintf(
    paste("%s  no Orchestrator block says \"Brief it with\", so the handed set collapsed to",
          "the brief itself and nothing else in it was checked"), brief_rel)

  problems <- character(0)
  unclear <- character(0)
  seen <- character(0)     # one not-given report per file:line:target, whichever rule found it
  add <- function(path, ln, msg) {
    problems <<- c(problems, sprintf("%s:%d  %s", path, ln, msg))
  }
  ## A name that fits several files checks nothing. Reported, but not as a broken pointer:
  ## the pointer may well be fine, and what needs a human is that no rule ran through it.
  note_unclear <- function(path, ln, what, cands) {
    if (is.null(cands)) return(invisible(NULL))
    msg <- sprintf("%s:%d  cannot tell what \"%s\" names -- it fits %s, so nothing is checked",
                   path, ln, trimws(what), paste(cands, collapse = " and "))
    if (!msg %in% unclear) unclear <<- c(unclear, msg)
    invisible(NULL)
  }
  want <- function(path, ln, target, how) {
    if (target %in% set) return(TRUE)
    key <- paste(path, ln, target)
    if (!key %in% seen) {
      seen <<- c(seen, key)
      add(path, ln, sprintf("%s %s, which this agent is not given", how, target))
    }
    FALSE
  }

  for (path_rel in intersect(c(brief_rel, set), corpus)) {
    src <- read_md(file.path(root, path_rel))
    skip <- rep(FALSE, length(src))
    ## An Orchestrator block is addressed to the orchestrator whichever agent happens to be
    ## holding the file: a plan reviewer is handed post-exec-reviewer.md as its review
    ## specification and reads that brief's block too.
    for (orch in orch_by[[path_rel]]) skip[orch[1]:orch[2]] <- TRUE
    ## The heading-bounded marker means the same thing, so the two masks are one union.
    for (sec in orch_sec_by[[path_rel]]) skip[sec[1]:sec[2]] <- TRUE
    from_dir <- dirname(path_rel)

    for (u in build_units(src, skip)) {
      ## Files named in this unit, in order -- the context every other form resolves against.
      named <- lapply(matches(FILE_RE, u$text), function(m) {
        list(start = m$start, token = m$groups[1],
             target = resolve_token(m$groups[1], from_dir, corpus))
      })
      for (n in named) {
        if (is.na(n$target)) {
          note_unclear(path_rel, line_at(u, n$start), n$token, ambiguity(n$target))
          next
        }
        if (identical(n$target, path_rel)) next
        want(path_rel, line_at(u, n$start), n$target, "points at")
      }
      ## The nearest file named before a pointer owns it. One that resolves to nothing still
      ## owns it: `.workflow/PROFILE.md § Gotchas` addresses the repo's profile, not a skill
      ## file, and following the chain further back would attribute the section to whatever
      ## happened to be named earlier in the sentence.
      owner <- function(pos) {
        before <- Filter(function(n) n$start < pos, named)
        if (!length(before)) return(NULL)
        before[[length(before)]]$target
      }

      for (m in matches(SEARCH_RE, u$text)) {
        needle <- trimws(paste0(m$groups, collapse = ""))
        ln <- line_at(u, m$start)
        tgt <- owner(m$start)
        if (is.null(tgt)) {
          r <- Filter(function(x) x$start < m$start, matches(mention_re, u$text))
          if (length(r)) tgt <- role_target(r[[length(r)]]$groups[1], roles)
        }
        if (is.null(tgt) || is.na(tgt)) next
        if (!want(path_rel, ln, tgt, "tells the agent to search")) next
        if (!any(grepl(needle, read_md(file.path(root, tgt)), fixed = TRUE))) {
          add(path_rel, ln,
              sprintf("says to search %s for \"%s\", which is not in it", tgt, needle))
        }
      }

      for (m in matches(SECTION_RE, u$text)) {
        sec <- section_name(m$groups)
        if (!nzchar(sec)) next
        ln <- line_at(u, m$start)
        tgt <- owner(m$start)
        anonymous <- is.null(tgt)               # no file named: try this file's own headings
        if (anonymous) tgt <- path_rel
        if (is.na(tgt)) next                    # a file, just not one the skill owns
        if (!want(path_rel, ln, tgt, "points at a section of")) next
        if (any(grepl(squash(sec), squash(headings_by[[tgt]]), fixed = TRUE))) next
        if (!anonymous) {
          add(path_rel, ln,
              sprintf("points at %s § \"%s\", which is no heading there", tgt, sec))
        } else {
          ## Naming the containing file here would be a wrong message on a real defect.
          ## The class: a line routes a reader to a step of the orchestrator's own
          ## procedure by writing `§` and no filename, and that heading lives in SKILL.md,
          ## which no brief hands over. Attributing the section to the file the sentence
          ## sits in sent the reader to the one file that is not the problem.
          add(path_rel, ln, sprintf(
            "points at § \"%s\", which names no file this agent holds and is no heading here",
            sec))
        }
      }

      for (m in matches(ROLE_POSS_RE, u$text)) {
        tgt <- role_target(m$groups[1], roles)
        if (is.na(tgt)) {
          note_unclear(path_rel, line_at(u, m$start), m$text, ambiguity(tgt))
          next
        }
        if (identical(tgt, path_rel)) next
        want(path_rel, line_at(u, m$start), tgt, "points at")
      }

      for (m in matches(PERIPH_RE, u$text)) {
        tgt <- periphrasis_target(m$groups[1], corpus)
        if (is.na(tgt)) {
          note_unclear(path_rel, line_at(u, m$start), m$text, ambiguity(tgt))
          next
        }
        if (identical(tgt, path_rel)) next
        want(path_rel, line_at(u, m$start), tgt, "points by periphrasis at")
      }
    }
  }
  list(brief = brief_rel, problems = problems, unclear = unclear, structural = structural)
}

## ---- running ---------------------------------------------------------------
## Every brief has to reach the run as one. Two things drop one silently -- an Orchestrator
## marker the regex does not recognise, and a missing row in SKILL.md's Reference map -- and
## either way the brief and all its defects leave the run while it still prints OK. Loosening
## the marker lowers the odds; this is what makes it audible.
##
## What counts as a brief is *declared*, never recognised: everything under
## references/subagents/ by construction, plus the names below for the ones that live
## elsewhere. A runbook can contain a brief -- guides/periodic-review.md hands over its lens
## sections and nothing else -- and no property of where it sits says so, so the name is
## written down here. Adding a brief outside that directory means adding it here too.
##
## Recognising the set instead -- say, every corpus file with "orchestrator" inside a
## blockquote -- reads more general and is strictly weaker, because it would derive the
## expectation from the same text whose drift it exists to catch. Delete a brief's Reference
## map row and it leaves the corpus, so it is never scanned for blockquotes, so nothing
## expects it, and the run goes clean over the defect. Reword the marker of a brief whose only
## orchestrator blockquote is that marker and the same thing happens. It also gates on files
## that are not briefs: any blockquote saying "the orchestrator" -- a runbook's section marker,
## a quoted lesson -- becomes a brief that failed to show up, and the cheapest-looking repair
## for that is to reword innocent prose. A directory listing and a written name are both
## independent of what the file says, which is the entire property needed here.
BRIEFS_OUTSIDE_SUBAGENTS <- c("guides/periodic-review.md")

expected_briefs <- function(root, corpus, briefs, declared = BRIEFS_OUTSIDE_SUBAGENTS) {
  dir <- file.path(root, "references", "subagents")
  found <- sort(list.files(dir, pattern = "\\.md$"))
  in_dir <- if (length(found)) paste("references", "subagents", found, sep = "/") else
    character(0)
  out <- character(0)
  ## The sweep is a directory listing, and list.files() answers character(0) for a directory
  ## that is not there exactly as it does for one holding nothing. Either way the half of
  ## the declaration that is supposed to need no maintenance declares nothing, every brief
  ## under it leaves the run unannounced, and no later rule can notice -- a file that never
  ## entered the expected set is never missed. So emptiness is the failure, and the two ways
  ## of reaching it are named apart because the fix for each is somewhere else.
  if (!length(found)) {
    out <- sprintf("references/subagents/  %s, so nothing under it is expected to be a brief",
                   if (dir.exists(dir)) "holds no .md file" else "is not a directory")
  }
  for (rel in unique(c(in_dir, declared))) {
    if (rel %in% briefs) next
    ## Order matters: a declared name that is not on disk resolves to no corpus row either,
    ## and blaming the Reference map for a file that was renamed away sends the reader to the
    ## one place the fix does not belong.
    out <- c(out, if (!file.exists(file.path(root, rel)))
      sprintf("%s  is named here as a brief but is not on disk, so nothing checks it", rel)
    else if (!rel %in% corpus)
      sprintf("%s  has no row in SKILL.md's Reference map, so it never entered the run", rel)
    else
      sprintf("%s  yielded no recognised `> **Orchestrator:**` block, so nothing checks it",
              rel))
  }
  out
}

run <- function(root, quiet = FALSE, declared = BRIEFS_OUTSIDE_SUBAGENTS) {
  corpus <- reference_map(root)
  gone <- sprintf("%s  has a Reference map row but is not on disk, so it left the corpus",
                  attr(corpus, "missing"))
  if (!length(corpus)) {
    if (!quiet) cat("Cannot read SKILL.md's Reference map; nothing defines the corpus.\n")
    return(list(problems = "SKILL.md has no Reference map", structural = character(0),
                unclear = character(0), by_brief = list()))
  }
  headings_by <- list(); orch_by <- list(); orch_sec_by <- list()
  for (p in corpus) {
    lines <- read_md(file.path(root, p))
    headings_by[[p]] <- heading_texts(lines)
    r <- orchestrator_ranges(lines)
    if (length(r)) orch_by[[p]] <- r
    ## Deliberately a separate list. `orch_by`'s *names* decide what is a brief and its
    ## *ranges* feed handed_set(); the section marker must do neither. It is an exemption
    ## from the scan and nothing else -- it cannot enrol a runbook as a brief, and it cannot
    ## quietly widen the set of files a brief is taken to hand over.
    s <- orchestrator_section_ranges(lines)
    if (length(s)) orch_sec_by[[p]] <- s
  }
  briefs <- corpus[corpus %in% names(orch_by)]
  structural <- c(gone, expected_briefs(root, corpus, briefs, declared))
  roles <- role_index(briefs, root)

  results <- lapply(briefs, check_brief, root = root, corpus = corpus, roles = roles,
                    headings_by = headings_by, orch_by = orch_by, orch_sec_by = orch_sec_by)
  problems <- unlist(lapply(results, `[[`, "problems"), use.names = FALSE)
  ## Kept per brief as well as flattened: the same file is handed to more than one agent, so
  ## "is this pointer broken *for this brief*" is a different question from "does this line
  ## appear anywhere in the output", and the self-test has to be able to ask the first one.
  by_brief <- stats::setNames(lapply(results, `[[`, "problems"), briefs)
  structural <- c(structural, unlist(lapply(results, `[[`, "structural"), use.names = FALSE))
  unclear <- unique(unlist(lapply(results, `[[`, "unclear"), use.names = FALSE))

  if (!quiet) {
    if (length(structural)) {
      cat("\nCHECKER CANNOT DO ITS JOB -- part of the corpus did not reach the run\n")
      cat("  Until this is fixed, a clean pointer list below means nothing: the defects in\n")
      cat("  the file named here were never looked for.\n")
      cat(paste0("  ", structural, collapse = "\n"), "\n", sep = "")
    }
    for (r in results) {
      if (!length(r$problems)) next
      cat(sprintf("\n%s -- pointers the agent it briefs cannot follow\n", r$brief))
      cat(paste0("  ", r$problems, collapse = "\n"), "\n", sep = "")
    }
    if (length(problems)) {
      cat("\nBROKEN: a pointer names a file the agent that reads it was not handed.\n")
      cat("Either add the file to that brief's Orchestrator block, or rewrite the pointer\n")
      cat("to say what the agent needs without sending it anywhere.\n")
    } else if (!length(structural)) {
      cat("OK: every prose pointer resolves inside the set its brief hands over.\n")
    }
    if (length(unclear)) {
      cat("\nUNCLEAR (human judgement required; does not affect exit status)\n")
      cat("  These names fit more than one file, so no rule ran through them. Adding a file\n")
      cat("  can put a name in this state and disarm a check that used to run, which is why\n")
      cat("  they are printed rather than skipped.\n")
      cat(paste0("  ", unclear, collapse = "\n"), "\n", sep = "")
    }
  }
  list(problems = problems, structural = structural, unclear = unclear, by_brief = by_brief)
}

## ---- what the caller asked for ---------------------------------------------
## This checker's subject is the skill root it sits in, never a path handed to it, so every
## argument other than the flag below is a request it cannot honour. Discarding one used to
## run the ordinary check and exit 0, and `--selftest` -- one hyphen from the flag this
## file's header sends every reader to first -- took exactly that path, so the reader saw an
## OK line and concluded the negative control had passed. An argument is not a defect in the
## tree, so it enters no list here: it says the run the caller asked for never happened.
KNOWN_FLAGS <- c("--self-test")

argument_problems <- function(args) {
  sprintf("Unrecognised argument: %s", setdiff(args, KNOWN_FLAGS))
}

## ---- negative control ------------------------------------------------------
## The fixture plants one of each defect class and, beside each, the construct that looks
## identical and is correct. Both halves are required: a checker with only a positive control
## is satisfied by flagging everything, and this repo has shipped a checker that did.
write_fixture <- function(d) {
  dir.create(file.path(d, "references", "subagents"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "guides"), showWarnings = FALSE)
  w <- function(p, x) {
    dir.create(dirname(file.path(d, p)), recursive = TRUE, showWarnings = FALSE)
    writeLines(x, file.path(d, p), useBytes = TRUE)
  }

  ## The names of the briefs that live outside references/subagents/ are taken from the shipped
  ## list rather than invented here, and each one gets a file below whose marker has drifted.
  ## So a name dropped from that list -- or the list emptied -- fails this self-test, instead
  ## of going quiet in the real run, which is the failure the list exists to prevent.
  declared_rows <- vapply(BRIEFS_OUTSIDE_SUBAGENTS, function(rel)
    sprintf("| **[%s](%s)** | Declared a brief; marker drifted |", rel, rel),
    character(1), USE.NAMES = FALSE)

  w("SKILL.md", c(
    "# Demo skill", "",
    "## Downshifting", "", "What a small change may drop.", "",
    "## Reference map", "",
    "| Read this | When |", "|---|---|",
    "| **[references/alpha.md](references/alpha.md)** | The bars |",
    "| **[references/beta.md](references/beta.md)** | Nobody hands this out |",
    ## Mapped and never written. Nothing else in the fixture points at it, which is the whole
    ## point: a row whose file is gone takes the file out of the corpus, so the pointers that
    ## would have dangled cannot be seen to dangle, and only the row itself is evidence.
    "| **[references/gone.md](references/gone.md)** | A row whose file was deleted |",
    "| **[references/harness-notes.md](references/harness-notes.md)** | Spawning |",
    "| **[references/notes.md](references/notes.md)** | One of two files named notes |",
    "| **[guides/notes.md](guides/notes.md)** | The other one |",
    "| **[references/subagents/demo.md](references/subagents/demo.md)** | Briefing demo |",
    "| **[references/subagents/other.md](references/subagents/other.md)** | Briefing other |",
    "| **[references/subagents/third.md](references/subagents/third.md)** | Odd marker |",
    "| **[references/subagents/nolist.md](references/subagents/nolist.md)** | No list |",
    "| **[references/subagents/unread.md](references/subagents/unread.md)** | No marker |",
    "| **[guides/delta.md](guides/delta.md)** | Handed after a separator |",
    "| **[guides/runbook.md](guides/runbook.md)** | A brief inside a runbook |",
    "| **[guides/declared.md](guides/declared.md)** | A brief outside the subagents dir |",
    "| **[guides/gamma.md](guides/gamma.md)** | One build model only |",
    declared_rows))

  ## A repo-root doc that is NOT in the Reference map, and whose name also names a file in
  ## every package under review.
  w("README.md", c("# Readme", "", "Not briefed material."))
  w("guides/gamma.md", c("# Gamma", "", "## Building", "", "Text."))
  w("guides/delta.md", c("# Delta", "", "## Deltas", "", "Text the demo reviewer holds."))
  w("references/harness-notes.md", c("# Harness notes", "", "## Absolute paths", "", "Text."))
  ## Nobody hands beta.md out, so it is never scanned -- unless a boundary bug puts it in
  ## someone's set, and then this link is the spurious finding that says so.
  w("references/beta.md", c(
    "# Beta", "", "## The rule", "",
    "Text nobody is given. The build model is in [gamma](../guides/gamma.md)."))
  ## Two files share a basename, so a bare mention of it resolves to neither.
  w("references/notes.md", c("# Notes", "", "Text."))
  w("guides/notes.md", c("# Notes", "", "Text."))

  ## A runbook whose brief is one section of it. The pointer is the same sentence repeated,
  ## so position -- and only position -- separates the exempt one from the rest. Its only
  ## blockquote is the marker, which must not enrol it as a brief. Neither example marker has
  ## a heading after it, so honouring either would swallow every prose line that follows.
  ##
  ## The indented example is the half that was live: this repo writes most of its examples
  ## that way, fenced_lines() cannot see the form, and the fenced case alone stayed green
  ## through a checker that honoured an indented sample as a real marker.
  w("guides/runbook.md", c(
    "# Runbook", "",                                                          # 1, 2
    "> **Orchestrator through the end of this section.**", "",                # 3, 4
    "The rename rule is in `references/beta.md`.", "",                        # 5, 6
    "## A later section", "",                                                 # 7, 8
    "The rename rule is in `references/beta.md`.", "",                        # 9, 10
    "## A marker in a fence", "",                                             # 11, 12
    "```",                                                                    # 13
    "> **Orchestrator through the end of this section.**",                    # 14
    "```", "",                                                                # 15, 16
    "The rename rule is in `references/beta.md`.", "",                        # 17, 18
    "## A marker in an indented block", "",                                   # 19, 20
    "    > **Orchestrator through the end of this section.**", "",            # 21, 22
    "The rename rule is in `references/beta.md`."))                           # 23

  ## Briefs that live outside references/subagents/, where no property of the location says
  ## what the file is. `declared.md` is the correct half: declared, mapped, marked, and its
  ## body pointer is what proves the declaration puts the file *into* the run rather than
  ## merely expecting it. The others are each a way the declaration can be live while the file
  ## is not a brief, and the message has to name which. `declared.md` is addressed by line
  ## number below, so a line added or removed in it repoints the case that names it.
  w("guides/declared.md", c(
    "# Declared runbook", "",                                                   # 1, 2
    "> **Orchestrator:** spawn a subagent (see `references/harness-notes.md`).", # 3
    "> Brief it with: the branch name and this file.", "",                      # 4, 5
    "## Role", "",                                                              # 6, 7
    "The rename rule is in `references/beta.md`, which nobody handed you."))     # 8

  w("guides/unmapped.md", c(
    "# Unmapped runbook", "",
    "> **Orchestrator:** spawn a subagent. Brief it with: this file.",
    "",
    "## Role", "", "Nothing checks this file: the corpus never included it."))

  ## Each shipped name, with a marker the regex cannot see -- the drift this list exists for.
  for (rel in BRIEFS_OUTSIDE_SUBAGENTS) {
    w(rel, c(
      "# Drifted runbook", "",
      "> Orchestrator: spawn one subagent per lens. Brief them with: this file.",
      "",
      "## Role", "", "Nothing here is checked, because nothing saw this file as a brief."))
  }

  ## Every line assertion in the self-test addresses this file by position, so a line added
  ## or removed anywhere above the fence silently repoints the case that names it.
  w("references/alpha.md", c(
    "# Alpha", "",                                                             # 1, 2
    "## The bars", "",                                                         # 3, 4
    "Set `Config/testthat/edition` in DESCRIPTION. A real typo in `README.md`", # 5
    "is a blocker, and the bullet goes in `NEWS.md`.", "",                     # 6, 7
    "The exceptions are the ones the profile's § 3 records by name. The rest",  # 8
    "of § \"The bars\" applies unchanged.", "",                                # 9, 10
    "A gotcha for this package goes in `.workflow/PROFILE.md` § Gotchas.", "", # 11, 12
    "The build model is in [guides/gamma.md](../guides/gamma.md).", "",        # 13, 14
    "The downshift table is in SKILL.md § \"Downshifting\".", "",              # 15, 16
    "The orphan-parameter audit is in the post-execution reviewer's § 4;",      # 17
    "the post-execution reviewer's checklist is not restated here.", "",       # 18, 19
    "Everything else is in § \"Nowhere At All\".", "",                         # 20, 21
    "The rest of the story is in `notes.md`.", "",                             # 22, 23
    "```",                                                                     # 24
    "See [beta](../references/beta.md) for the fenced example.",                # 25
    "Gate summary: nothing but pasted tool output.",                          # 26
    "```", ""))                                                               # 27, 28

  ## Hands demo.md over as a review specification, the way the planning reviewer is handed
  ## the post-execution reviewer's brief -- so demo.md's own Orchestrator block gets read by
  ## an agent it does not address.
  w("references/subagents/other.md", c(
    "# Post-execution reviewer", "",
    "> **Orchestrator:** spawn a subagent (see `references/harness-notes.md`) after the",
    "> gate passes. Brief it with: the branch name, this file, `references/alpha.md`,",
    "> and [demo.md](demo.md) as the review specification, plus `guides/runbook.md`.",
    "",
    "## Role", "", "You read `references/alpha.md`, which you were given."))

  ## Marker variants. `third.md` writes the colon outside the bold; `unread.md` drops the
  ## bold entirely and so is *meant* to stay unrecognised, because that is what the sweep
  ## over references/subagents/ has to be loud about. `nolist.md` has a recognised block
  ## that never says "Brief it with".
  w("references/subagents/third.md", c(
    "# Third reviewer", "",                                                     # 1, 2
    "> **Orchestrator**: spawn a subagent after the gate passes. Brief it with:", # 3
    "> the branch name and this file.", "",                                     # 4, 5
    "## Role", "",                                                              # 6, 7
    "The rename rule is in `references/beta.md`, which nobody handed you."))     # 8

  w("references/subagents/nolist.md", c(
    "# Listless reviewer", "",
    "> **Orchestrator:** spawn a subagent after the gate passes. Hand it the branch name.",
    "",
    "## Role", "", "You have nothing to read but this file."))

  w("references/subagents/unread.md", c(
    "# Unread reviewer", "",
    "> Orchestrator: spawn a subagent. Brief it with: this file.",
    "",
    "## Role", "", "Nothing here is checked, because nothing saw this file as a brief."))

  w("references/subagents/demo.md", c(
    "# Demo reviewer", "",                                                      # 1, 2
    paste("> **Orchestrator:** spawn a subagent (see `references/harness-notes.md`);",
          "the rename rule is in `references/beta.md`.",
          "Brief it with: the branch name, the repo's"),                        # 3
    "> `.workflow/PROFILE.md`, this file, and **`references/alpha.md`**.",       # 4
    ">",                                                                        # 5
    "> Also give it `guides/delta.md`, which the bars defer to.",                # 6
    "",                                                                         # 7
    "> **What a small change may downshift is the table in `SKILL.md`",          # 8
    "> § \"Downshifting\"** -- this brief does not restate it. The build model",  # 9
    "> is in `guides/gamma.md`, which the orchestrator holds.", "",             # 10, 11
    "## Role", "",                                                              # 12, 13
    "You check against `references/alpha.md` -- search it for",                  # 14
    "`Config/testthat/edition`, and read its § \"The bars\" first.", "",        # 15, 16
    "Successive rounds save to `_v2.md`; the bullet goes in `NEWS.md`.", "",    # 17, 18
    "The rename rule is in `beta.md` -- search it for \"the rule\".", "",       # 19, 20
    "How your harness spawns things is in `references/harness-notes.md`.", "",  # 21, 22
    "Read the beta reference before ruling on a rename.", "",                   # 23, 24
    "The beta reference explains what a rename must preserve.", "",             # 25, 26
    "The post-execution reviewer's § 4 covers orphan parameters.", "",          # 27, 28
    "Scope for a rename lives in the beta entry.", "",                          # 29, 30
    "The bars are in `references/alpha.md` § \"No Such Section\", and that",     # 31
    "file also says to search it for \"a string nowhere in alpha\".", "",       # 32, 33
    "Everything else went into the notes reference.", "",                       # 34, 35
    "It is the reviewer's § 2 that nobody here can resolve.", "",               # 36, 37
    "You were also handed `guides/delta.md`, which nobody else is.", "",        # 38, 39
    "Nothing in this paragraph points anywhere at all.", "",                    # 40, 41
    "> **Orchestrator:** on the second spawn, also hand over the build model in", # 42
    "> `guides/gamma.md` -- this brief does not restate it."))                  # 43
  invisible(NULL)
}

self_test <- function() {
  d <- file.path(tempdir(), "check-briefs-selftest")
  unlink(d, recursive = TRUE); dir.create(d, showWarnings = FALSE)
  write_fixture(d)
  ## The fixture's declaration is the shipped one plus the probes above: the correct half, one
  ## whose Reference map row is missing, and one that names a file no longer there.
  r <- run(d, quiet = TRUE,
           declared = c(BRIEFS_OUTSIDE_SUBAGENTS, "guides/declared.md", "guides/unmapped.md",
                        "guides/vanished.md"))
  p <- r$problems

  ## The holes about the sweep itself need a root whose references/subagents/ comes back
  ## empty, and that cannot coexist with the fixture above, so each gets a root of its own
  ## from the same writer. These two go through run(), because what was wrong was never the
  ## listing on its own but that nothing downstream missed what the listing failed to hand
  ## it, and only a whole run puts the message where the exit status reads it.
  sweep_run <- function(name, prepare) {
    dd <- file.path(tempdir(), name)
    unlink(dd, recursive = TRUE); dir.create(dd, showWarnings = FALSE)
    write_fixture(dd)
    prepare(file.path(dd, "references", "subagents"))
    out <- run(dd, quiet = TRUE, declared = BRIEFS_OUTSIDE_SUBAGENTS)
    unlink(dd, recursive = TRUE)
    out
  }
  no_dir <- sweep_run("check-briefs-selftest-nodir",
                      function(sub) unlink(sub, recursive = TRUE))
  bare_dir <- sweep_run("check-briefs-selftest-baredir",
                        function(sub) file.remove(list.files(sub, full.names = TRUE)))

  want <- c(
    "subagents/demo.md:19  points at references/beta.md" =
      "a brief body naming a file its agent was not handed",
    "alpha.md:13  points at guides/gamma.md" =
      "a handed reference file linking to a file the agent was not handed",
    "alpha.md:15  points at SKILL.md" =
      "an unbackticked filename in a handed file",
    "demo.md:21  points at references/harness-notes.md" =
      "the spawn instruction is not a hand-over, so a body pointer at it dangles",
    "demo.md:23  points by periphrasis at references/beta.md" =
      "a file named by periphrasis rather than by filename",
    "alpha.md:17  points at references/subagents/other.md" =
      "a file named by the role that owns it",
    "which is not in it" = "a search-it-for string absent from the file it names",
    "\"No Such Section\", which is no heading" = "a section that does not exist there",
    "\"Nowhere At All\", which names no file this agent holds" =
      "a section naming no file, and no heading here either")
  hit <- vapply(names(want), function(w) any(grepl(w, p, fixed = TRUE)), logical(1))

  ## Each of these covers a way the checker was silently wrong rather than noisy: it reported
  ## success, or the right complaint about the wrong file, over a tree with a live defect.
  fixed <- c(
    "a brief whose Orchestrator marker puts the colon outside the bold is still read" =
      any(grepl("subagents/third.md:8  points at references/beta.md", p, fixed = TRUE)),
    "a file under references/subagents/ that yields no block is named, not dropped" =
      any(grepl("references/subagents/unread.md  yielded no recognised", r$structural,
                fixed = TRUE)),
    "an Orchestrator block that never says \"Brief it with\" is named, not collapsed" =
      any(grepl("references/subagents/nolist.md  no Orchestrator block says", r$structural,
                fixed = TRUE)),
    "either of those fails the run on its own, with no broken pointer needed" =
      length(r$structural) > 0L,
    ## The same guard for a brief that is not under references/subagents/, where nothing about
    ## the file's location makes it one. Driven off the shipped list, so emptying that list --
    ## or dropping a name out of it -- fails here rather than going quiet in the real run.
    "a declared brief outside references/subagents/ whose marker drifted is named" =
      length(BRIEFS_OUTSIDE_SUBAGENTS) > 0L &&
        all(vapply(BRIEFS_OUTSIDE_SUBAGENTS, function(rel)
          any(grepl(paste0(rel, "  yielded no recognised"), r$structural, fixed = TRUE)),
          logical(1))),
    "a declared brief with no Reference map row is named as that, not as a bad marker" =
      any(grepl("guides/unmapped.md  has no row in SKILL.md's", r$structural, fixed = TRUE)),
    "a declared brief that is no longer on disk is named as that, not blamed on the map" =
      any(grepl("guides/vanished.md  is named here as a brief but is not on disk",
                r$structural, fixed = TRUE)),
    "a brief outside that directory is read as one, not merely expected to be one" =
      any(grepl("guides/declared.md:8  points at references/beta.md", p, fixed = TRUE)),
    "a sentence-initial \"The ... reference\" periphrasis, not just the mid-sentence form" =
      any(grepl("demo.md:25  points by periphrasis at references/beta.md", p, fixed = TRUE)),
    "a sentence-initial role possessive, not just the mid-sentence form" =
      any(grepl("demo.md:27  points at references/subagents/other.md", p, fixed = TRUE)),
    "\"the <x> entry\" is a periphrasis too -- leaving it out misattributed a real defect" =
      any(grepl("demo.md:29  points by periphrasis at references/beta.md", p, fixed = TRUE)),
    "a bare filename fitting two files is surfaced as unclear, not skipped in silence" =
      any(grepl("alpha.md:22  cannot tell what \"notes.md\" names", r$unclear, fixed = TRUE)),
    "a periphrasis fitting two files is surfaced too" =
      any(grepl("demo.md:34  cannot tell what \"the notes reference\" names", r$unclear,
                fixed = TRUE)),
    "a role phrase fitting several briefs is surfaced too" =
      any(grepl("demo.md:36  cannot tell what \"the reviewer's §\" names", r$unclear,
                fixed = TRUE)),
    "ambiguity is advisory: it never enters the broken-pointer list" =
      !any(grepl("cannot tell", p, fixed = TRUE)),
    ## The control for the whole point of the heading bound. Without it, nothing here
    ## distinguishes a marker that stops at the next heading from one that runs to EOF, and
    ## a section written later could sit inside an exemption nobody meant to grant it.
    "an Orchestrator section marker stops exempting at the next heading" =
      any(grepl("guides/runbook.md:9  points at references/beta.md", p, fixed = TRUE)),
    "a section marker inside a code fence is an example, and exempts nothing" =
      any(grepl("guides/runbook.md:17  points at references/beta.md", p, fixed = TRUE)),
    ## The other half of that, and the half that was live: this repo writes most of its
    ## examples as indented blocks, a form fenced_lines() cannot see, so an indented sample
    ## of the marker was honoured and exempted every pointer under it.
    "a section marker in an indented block is an example too" =
      any(grepl("guides/runbook.md:23  points at references/beta.md", p, fixed = TRUE)),
    ## Corpus integrity. Each of these was a way the whole run went quiet: the expectation and
    ## the thing expected were derived from the same disk state, so removing the thing removed
    ## the expectation with it and OK printed over the hole.
    "a Reference map row whose file is not on disk is named, not dropped" =
      any(grepl("references/gone.md  has a Reference map row but is not on disk",
                r$structural, fixed = TRUE)),
    "a missing references/subagents/ is named, not read as expecting no brief" =
      any(grepl("references/subagents/  is not a directory", no_dir$structural, fixed = TRUE)),
    "an empty references/subagents/ is named too, and named as the other thing" =
      any(grepl("references/subagents/  holds no .md file", bare_dir$structural,
                fixed = TRUE)) &&
        !any(grepl("is not a directory", bare_dir$structural, fixed = TRUE)),
    ## Asked of expected_briefs() directly, and with nothing else for it to complain about,
    ## because in a whole run the map rows for the files that went with the directory are
    ## also gone and would keep the structural list non-empty on their own. A case that only
    ## asked whether that list was non-empty would stay green with this guard deleted.
    "the sweep failure needs nothing else to be wrong before it appears" =
      any(grepl("references/subagents/  is not a directory",
                expected_briefs(file.path(d, "no-such-root"), corpus = "SKILL.md",
                                briefs = "SKILL.md", declared = character(0)), fixed = TRUE)),
    ## Without this the case above is satisfied by a checker that names the directory and
    ## still lets every brief that was under it leave silently.
    "the briefs that were under it are named as gone from the map as well" =
      all(vapply(c("references/subagents/demo.md", "references/subagents/other.md"),
                 function(rel) any(grepl(paste0(rel, "  has a Reference map row"),
                                         no_dir$structural, fixed = TRUE)), logical(1))),
    ## The arguments. The failure guarded here is a reader running --selftest, reading OK and
    ## exit 0, and concluding the negative control passed -- this file being the control they
    ## never ran. Each case names its own argument: one built from KNOWN_FLAGS would agree
    ## with the implementation whatever either of them said.
    "an argument one hyphen off the flag the header sends readers to is named" =
      any(grepl("Unrecognised argument: --selftest", argument_problems("--selftest"),
                fixed = TRUE)),
    "a path argument is named too, since this checker takes none" =
      any(grepl("Unrecognised argument: SKILL.md", argument_problems("SKILL.md"),
                fixed = TRUE)))

  ## Line greps carry the two spaces that follow the number: a bare "demo.md:3" also matches
  ## demo.md:31, and a fixture that grows past ten lines would quietly stop testing what the
  ## case says it tests.
  ## demo.md is also handed to other.md as a review specification, so a pointer of demo's that
  ## other.md was not given is a true finding for *other* -- scoping to demo's own list is
  ## what makes the separator case ask the question it means to ask.
  demo <- r$by_brief[["references/subagents/demo.md"]]
  clean <- c(
    "an Orchestrator block, read by any agent, addresses the orchestrator" =
      !any(grepl("demo.md:8  ", p, fixed = TRUE)) &&
        !any(grepl("demo.md:9  ", p, fixed = TRUE)) &&
        !any(grepl("demo.md:3  ", p, fixed = TRUE)),
    "a second Orchestrator block in the same file is exempt as well" =
      !any(grepl("demo.md:43  ", p, fixed = TRUE)),
    "a truly blank line inside a block does not end it early" =
      !any(grepl("demo.md:10  ", p, fixed = TRUE)),
    "a file named before \"Brief it with\" on that line is not swept into the set" =
      !any(grepl("references/beta.md:", p, fixed = TRUE)),
    "a file listed after a bare `>` separator is still handed over" =
      !any(grepl("guides/delta.md, which this agent is not given", demo, fixed = TRUE)),
    "a section naming no file is not attributed to the file it sits in" =
      !any(grepl("references/alpha.md § \"Nowhere At All\"", p, fixed = TRUE)),
    "a brief body pointer at a file that is in its set" =
      !any(grepl("points at references/alpha.md, which", p, fixed = TRUE)),
    "a search-it-for whose string really is in the file it names" =
      !any(grepl("Config/testthat/edition", p, fixed = TRUE)),
    "a section reference that resolves in a handed file" =
      !any(grepl("\"The bars\"", p, fixed = TRUE)),
    "a filename belonging to the package under review, not to the skill" =
      !any(grepl("NEWS.md", p, fixed = TRUE)) && !any(grepl("_v2.md", p, fixed = TRUE)) &&
        !any(grepl("PROFILE.md", p, fixed = TRUE)),
    "a repo-root doc whose name also names a file in that package" =
      !any(grepl("README.md", p, fixed = TRUE)),
    "a numbered section of the repo's own profile" =
      !any(grepl("alpha.md:8  ", p, fixed = TRUE)),
    "a named section of a file the skill does not own" =
      !any(grepl("alpha.md:11  ", p, fixed = TRUE)),
    "a role named without a section, which addresses nothing" =
      !any(grepl("alpha.md:18  ", p, fixed = TRUE)),
    "a bare filename that fits more than one file in the corpus" =
      !any(grepl("alpha.md:22  ", p, fixed = TRUE)),
    "a pointer inside a code fence" =
      !any(grepl("alpha.md:25  ", p, fixed = TRUE)),
    "a brief whose own text points only at files it hands over" =
      !any(grepl("subagents/other.md:", p, fixed = TRUE)),
    "a pointer under an Orchestrator section marker, before the next heading" =
      !any(grepl("guides/runbook.md:5  ", p, fixed = TRUE)),
    "a section marker as evidence that the file carrying it is a brief" =
      !("guides/runbook.md" %in% names(r$by_brief)),
    ## The control against the broader sweep this guard was weighed against: runbook.md holds
    ## a blockquote saying "Orchestrator", and is not a brief. Expecting it to be one gates the
    ## whole run on a file whose only defect is a phrase.
    "a corpus file with an orchestrator blockquote, which no rule declares a brief" =
      !any(grepl("guides/runbook.md", r$structural, fixed = TRUE)),
    "an ordinary corpus file, which nothing declares a brief either" =
      !any(grepl("guides/gamma.md", r$structural, fixed = TRUE)) &&
        !any(grepl("references/beta.md", r$structural, fixed = TRUE)),
    ## The other half of the corpus-integrity cases: a map row is evidence of a hole only
    ## when its file is absent, and a directory listing only when it comes back empty.
    "a Reference map row whose file is on disk is not named as gone" =
      !any(vapply(c("references/alpha.md", "guides/runbook.md"), function(rel)
        any(grepl(paste0(rel, "  has a Reference map row"), r$structural, fixed = TRUE)),
        logical(1))),
    ## The ordering the message text already promised: a declared name that is off disk has
    ## no corpus row either, and blaming the map for it sends the reader to the wrong file.
    "a declared brief that is off disk and unmapped is not blamed on the map" =
      !any(grepl("guides/vanished.md  has a Reference map row", r$structural, fixed = TRUE)),
    "a references/subagents/ that holds briefs is not named at all" =
      !any(grepl("references/subagents/  ", r$structural, fixed = TRUE)),
    "the flag this checker does know is not an unrecognised argument" =
      !length(argument_problems("--self-test")) && !length(argument_problems(character(0))))

  cat("self-test: planted every defect class above, plus the constructs that mimic them\n")
  for (w in names(want)) {
    cat(sprintf("  [%s] catches: %s\n", if (hit[[w]]) " ok " else "MISS", want[[w]]))
  }
  for (n in names(fixed)) {
    cat(sprintf("  [%s] reports: %s\n", if (fixed[[n]]) " ok " else "MISS", n))
  }
  for (n in names(clean)) {
    cat(sprintf("  [%s] ignores: %s\n", if (clean[[n]]) " ok " else "FALSE+", n))
  }
  ok <- all(hit) && all(fixed) && all(clean)
  if (!ok) {
    cat("\n  the fixture raised:\n")
    cat(paste0("    ", c(r$structural, p, r$unclear), collapse = "\n"), "\n", sep = "")
  }
  cat(if (ok) "self-test PASSED - the checker detects the defects it claims to.\n"
      else "self-test FAILED - do not trust a clean run from this checker.\n")
  unlink(d, recursive = TRUE)
  ok
}

## ---- main ------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
bad <- argument_problems(args)
if (length(bad)) {
  cat(paste0(bad, collapse = "\n"), "\n", sep = "")
  cat("Usage: Rscript scripts/check-briefs.R\n")
  cat("       Rscript scripts/check-briefs.R --self-test\n")
  quit(status = 1L)
}
if ("--self-test" %in% args) quit(status = if (self_test()) 0L else 1L)

root <- skill_root()
if (!file.exists(file.path(root, "SKILL.md"))) {
  cat(sprintf("Cannot find SKILL.md under %s.\n", root))
  quit(status = 1L)
}
res <- run(root)
quit(status = if (length(res$problems) || length(res$structural)) 1L else 0L)
