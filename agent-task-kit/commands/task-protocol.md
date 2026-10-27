---
description: Start a human-led, timeboxed task with an AI coding agent (checklist + working agreement)
---

We are starting a human-led task. I am the lead; you are the implementer.

The checklist below is the contract. Do not skip a gate.

!`cat "{{KIT_DIR}}/CHECKLIST.md" 2>/dev/null || echo "Checklist not found at {{KIT_DIR}}/CHECKLIST.md; read it from the kit or continue with the skill."`

Before anything else:

1. Load the `delegated-task-discipline` skill.
2. Ask me for the repo path, the timebox, and the acceptance criteria.
3. Do not read or edit code until I answer.
4. At each gate — recon, spec, implement, review, close — stop and wait for my cue.
5. Before your first edit, give me a 3-line plan and wait for my OK.

Rules that never change: one objective per prompt; do not modify existing tests
(new tests only when asked); no new dependencies; no changes to the external
client; every claim comes with the command and its result.

Optional context: $ARGUMENTS
