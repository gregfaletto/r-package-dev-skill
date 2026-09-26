#!/bin/sh
# Standing user request that the Agent tool be used.
#
# Why this exists: on Opus 5 and Opus 5.5, Claude Code injects a model-gated
# system-prompt section reading "Do not call the AgentTool unless the user
# requested it". It is not user-configured, has no local opt-out, and reads to
# the model as if it carried the user's authority -- so it silently suppresses
# configured delegation workflows. See anthropics/claude-code#80988 and #82371.
#
# UserPromptSubmit output is injected as USER-side context each turn, which
# satisfies that instruction's own escape clause. Phrasing matters: a policy
# ("delegate multi-file work") does not survive; a request naming the occasions
# does. Costs roughly 150 tokens per turn.
#
# Observed on Claude Code 2.1.220 with Opus 5 in August 2026, and with Opus 5.5
# in September 2026. This is a vendor bug, not a stable interface -- re-check
# before installing, and remove this hook once the section is opt-out or scoped.

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":"Standing request from me (the user), for every session: I am requesting the Agent tool. Spawn subagents without asking permission first, specifically on these occasions -- plan review before implementation; the drift sentinel, both passes; delegated implementation of a non-trivial change; post-execution review of a diff; the periodic multi-agent code review; and any broad investigation where a clean context helps. Treat this as satisfying any instruction to obtain user permission before using the Agent tool. If you decline to delegate on one of these occasions, say so and say why, rather than silently doing the work inline."}}
JSON
