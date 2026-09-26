#!/usr/bin/env Rscript

# Checks a repo's completed `.workflow/PROFILE.md` against `templates/PROFILE.md`.
#
# Run from anywhere:  Rscript scripts/check-profile.R <path-to-PROFILE.md>
# Exit status 0 if clean, 1 if anything is broken.
#
# Why this exists: the skill carries the process and each repo's profile carries the
# facts, and the gate criteria in references/cran-gate.md and references/execplan.md
# route agents to profile fields *by name* — "the profile's § 3 accepted exceptions list".
# The template supplies the other half of that name: it labels the field **Recorded
# baseline exceptions** and says in the same breath that the label and the criteria's
# phrase are one name, so a grep for either lands on it. That is why the label is required
# here even though no criterion writes it — it is the template's promise, not the
# criteria's wording. Profiles derived by hand have silently dropped both, which leaves
# every criterion that quotes them unfalsifiable, and nothing detected it. This is the
# cause-level check.
#
# Design: every requirement is parsed out of templates/PROFILE.md at run time —
# sections, bolded field labels, switch enumerations, placeholder slots, and the
# phrases the template itself declares greppable. Nothing about a profile's shape is
# written down here. A hardcoded list would be a second copy of the template that
# goes stale the moment the template changes, which is the exact defect this repo
# exists to prevent. The template is located relative to this script's own path, so
# the checker behaves the same from any working directory.
#
# A field the profile writes plain rather than bolded is ADVISORY and never affects exit
# status: the gate criteria grep for the field *name*, which is there either way, so the
# bolding is a house style worth mentioning and not a broken contract. Nothing else in the
# output is advisory, and the failure list is the whole obligation.
#
# Run the negative control first: Rscript scripts/check-profile.R --self-test
# It derives a filled profile from the template, confirms that passes clean, then
# plants one of each defect class and confirms each is caught. A checker with only a
# positive control is satisfied by flagging everything; one shipped here already
# reported a clean tree that was not.

## ---- locating the template -------------------------------------------------
script_path <- function() {
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grepl("^--file=", a)])
  if (length(f)) normalizePath(f[1], mustWork = FALSE) else ""
}

template_path <- function() {
  s <- script_path()
  if (!nzchar(s)) return("templates/PROFILE.md")
  file.path(dirname(dirname(s)), "templates", "PROFILE.md")
}

read_md <- function(path) {
  x <- readLines(path, warn = FALSE, encoding = "UTF-8")
  Encoding(x) <- "UTF-8"
  x
}

## ---- markdown shredding ----------------------------------------------------
## The [switch] marker is nested bold, which breaks naive bold parsing, so it is
## removed before any label is read and remembered separately.
SWITCH_RE <- "\\*\\*\\[switch\\]\\*\\*"
drop_switch_tag <- function(lines) gsub(SWITCH_RE, "", lines, perl = TRUE)

LABEL_RE <- "^[[:space:]]*(?:[-*+][[:space:]]+|[0-9]+\\.[[:space:]]+)?\\*\\*(.+?)\\*\\*"

## A bold span opening a line, plus whatever follows it on that line.
parse_label <- function(line) {
  m <- regexpr(LABEL_RE, line, perl = TRUE)
  if (m[1] == -1L) return(NULL)
  n <- attr(m, "match.length")
  whole <- substr(line, 1L, n)
  list(label = sub("^.*?\\*\\*(.+?)\\*\\*$", "\\1", whole, perl = TRUE),
       rest = substring(line, n + 1L))
}

## The same field written without bold. What the gate criteria rely on is the field
## *name*, which a grep finds whether or not it is bolded, so a plain `Name: value`
## or `Name. prose` line satisfies the contract just as the template's bolded form
## does. Only the leading phrase is taken, so a value that happens to contain another
## field's word cannot satisfy it; backticks, brackets and parentheses end the scan
## because a line opening with code or a placeholder is not a field name.
##
## Two constraints keep ordinary prose from impersonating a field, which would be far
## worse than a false positive because it would silently satisfy a requirement: the
## line has to open a block or be a list item, the way every label in the template
## does, and the name itself has to be comma-free. Without them a sentence running on
## from the line above ("...with / one recorded exception, below.") reads as the very
## field whose absence is the reason this script exists.
PLAIN_RE <- paste0("^[[:space:]]{0,3}(?:[-*+][[:space:]]+|[0-9]+\\.[[:space:]]+)?",
                   "([^:.`<>()]{1,60})[:.]")

parse_plain_label <- function(line, opens_block) {
  if (!opens_block || grepl("^#{1,6}[[:space:]]", line)) return(NULL)
  m <- regexpr(PLAIN_RE, line, perl = TRUE)
  if (m[1] == -1L) return(NULL)
  n <- attr(m, "match.length")
  lab <- sub("[:.]$", "", substr(line, 1L, n))
  lab <- sub("^[[:space:]]{0,3}(?:[-*+][[:space:]]+|[0-9]+\\.[[:space:]]+)?", "", lab)
  lab <- trimws(gsub("\\*", "", lab))
  if (grepl("[,;]", lab) || !grepl("^[[:alnum:]]", lab)) return(NULL)
  list(label = lab, rest = substring(line, n + 1L))
}

## The template writes fields two ways — `- **Name:** value` and `**Name.** prose` —
## so a trailing colon or period is what separates a *name* from ordinary bold
## emphasis. A semicolon means the span is a sentence, i.e. prose.
is_field_label <- function(txt) {
  lab <- trimws(gsub("`", "", txt))
  !grepl(";", lab, fixed = TRUE) && grepl("[:.]$", lab)
}

bold_spans <- function(lines, offset = 0L) {
  out <- list()
  for (i in seq_along(lines)) {
    m <- gregexpr("\\*\\*(.+?)\\*\\*", lines[i], perl = TRUE)[[1]]
    if (m[1] == -1L) next
    st <- as.integer(m); ln <- attr(m, "match.length")
    for (k in seq_along(st)) {
      s <- substr(lines[i], st[k], st[k] + ln[k] - 1L)
      out[[length(out) + 1L]] <- list(line = i + offset,
                                      text = gsub("^\\*\\*|\\*\\*$", "", s))
    }
  }
  out
}

headings <- function(lines) {
  idx <- grep("^#{1,6}[[:space:]]+", lines)
  data.frame(line = idx,
             level = nchar(sub("^(#+).*$", "\\1", lines[idx])),
             text = trimws(sub("^#{1,6}[[:space:]]+", "", lines[idx])),
             stringsAsFactors = FALSE)
}

## Numbered `## N. Title` sections. A profile may legitimately retitle one, so the
## number is the identity and the title is only carried for the message.
sections <- function(lines) {
  idx <- grep("^##[[:space:]]+[0-9]+\\.", lines)
  if (!length(idx)) {
    return(data.frame(num = integer(0), title = character(0),
                      start = integer(0), end = integer(0),
                      stringsAsFactors = FALSE))
  }
  all_h2 <- grep("^##[[:space:]]+", lines)
  ends <- vapply(idx, function(s) {
    nxt <- all_h2[all_h2 > s]
    if (length(nxt)) nxt[1] - 1L else length(lines)
  }, integer(1))
  data.frame(num = as.integer(sub("^##[[:space:]]+([0-9]+)\\..*$", "\\1", lines[idx])),
             title = trimws(sub("^##[[:space:]]+[0-9]+\\.[[:space:]]*", "", lines[idx])),
             start = idx, end = ends, stringsAsFactors = FALSE)
}

## Everything from a label up to the next label, bullet or heading. Only used to
## answer "is there anything here at all", so swallowing a trailing paragraph is fine.
value_region <- function(lines, i, rest) {
  out <- rest
  j <- i + 1L
  while (j <= length(lines)) {
    l <- lines[j]
    if (grepl("^#{1,6}[[:space:]]", l)) break
    if (grepl("^[[:space:]]*[-*+][[:space:]]", l)) break
    if (!is.null(parse_label(l))) break
    out <- c(out, l)
    j <- j + 1L
  }
  out
}

is_blank_value <- function(v) {
  s <- paste(v, collapse = " ")
  !nzchar(trimws(gsub("[*_:`~—–-]", "", s)))
}

## ---- label matching --------------------------------------------------------
## A profile that renames a field breaks the criteria that grep for it, so the
## label text is the contract. Matching still stems and drops filler so that
## incidental wording ("Timings — measured 2026-08-15") still counts as the field.
STOPWORDS <- c("the", "a", "an", "and", "or", "of", "to", "in", "for", "on", "at",
               "by", "with", "that", "this", "it", "its", "is", "are", "be", "do",
               "not", "must", "every", "all", "them", "from", "as", "if", "each",
               "any", "say", "which", "use", "under", "here", "than", "more")

## The stem width truncates every word to a common prefix, so that inflection does not decide
## whether a field was named: the skill writes "the exceptions the profile records" for
## **Recorded baseline exceptions** and "the smoke snippet" for **Smoke snippets**. Both sides
## of it are live. Too short and distinct label words merge -- at 3, `Matrix` is satisfied by
## "matching" and `Imports` by "implementations", so a heading naming one field satisfies a
## different one. Too long and ordinary inflection stops reaching its own field -- at 7
## "records" no longer reaches `Recorded`, and at 8 "snippet" no longer reaches `Smoke
## snippets`, which check-fields.R's self-test catches as a real mention read as an orphan.
## 6 sits inside that band rather than at either edge: a sanity stop, not a tuned value.
## Nothing recoverable says why 6 rather than 5, and neither edge is near enough to guess.
tokens <- function(txt) {
  t <- tolower(gsub("`", " ", txt))
  t <- unlist(strsplit(t, "[^a-z0-9]+"))
  t <- t[nchar(t) > 1 & !t %in% STOPWORDS]
  unique(substr(t, 1L, 6L))
}

## How much of a label has to be present before the label counts as named. This one *is*
## tuned, and the band is narrow: every value that works lies above a half and no higher than
## two thirds, and both edges bite immediately. At a half the ceiling lets either word of a
## two-word label stand for the whole, and check-fields.R's self-test then reads a field named
## nowhere but inside a code fence as named -- an orphan going unreported, which is the class
## that checker exists for. Past two thirds a three-word label needs every word, and
## **Known-flaky jobs**, which the skill names as "a known-flaky job (the profile lists
## them)", is reported as an orphan against this repo's own tree: a clean run failing. 0.6 is
## the round value inside the band. max(1L, ...) keeps a one-word label askable at all.
covers <- function(need, have) {
  if (!length(need)) return(TRUE)
  sum(need %in% have) >= max(1L, ceiling(0.6 * length(need)))
}

## ---- code context ----------------------------------------------------------
## Fenced blocks and 4-space-indented blocks are both code. The template puts gate
## commands in indented blocks, so a rule that only knew about fences would read
## `gh pr checks <n> --json name` as an unfilled slot.
code_lines <- function(lines) {
  open <- FALSE
  vapply(lines, function(l) {
    if (grepl("^[[:space:]]*(```|~~~)", l)) { open <<- !open; return(TRUE) }
    open || grepl("^(\t| {4,})[^[:space:]]", l)
  }, logical(1), USE.NAMES = FALSE)
}

## ---- placeholder slots -----------------------------------------------------
## `<...>` is an unfilled slot only when it stands alone in its context. Glued into
## an identifier (`.EXPECTED_SLOTS_<CLASS>`), or sharing a code span or a code line
## with anything else (`# <pkg> <version> (development version)`,
## `gh pr checks <n> --watch`), it is a metavariable in a convention or a command,
## which a completed profile may legitimately quote. The same token is both in the
## template — `<n>` is a metavariable at the status command and a fill-in slot under
## the baseline counts — so context, not the token, has to decide.
GLUE <- "[A-Za-z0-9_./-]"

angle_slots <- function(lines, offset = 0L) {
  code <- code_lines(lines)
  res <- list()
  for (i in seq_along(lines)) {
    l <- lines[i]
    m <- gregexpr("<[^<>]{1,80}>", l, perl = TRUE)[[1]]
    if (m[1] == -1L) next
    cs <- gregexpr("`[^`]*`", l, perl = TRUE)[[1]]
    st <- as.integer(m); ln <- attr(m, "match.length")
    for (k in seq_along(st)) {
      s <- st[k]; e <- s + ln[k] - 1L
      txt <- substr(l, s, e)
      before <- if (s > 1L) substr(l, s - 1L, s - 1L) else " "
      after <- if (e < nchar(l)) substr(l, e + 1L, e + 1L) else " "
      if (grepl(GLUE, before) || grepl(GLUE, after)) next
      if (code[i]) {
        if (trimws(l) != txt) next
      } else if (cs[1] != -1L) {
        css <- as.integer(cs); csl <- attr(cs, "match.length")
        inside <- which(css < s & (css + csl - 1L) > e)
        if (length(inside)) {
          span <- substr(l, css[inside[1]] + 1L, css[inside[1]] + csl[inside[1]] - 2L)
          if (trimws(span) != txt) next
        }
      }
      res[[length(res) + 1L]] <- list(line = i + offset, text = txt)
    }
  }
  res
}

## ---- switch fields ---------------------------------------------------------
## Legal values come out of the template's own enumeration: either a list of
## `- **`value`**` items, or the backticked alternatives in the block that opens the
## subsection. Nothing about which values are legal is written down here.
switch_values <- function(body) {
  v <- character(0)
  for (l in body) {
    p <- parse_label(l)
    if (is.null(p)) next
    lab <- trimws(p$label)
    if (grepl("^`[^`]+`$", lab)) v <- c(v, gsub("`", "", lab))
  }
  if (length(v) >= 2L) return(unique(v))

  nz <- which(nzchar(trimws(body)))
  if (!length(nz)) return(character(0))
  start <- nz[1]
  blank <- which(!nzchar(trimws(body)))
  blank <- blank[blank > start]
  stop <- if (length(blank)) blank[1] - 1L else length(body)
  blk <- body[start:stop]
  alt <- blk[grepl("`[^`]+`[[:space:]]*/[[:space:]]*`[^`]+`", blk, perl = TRUE)]
  if (length(alt)) blk <- alt[1]
  toks <- gsub("`", "", unlist(regmatches(blk, gregexpr("`[^`]+`", blk, perl = TRUE))))
  unique(toks[grepl("^[A-Za-z][A-Za-z0-9_+-]*$", toks)])
}

heading_block <- function(lines, h, i) {
  start <- h$line[i] + 1L
  nxt <- h$line[h$line > h$line[i] & h$level <= h$level[i]]
  end <- if (length(nxt)) nxt[1] - 1L else length(lines)
  if (start > end) character(0) else lines[start:end]
}

parse_switches <- function(lines) {
  raw <- lines
  clean <- drop_switch_tag(lines)
  h <- headings(clean)
  out <- list()
  for (i in seq_len(nrow(h))) {
    if (!grepl(SWITCH_RE, raw[h$line[i]], perl = TRUE)) next
    body <- heading_block(clean, h, i)
    out[[length(out) + 1L]] <- list(name = h$text[i], values = switch_values(body))
  }
  out
}

## ---- greppable contract phrases --------------------------------------------
## Where the template says a grep for a *term* or *name* must land on a field, that
## term is itself part of the contract and has to survive into the profile verbatim.
## Both cues are required: a paragraph that only says "grep it" is telling the reader
## how to find something in the repo, not naming a term the criteria search for.
paragraphs <- function(lines) {
  nz <- nzchar(trimws(lines))
  out <- list(); i <- 1L
  while (i <= length(lines)) {
    if (!nz[i]) { i <- i + 1L; next }
    j <- i
    while (j < length(lines) && nz[j + 1L]) j <- j + 1L
    out[[length(out) + 1L]] <- list(start = i, end = j)
    i <- j + 1L
  }
  out
}

grep_phrases <- function(lines) {
  clean <- drop_switch_tag(lines)
  out <- character(0)
  for (p in paragraphs(clean)) {
    blk <- clean[p$start:p$end]
    if (!any(grepl("grep", blk, fixed = TRUE))) next
    if (!any(grepl("\\b(term|name)s?\\b", blk, perl = TRUE))) next
    for (b in bold_spans(blk)) {
      if (!is.null(parse_label(blk[b$line])) &&
          identical(parse_label(blk[b$line])$label, b$text)) next
      if (length(strsplit(trimws(b$text), "[[:space:]]+")[[1]]) > 5L) next
      out <- c(out, trimws(gsub("[*`]", "", b$text)))
    }
  }
  unique(out)
}

## ---- template requirements -------------------------------------------------
parse_template <- function(path) {
  raw <- read_md(path)
  lines <- drop_switch_tag(raw)
  secs <- sections(lines)
  sw <- parse_switches(raw)
  legal_all <- unique(unlist(lapply(sw, `[[`, "values")))

  fields <- list()
  for (s in seq_len(nrow(secs))) {
    rng <- secs$start[s]:secs$end[s]
    body <- lines[rng]
    ## "Pick one and delete the other" makes the paragraph-level names of that
    ## section alternatives, so requiring all of them would flag a correct profile.
    pick_one <- any(grepl("^Pick one", trimws(body)))
    for (k in seq_along(rng)) {
      i <- rng[k]
      p <- parse_label(lines[i])
      if (is.null(p) || !is_field_label(p$label)) next
      lab <- trimws(gsub("`", "", p$label))
      if (grepl("^if[[:space:]]", tolower(lab))) next
      val <- value_region(lines, i, p$rest)
      if (any(grepl("Delete if", val, fixed = TRUE))) next
      bulleted <- grepl("^[[:space:]]*[-*+][[:space:]]", lines[i])
      fields[[length(fields) + 1L]] <- list(
        label = sub("[:.]$", "", lab), section = secs$num[s],
        group = if (pick_one && !bulleted) paste0("alt-", secs$num[s]) else NA_character_
      )
    }
  }

  list(sections = secs, fields = fields, switches = sw,
       placeholders = unique(vapply(angle_slots(lines), `[[`, "", "text")),
       legal_values = legal_all, phrases = grep_phrases(raw))
}

## ---- the check -------------------------------------------------------------
check_profile <- function(path, tpl) {
  raw <- read_md(path)
  lines <- drop_switch_tag(raw)
  secs <- sections(lines)
  h <- headings(lines)

  problems <- character(0)
  advisory <- character(0)
  add <- function(ln, msg) {
    problems <<- c(problems, sprintf("%s:%d  %s", path, ln, msg))
  }
  note <- function(ln, msg) {
    advisory <<- c(advisory, sprintf("%s:%d  %s", path, ln, msg))
  }

  ## Where a missing thing should have gone: the next higher-numbered section.
  insertion_line <- function(num) {
    later <- secs$start[secs$num > num]
    if (length(later)) min(later) else length(lines)
  }

  ## 1. sections present in the template and absent from the profile
  for (s in seq_len(nrow(tpl$sections))) {
    num <- tpl$sections$num[s]
    if (num %in% secs$num) next
    add(insertion_line(num),
        sprintf("missing section: ## %d. %s", num, tpl$sections$title[s]))
  }

  ## 2. named fields
  ## Bolded spans and headings first, plain `Name:` lines last, so that a profile
  ## which bolds the field is never reported as having merely written it plain.
  code <- code_lines(lines)
  section_labels <- function(num) {
    r <- which(secs$num == num)
    if (!length(r)) return(NULL)
    rng <- secs$start[r[1]]:secs$end[r[1]]
    cand <- list()
    for (b in bold_spans(lines[rng], offset = secs$start[r[1]] - 1L)) {
      p <- parse_label(lines[b$line])
      rest <- if (!is.null(p) && identical(p$label, b$text)) p$rest else NA_character_
      cand[[length(cand) + 1L]] <- list(line = b$line, text = b$text,
                                        rest = rest, bold = TRUE)
    }
    hh <- h[h$line %in% rng, , drop = FALSE]
    for (k in seq_len(nrow(hh))) {
      cand[[length(cand) + 1L]] <- list(line = hh$line[k], text = hh$text[k],
                                        rest = NA_character_, bold = TRUE)
    }
    for (i in rng) {
      if (code[i]) next
      opens <- grepl("^[[:space:]]{0,3}(?:[-*+]|[0-9]+\\.)[[:space:]]", lines[i]) ||
        i == 1L || !nzchar(trimws(lines[i - 1L])) ||
        grepl("^#{1,6}[[:space:]]", lines[i - 1L])
      p <- parse_plain_label(lines[i], opens)
      if (is.null(p) || !nzchar(p$label)) next
      cand[[length(cand) + 1L]] <- list(line = i, text = p$label,
                                        rest = p$rest, bold = FALSE)
    }
    cand
  }
  group_hits <- list()
  for (f in tpl$fields) {
    if (!f$section %in% secs$num) next   # already reported as a missing section
    cand <- section_labels(f$section)
    ## A slash in a template label joins alternative names for one field
    ## ("Class validators / expected-slot lists"), so either half satisfies it.
    alts <- trimws(strsplit(f$label, "[[:space:]]+/[[:space:]]+")[[1]])
    needs <- lapply(unique(c(f$label, alts)), tokens)
    needs <- needs[lengths(needs) > 0L]
    hit <- NULL
    for (c in cand) {
      have <- tokens(c$text)
      if (any(vapply(needs, covers, logical(1), have = have))) { hit <- c; break }
    }
    if (!is.na(f$group)) {
      group_hits[[f$group]] <- c(group_hits[[f$group]], !is.null(hit))
      next
    }
    if (is.null(hit)) {
      add(secs$start[which(secs$num == f$section)[1]],
          sprintf("missing named field: **%s** (template section %d)",
                  f$label, f$section))
      next
    }
    if (!hit$bold) {
      note(hit$line, sprintf("named field is present but not bolded: %s", f$label))
    }
    ## A heading or an inline match carries its value inside the label itself.
    if (is.na(hit$rest)) next
    if (is_blank_value(value_region(lines, hit$line, hit$rest))) {
      add(hit$line, sprintf("named field is present but empty: **%s**", f$label))
    }
  }
  for (g in names(group_hits)) {
    if (any(group_hits[[g]])) next
    num <- as.integer(sub("^alt-", "", g))
    add(secs$start[which(secs$num == num)[1]],
        sprintf("section %d states none of the template's alternatives", num))
  }

  ## The names the gate criteria grep for.
  for (ph in tpl$phrases) {
    if (any(grepl(ph, lines, fixed = TRUE))) next
    add(1L, sprintf("contract phrase the gate criteria grep for is absent: \"%s\"", ph))
  }

  ## 3. unfilled placeholders
  for (sl in angle_slots(lines)) {
    if (!sl$text %in% tpl$placeholders) next
    ## A slot naming a legal switch value is the template's own way of writing a
    ## correct answer, e.g. an empty accepted exceptions list.
    if (gsub("[<>]", "", sl$text) %in% tpl$legal_values) next
    add(sl$line, sprintf("unfilled template placeholder: %s", sl$text))
  }

  ## 4. switch fields
  for (sw in tpl$switches) {
    need <- tokens(sw$name)
    row <- NULL
    for (k in seq_len(nrow(h))) {
      if (covers(need, tokens(h$text[k]))) { row <- k; break }
    }
    if (is.null(row)) {
      lab <- NULL
      for (b in bold_spans(lines)) if (covers(need, tokens(b$text))) { lab <- b; break }
      if (is.null(lab)) {
        add(1L, sprintf("switch field is absent: %s", sw$name))
      }
      next
    }
    if (!length(sw$values)) next   # no enumeration to police; presence is enough
    body <- heading_block(lines, h, row)
    blob <- paste(body, collapse = "\n")
    seen <- sw$values[vapply(sw$values, function(v) {
      grepl(paste0("(?<![A-Za-z0-9_-])", v, "(?![A-Za-z0-9_-])"), blob, perl = TRUE)
    }, logical(1))]
    if (!length(seen)) {
      add(h$line[row], sprintf("switch field %s declares no legal value; expected one of %s",
                               sw$name, paste(sw$values, collapse = ", ")))
    }
    for (l in seq_along(body)) {
      p <- parse_label(body[l])
      if (is.null(p)) next
      lab <- trimws(p$label)
      if (!grepl("^`[^`]+`$", lab)) next
      v <- gsub("`", "", lab)
      if (v %in% sw$values) next
      add(h$line[row] + l,
          sprintf("switch field %s: illegal value `%s`; expected one of %s",
                  sw$name, v, paste(sw$values, collapse = ", ")))
    }
  }

  list(problems = problems, advisory = advisory)
}

run <- function(path, tpl, quiet = FALSE) {
  r <- check_profile(path, tpl)
  if (!quiet) {
    if (length(r$problems)) {
      cat(paste0("  ", r$problems, collapse = "\n"), "\n", sep = "")
      cat("\nBROKEN: the profile does not satisfy the template.\n")
    } else {
      cat(sprintf("OK: %s satisfies every requirement derived from the template.\n", path))
    }
    if (length(r$advisory)) {
      cat("\nADVISORY (human judgement required; does not affect exit status)\n")
      cat("  The field is here and the criteria that grep for its name will find it, so\n")
      cat("  none of this is a broken contract. Read each one before acting on it.\n")
      cat(paste0("  ", r$advisory, collapse = "\n"), "\n", sep = "")
    }
  }
  r
}

## ---- negative control ------------------------------------------------------
## The clean fixture is derived from the template rather than typed, so it cannot
## drift away from the requirements the checker derives from that same file.
fill_slots <- function(lines) {
  for (sl in angle_slots(lines)) {
    lines[sl$line] <- gsub(sl$text, "recorded", lines[sl$line], fixed = TRUE)
  }
  lines
}

drop_block <- function(lines, at, stop_re) {
  j <- at + 1L
  while (j <= length(lines) && !grepl(stop_re, lines[j], perl = TRUE)) j <- j + 1L
  lines[-(at:(j - 1L))]
}

## Every fixture edit below addresses the template by a literal pattern, and `sub()` on a
## pattern that no longer matches is a silent no-op: the fixture stops being mutated, and the
## case watching that mutation goes green by construction rather than by working. The line
## that filled `**Known-benign output:` did exactly this the day that field was deleted from
## the template -- the case named after it stayed green under every mutation of the rule it
## names, which is the check-docs.R "# A" failure one directory over. A template this file
## deliberately reads at run time can drop any of these at any time, so no pattern here may
## be allowed to stop biting quietly.
##
## So each edit is named for the construct it plants and records whether it actually changed
## anything, and self_test() refuses to interpret its own result while any of them did not.
##
## What this does not cover: an edit that still matches but no longer means what its case
## says -- a field renamed to a different concept that keeps a matching prefix -- and a case
## whose grep string can never appear for some reason outside the fixture. Only silence on
## the fixture side is made audible.
EDITS <- new.env(parent = emptyenv())

fx <- function(x, what, pat, repl, fixed = FALSE) {
  y <- sub(pat, repl, x, fixed = fixed)
  EDITS[[what]] <- !identical(y, x)
  y
}

## The line the caller goes on to cut or append at, or NA when the anchor is gone.
fx_at <- function(x, what, pat) {
  i <- grep(pat, x)
  EDITS[[what]] <- length(i) > 0L
  if (length(i)) i[1] else NA_integer_
}

good_profile <- function(tpl_lines) {
  x <- fill_slots(tpl_lines)
  ## Legitimately optional: the timings paragraph and the build-model alternative
  ## this repo did not pick, and the distribution channels that do not apply. What
  ## remains of section 2 is the plain, period-closed label that opens it.
  i <- fx_at(x, "an optional build-model alternative the repo did not pick", "^\\*\\*Timings")
  if (!is.na(i)) x <- drop_block(x, i, "^## ")
  i <- fx_at(x, "a distribution bullet that does not apply", "^- \\*\\*If Bioconductor:")
  if (!is.na(i)) x <- drop_block(x, i, "^([-*+] |#)")
  x <- fx(x, "a section retitled but still numbered",
          "^## 3\\. The gate .*$", "## 3. The per-PR CRAN gate - exact commands")
  ## A field answered the way a real profile answers it -- the template's italic guidance
  ## replaced by an actual value -- sitting in a fixture full of defects. Nothing the run
  ## says may name it.
  x <- fx(x, "a correctly filled field", "^- \\*\\*Verbose output:\\*\\*.*$",
          "- **Verbose output:** `message()` gated on `verbose`; never `cat()`.")
  ## Three ways a real profile names a field that is present. The criteria grep for
  ## the name, which is there in each, so none of them may fail the run.
  x <- fx(x, "a field written plain instead of bolded",
          "^- \\*\\*Status command:\\*\\*.*$", "- Status command: gh pr checks --watch")
  x <- fx(x, "a plain field closed by a period rather than a colon",
          "^\\*\\*Plain devtools package\\.\\*\\* ", "Plain devtools package. ")
  x <- fx(x, "a field named by one half of a slashed template label",
          "^- \\*\\*Class validators / expected-slot lists:\\*\\*", "- **Class validators:**")
  i <- fx_at(x, "an indented command block", "^## 3\\.")
  if (!is.na(i)) {
    x <- append(x, c("", "    gh pr checks <n> --json name --jq '.[].name'",
                     "    git log --since <YYYY-MM-DD> --oneline"),
                after = i)
  }
  c(x, "", "## 14. Repo-specific extras", "",
    "Notes this repo keeps that the template does not ask for.")
}

bad_profile <- function(x) {
  i <- fx_at(x, "a whole section dropped", "^## 10\\.")
  if (!is.na(i)) x <- drop_block(x, i, "^## ")
  ## Both repos that got this wrong dropped the label and the term together.
  x <- fx(x, "the label the gate criteria reach by its other name",
          "^\\*\\*Recorded baseline exceptions\\.\\*\\*.*$",
          "Anything that survived the adoption clean-up is written in the CI log.")
  x <- fx(x, "the phrase the criteria grep for",
          "These are the accepted exceptions list for", "These cover", fixed = TRUE)
  x <- fx(x, "a field left empty",
          "^- \\*\\*Known-flaky jobs:\\*\\*.*$", "- **Known-flaky jobs:**")
  x <- fx(x, "a surviving date slot and a surviving path slot",
          "^- \\*\\*Workflows:\\*\\*.*$",
          "- **Workflows:** `<paths under .github/workflows/>`, added `<YYYY-MM-DD>`.")
  x <- fx(x, "a switch set to a value off the menu", "`team`", "`solo-cowboy`", fixed = TRUE)
  x
}

self_test <- function(tpl_path) {
  tpl <- parse_template(tpl_path)
  d <- file.path(tempdir(), "check-profile-selftest")
  dir.create(d, showWarnings = FALSE)
  gp <- file.path(d, "good.md"); bp <- file.path(d, "bad.md")
  rm(list = ls(EDITS, all.names = TRUE), envir = EDITS)
  g <- good_profile(read_md(tpl_path))
  writeLines(g, gp, useBytes = TRUE)
  b <- bad_profile(g)
  writeLines(b, bp, useBytes = TRUE)

  clean <- run(gp, tpl, quiet = TRUE)
  broke <- run(bp, tpl, quiet = TRUE)
  probs <- broke$problems
  advs <- broke$advisory

  want <- c("missing section: ## 10" = "a whole section dropped",
            "missing named field: **Recorded baseline exceptions**" =
              "the label the template promises a grep for either name lands on",
            "contract phrase" = "the phrase the criteria grep for",
            "present but empty: **Known-flaky jobs**" = "a field left empty",
            "unfilled template placeholder: <YYYY-MM-DD>" = "a surviving date slot",
            "unfilled template placeholder: <paths under .github/workflows/>" =
              "a surviving path slot",
            "illegal value `solo-cowboy`" = "a switch set to a value off the menu")
  hit <- vapply(names(want), function(w) any(grepl(w, probs, fixed = TRUE)), logical(1))

  ## Valid constructs. A checker with only a positive control is satisfied by
  ## flagging everything, so each of these must survive untouched.
  clean_cases <- c(
    "profile derived from the template raises no failure" =
      as.character(!length(clean$problems)),
    "an optional build-model alternative the repo did not pick" =
      as.character(!any(grepl("Generated / literate", probs, fixed = TRUE))),
    "a distribution bullet that does not apply" =
      as.character(!any(grepl("Bioconductor", probs, fixed = TRUE))),
    "a section retitled but still numbered" =
      as.character(!any(grepl("missing section: ## 3", probs, fixed = TRUE))),
    "an extra section the template does not define" =
      as.character(!any(grepl("14", probs, fixed = TRUE))),
    ## Sitting among the defects in the bad fixture, not off in the clean one -- the clean
    ## fixture is already asserted silent as a whole, so a case asked there asks nothing.
    "a correctly filled field" =
      as.character(!any(grepl("Verbose output", probs, fixed = TRUE))),
    "a field written plain instead of bolded" =
      as.character(!any(grepl("Status command", probs, fixed = TRUE)) &&
                     any(grepl("not bolded: Status command", advs, fixed = TRUE))),
    "a field named by one half of a slashed template label" =
      as.character(!any(grepl("Class validators", probs, fixed = TRUE))),
    "a plain field closed by a period rather than a colon" =
      as.character(!any(grepl("section 2 states none", probs, fixed = TRUE))),
    "an angle-bracket metavariable inside a code block" =
      as.character(!any(grepl("unfilled template placeholder",
                              clean$problems, fixed = TRUE))))

  ## Did each construct actually get planted? Read first, because every case below is a
  ## claim about a fixture, and a fixture that was never mutated makes all of them true.
  planted <- unlist(as.list(EDITS, all.names = TRUE))
  planted <- planted[order(names(planted))]

  cat("self-test: planted every defect class above, plus valid constructs\n")
  for (n in names(planted)) {
    cat(sprintf("  [%s] plants: %s\n", if (planted[[n]]) " ok " else "GONE", n))
  }
  for (w in names(want)) {
    cat(sprintf("  [%s] catches: %s\n", if (hit[[w]]) " ok " else "MISS", want[[w]]))
  }
  for (n in names(clean_cases)) {
    ok <- identical(clean_cases[[n]], "TRUE")
    cat(sprintf("  [%s] ignores: %s\n", if (ok) " ok " else "FALSE+", n))
  }
  ok <- all(planted) && all(hit) && all(clean_cases == "TRUE")
  if (!all(planted)) {
    cat("\n  GONE means the template no longer contains what that fixture edit looked for,\n")
    cat("  so the construct was never planted and every case that watches it is green by\n")
    cat("  construction. Repoint the edit in good_profile()/bad_profile() at a field the\n")
    cat("  template still defines; do not delete the case.\n")
  }
  if (!ok && length(clean$problems)) {
    cat("\n  clean fixture raised:\n")
    cat(paste0("    ", clean$problems, collapse = "\n"), "\n", sep = "")
  }
  cat(if (ok) "self-test PASSED - the checker detects the defects it claims to.\n"
      else "self-test FAILED - do not trust a clean run from this checker.\n")
  unlink(d, recursive = TRUE)
  ok
}

## ---- main ------------------------------------------------------------------
## Guarded so this file can be source()d for parse_template() without running or exiting.
## What the template defines has to have exactly one owner: scripts/check-fields.R asks the
## same question of the same parser, and a second copy of it there could enforce a different
## field list than this script requires, which is the drift both scripts exist to catch.
## sys.nframe() is 0 only at the top level of an Rscript invocation; source() adds frames.
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  tpl_path <- template_path()
  if (!file.exists(tpl_path)) {
    cat(sprintf("Cannot find the template at %s.\n", tpl_path))
    quit(status = 1L)
  }

  if ("--self-test" %in% args) quit(status = if (self_test(tpl_path)) 0L else 1L)

  paths <- args[!startsWith(args, "--")]
  if (length(paths) != 1L) {
    cat("Usage: Rscript scripts/check-profile.R <path-to-PROFILE.md>\n")
    cat("       Rscript scripts/check-profile.R --self-test\n")
    quit(status = 1L)
  }
  if (!file.exists(paths[1])) {
    cat(sprintf("No such file: %s\n", paths[1]))
    quit(status = 1L)
  }
  res <- run(paths[1], parse_template(tpl_path))
  quit(status = if (length(res$problems)) 1L else 0L)
}
