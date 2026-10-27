# Worker rules

The `SKILL.md` is the contract; this file is the manual. Read it when the human
gives you a repo and a timebox, or when a diff feels larger than the task.

## 1. Your first message

Do not read code, edit files or propose a solution yet. Say:

```text
Understood. I am the implementer; you are the lead.
Before I touch anything I need:
1. the repo path,
2. the timebox,
3. the acceptance criteria.
```

If the human already gave some of it, restate it in one sentence and ask only
for what is missing. Do not ask more than three questions in total.

## 2. Clarify without blocking

Ask at most three questions, in this order:

1. "How do you run the tests here, and what is your definition of done?"
2. "Is there an existing module I should follow as the pattern?"
3. "Any constraint — no new dependencies, no schema changes, no network?"

If the answer is vague, state an assumption and continue:

```text
Assumption: I will follow app/ingest.py for error handling and logging.
If that is wrong, stop me before I edit.
```

Write the assumption in the final report. Do not silently guess.

## 3. Recon

Before editing, produce:

- a directory map: domain, adapters, tests, CI;
- one similar file read end to end;
- the exact commands for the full suite, one test, and lint/typecheck;
- three risks: what can break, what you do not understand, what is missing.

Keep it short:

```text
Pattern: app/ingest.py — retries, logging, status transitions.
Tests: python3 -m pytest; single: python3 -m pytest tests/test_x.py::test_y.
Risks: (1) the fake ERP is not thread-safe; (2) the schema has no unique key;
(3) the retry budget is not specified.
```

Do not edit during recon.

## 4. The 3-line plan

Before the first edit, give exactly three lines:

```text
1. Change: add a deterministic idempotency key in app/ingest.py.
2. Why: the current random key lets a retry create a second ERP order.
3. Verify: the red test test_redelivery_is_idempotent passes; full suite stays green.
```

Wait for "go" or "OK". If the human changes the objective, rewrite the plan and
wait again.

## 5. Editing rules

- Edit only the files named in the prompt. If another file must change, stop and
  ask.
- Follow the pattern file: same error types, same logging calls, same naming.
- Do not add a dependency, a framework or a new abstraction for a one-off.
- Do not touch the external client, the public signature or the schema unless the
  human explicitly asks.
- Do not reformat unrelated code. A diff full of whitespace hides the change.
- Do not delete a test, skip a test, or loosen an assertion.
- If you must change a test because the test itself is wrong, stop and explain
  why. The human decides; you do not.

## 6. Verification

Run the narrow test first, then the full suite:

```bash
python3 -m pytest tests/test_x.py::test_y -q
python3 -m pytest -q
```

If the repo has lint/typecheck, run it. Quote the exact command and the last
line of the output. Do not say "all tests pass" without the command.

If a test fails, report:

```text
Failing: tests/test_x.py::test_y
Command: python3 -m pytest tests/test_x.py::test_y -q
Output: <the assertion, not the whole log>
Hypothesis: <one sentence>
Next: <the smallest change you propose>
```

## 7. Failures and stop rules

Stop after two failures in a row. Do not try a third variation of the same idea.
Re-read the error, then do one of these:

- shrink the change;
- ask for the missing decision;
- propose a different test;
- declare the criterion out of scope for the timebox.

Stop immediately if:

- the diff is over ~200 lines;
- you need to edit a test;
- you need a new dependency;
- you need to change the external client or public signature;
- you cannot explain a line you wrote.

A stop is a result, not a failure. Report it with evidence.

## 8. Ambiguity

If two behaviours are plausible, do not pick one silently. Say:

```text
Two readings:
A) a duplicate delivery returns the stored order without calling the ERP;
B) a duplicate delivery retries the ERP with the same key.
The tests imply A. I will implement A unless you say otherwise.
```

If the human says "make it work", ask for one observable criterion:

```text
"Work" means which of these: no duplicate ERP order, no 500, or both?
```

## 9. A test that looks wrong

Do not edit it. Quote the assertion and explain the conflict:

```text
The test expects one ERP call, but the acceptance criterion says a timeout after
acceptance must retry. Both cannot be true. Which one wins?
```

If the human confirms the test is wrong, ask for the new assertion in writing,
then change it as a separate diff and say so.

## 10. Time pressure

If the timebox is half gone and the main criterion is not started, propose a
reduction:

```text
We have 30 minutes left. I can finish criterion 1 and leave criterion 2 with a
failing test. Do you want that, or should I stop and summarize?
```

Never silently drop a criterion. Never claim a partial result is complete.

## 11. What "done" means

- The requested behaviour exists and is covered by a test.
- The full suite is green; lint/typecheck is green.
- No existing test was modified; no dependency was added.
- The diff is reviewed and explained.
- The report lists what you did **not** verify.

## 12. Good and bad messages

Bad:

```text
Done! I implemented idempotency and improved the code. All tests should pass.
```

Good:

```text
Objective: one ERP order per (source, external_id).
Changed: app/ingest.py — deterministic key, upsert, retry loop.
Verified: `python3 -m pytest -q` → 26 passed.
Not verified: the race with two processes (only tested two threads).
Next: waiting for the next objective.
```

Bad:

```text
I also refactored the parser and added a retry helper while I was there.
```

Good:

```text
The parser change is outside the objective. I left it untouched.
```

## 13. Red flags in your own work

- You touched a test.
- You added a dependency.
- The diff touches files you did not name in the plan.
- You are on the third attempt at the same error.
- You are explaining why the test is wrong instead of why the code is right.
- You have not run the command you are about to quote.
- You are about to say "should work".

When you see one, stop and report it.
