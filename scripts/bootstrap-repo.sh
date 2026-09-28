#!/usr/bin/env bash
# Scaffold the r-package-dev workflow into an R package repo.
#
# Run from the repo root:
#   bash ~/.claude/skills/r-package-dev/scripts/bootstrap-repo.sh
#
# Creates .workflow/ and .plans/, copies the PROFILE template, and adds the
# gitignore + .Rbuildignore entries. Idempotent: never overwrites an existing
# PROFILE.md, never duplicates an ignore line.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f DESCRIPTION && ! -f build.R && ! -d R ]]; then
    echo "ERROR: this does not look like an R package repo root." >&2
    echo "Expected one of: DESCRIPTION, build.R, R/" >&2
    exit 1
fi

mkdir -p .workflow .plans

if [[ -f .workflow/PROFILE.md ]]; then
    echo "kept    .workflow/PROFILE.md (already exists)"
else
    cp "$SKILL_DIR/templates/PROFILE.md" .workflow/PROFILE.md
    echo "created .workflow/PROFILE.md (from template — fill it in)"
fi

# .gitignore entries
add_ignore() {
    local file="$1" line="$2"
    touch "$file"
    if grep -qxF "$line" "$file"; then
        echo "kept    $file: $line"
    else
        # A file with no trailing newline would otherwise get the new entry
        # glued onto its last line, silently breaking BOTH: e.g. `.Rproj.user`
        # + `.workflow/` becomes `.Rproj.user.workflow/`, which ignores neither.
        if [[ -s "$file" && -n "$(tail -c 1 "$file")" ]]; then
            printf '\n' >> "$file"
        fi
        printf '%s\n' "$line" >> "$file"
        echo "added   $file: $line"
    fi
}

add_ignore .gitignore ".workflow/"
add_ignore .gitignore ".plans/"
add_ignore .gitignore ".claude/"

# .Rbuildignore uses regexes; only meaningful for a package built from this root
if [[ -f DESCRIPTION ]]; then
    add_ignore .Rbuildignore '^\.workflow$'
    add_ignore .Rbuildignore '^\.plans$'
    add_ignore .Rbuildignore '^\.claude$'
fi

cat <<'EOF'

Done. Next:

  1. Derive .workflow/PROFILE.md by following references/adoption.md — it has a
     per-field table of the command that produces each answer. Do not guess a
     field that has a command; a wrong profile has caused several of this
     workflow's serious failures.
  2. Confirm the filled profile with the maintainer before relying on it.
  3. Add an AGENTS.md / CLAUDE.md at the repo root pointing at the r-package-dev
     skill and at .workflow/PROFILE.md, and carrying the delegation standing
     request -- see adoption.md, step 2. Not optional: without it every subagent
     check in the skill can silently become self-review.

A global gitignore keeps these directories out of every repo by accident. Check
for an existing one first -- setting core.excludesfile overwrites it silently:

  git config --global --get core.excludesfile   # prints a path? append to that file
  git config --global core.excludesfile ~/.gitignore_global   # only if it printed nothing
  printf '%s\n' .claude/ .workflow/ .plans/ .DS_Store >> ~/.gitignore_global
EOF
