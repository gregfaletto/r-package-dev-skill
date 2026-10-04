# Editing this skill

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

The artifact names have their own sweep, because they went wrong in the way described
above. They were prescribed in one file, derived rather than stated in a brief, and written
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

Changes a review proposed and the maintainer set aside are in [`CONSIDERED.md`](CONSIDERED.md),
which says how to add to them. Check it before proposing a change.

`references/harness-notes.md` tells users to copy `scripts/delegation-standing-request.sh` into
`~/.claude/hooks/`, so a change to the script reaches an existing install only when it is
copied again. Say so in the commit message.
