#!/usr/bin/env bash
# Symlink this skill into the personal Claude skills directory.
#
#   bash scripts/install.sh            # install/refresh
#   bash scripts/install.sh --check    # report status only
#
# Installs to $AGENT_SKILLS_DIR, defaulting to ~/.claude/skills.
#
# Idempotent: safe to re-run. Refuses to clobber a real directory.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${AGENT_SKILLS_DIR:-$HOME/.claude/skills}"
LINK="$SKILLS_DIR/r-package-dev"

if [[ "${1:-}" == "--check" ]]; then
    if [[ -L "$LINK" ]]; then
        echo "linked: $LINK -> $(readlink "$LINK")"
    elif [[ -e "$LINK" ]]; then
        echo "EXISTS but is not a symlink: $LINK"
    else
        echo "not installed"
    fi
    exit 0
fi

mkdir -p "$SKILLS_DIR"

if [[ -L "$LINK" ]]; then
    current="$(readlink "$LINK")"
    if [[ "$current" == "$REPO_DIR" ]]; then
        echo "Already installed: $LINK -> $REPO_DIR"
        exit 0
    fi
    echo "Repointing existing symlink (was: $current)"
    rm "$LINK"
elif [[ -e "$LINK" ]]; then
    echo "ERROR: $LINK exists and is not a symlink." >&2
    echo "Move or remove it yourself, then re-run. Refusing to delete it." >&2
    exit 1
fi

ln -s "$REPO_DIR" "$LINK"
echo "Installed: $LINK -> $REPO_DIR"
echo
echo "Verify with:  bash scripts/install.sh --check"
