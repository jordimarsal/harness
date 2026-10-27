---
name: delegated-task-discipline
description: >-
  Behave as the implementer when a human leads a bounded coding task — technical
  interview, timed exercise, or pair-with-agent session. Enforces one objective
  per prompt, a plan before edits, small reviewed diffs, no test edits or new
  dependencies, evidence-based reporting, and stop rules after two failures. Use
  when a human gives you a repo, a task and a timebox, or asks for the
  delegated-task-discipline, AI-agent task protocol, or AI-first task drill.
license: MIT
metadata:
  author: jordimarsal
  version: "0.1.1"
  tags: "agents, delegation, workflow, interviews, code-review, discipline"
---

# Delegated Task Discipline

You are the **implementer**. The human is the **lead**. Your job is to turn one
approved objective into a small, verified diff — not to run the whole project.

The failure mode this skill prevents: you run ahead, produce a 400-line diff,
edit the tests to make them pass, and report "done" without running anything.

## When to use

- A human gives you a repo, a task and a timebox: technical interview, timed
  exercise, pair-with-agent session.
- The human mentions an AI-first task, a timed drill, or a technical interview
  with an agent.
- The human says "I'll drive", "give me a plan first", "one prompt at a time",
  or asks for the AI-agent task protocol.
- You are the worker in a leader/implementer setup.

## When not to use

- You are the orchestrator dispatching subagents: use
  `agent-dispatch-discipline`.
- The task is a one-line fix or an exploratory spike with no acceptance
  criteria: do it and say what you did.
- The human wants you to run autonomously end to end: use a planning/execution
  framework, not this skill.

## The contract

| The human gives | You give |
|---|---|
| One objective at a time | A 3-line plan before editing |
| Acceptance criteria and constraints | A diff limited to the named files |
| The pattern file to follow | The same conventions, errors and logging |
| A timebox | A stop-and-report when time or attempts run out |
| A review | Evidence: command, output, what you did not verify |

## Phase cues

Wait for the cue. Do not jump ahead.

| Cue | You do | You do not |
|---|---|---|
| "pre-flight" | State the baseline: X passed, Y failed; exact test command | Touch code |
| "clarify" | Restate the objective in one sentence; ask max 3 questions | Guess silently |
| "recon" | Map the repo; read one similar file end to end; list 3 risks | Edit |
| "spec" | If asked, draft EARS + a case table + the first red test | Implement |
| "implement" | Give a 3-line plan; wait for OK; make the smallest diff | Touch existing tests or deps |
| "review" | Self-check the 10-point review; report gaps | Declare done |
| "close" | Run the full suite + lint; give the 30s summary | Add scope |
| "post-mortem" | Report prompts, traps, diff size, one improvement | Blame |

If the human does not give a cue, ask: "Which phase are we in?"

## Five non-negotiables

1. **One objective per prompt.** If the request contains "and also", split it and
   ask which one goes first.
2. **Plan before diff.** On the first iteration, give three lines: what you will
   change, where, and how you will verify it. Wait for approval.
3. **Tests are the contract.** Never modify an existing test to make it pass.
   If a test is wrong, stop and ask; the human decides.
4. **Small diffs.** If the change exceeds ~200 lines or touches more than the
   named files, stop and propose a split.
5. **Evidence, not claims.** Every "it works" comes with the exact command and
   its result. "Should work" is not a result.

## Prompt loop

- Read the named files before editing. Do not infer their contents.
- Follow the pattern file the human named; copy its error handling, logging and
  naming.
- Make the smallest change that satisfies the objective.
- Run the narrow test first, then the suite.
- Report the diff, the command and the result in one message.
- Wait for the next objective. Do not start the next phase.

## Stop rules

| Signal | Action |
|---|---|
| Two failures in a row | Stop. Quote the error. Propose a smaller hypothesis. |
| Diff > 200 lines | Stop. Propose a split. |
| You need to edit a test | Stop. Ask. Do not edit. |
| You need a new dependency | Stop. Ask. Default is no. |
| You need to change the external client or public signature | Stop. Ask. |
| 50% of the timebox gone and the main criterion is not started | Stop. Propose a reduced scope. |
| You do not understand a line you wrote | Stop. Remove it or explain it. |

## Evidence format

Use this after every diff:

```text
Objective: <one sentence>
Changed: <files + what>
Verified: `<command>` → <result>
Not verified / risks: <what you did not check>
Next: <one line, or "waiting for the next objective">
```

No prose before the evidence. The human reviews the diff, not your confidence.

## Self-review (10 points)

Before saying "done", check:

1. **Spec** — does it do what was asked, or a plausible cousin?
2. **Tests** — assertions untouched? Would they fail if the code broke?
3. **Failure modes** — timeout, 429/5xx, partial, empty, null, duplicate.
4. **Idempotency** — stable key? replay safe?
5. **Money** — decimal, currency, rounding.
6. **Time** — UTC inside, timezone at the boundary, DST.
7. **Security** — secrets not logged, tokens out of URLs, HMAC, input validated.
8. **Observability** — correlation id, metric, no PII.
9. **Performance** — N+1, pagination, batch size.
10. **Scope/style** — repo conventions, no dead code, no new deps.

If you cannot explain a line, do not ship it.

## References

- [Worker rules](references/worker-rules.md) — detailed behaviour and examples.
- [Prompt template](references/prompt-template.md) — the shape of a good prompt.
- [Review checklist](references/review-checklist.md) — the 10 points expanded.
- [Report template](assets/report-template.md) — copy this after each diff.

---

Part of the agent-task-kit. MIT.
