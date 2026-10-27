# Prompt template

The human writes the prompt; the implementer follows it. A good prompt has one
objective, the exact files, the pattern to copy, the constraints, and the
verification.

## Template

```text
Context: <one paragraph: what the service does, where this change fits>
Task: <one objective, imperative>
Files: <exact paths to read and to change>
Pattern: follow <file:line> — same error handling, same logging.
Constraints:
- do not modify tests
- do not modify <external client / public API>
- no new dependencies
- keep the existing function signature
Done when:
- `<test command>` passes, including <specific test names>
- <behavioural criterion>
First: give me a 3-line plan. Then wait for my OK before editing.
```

## Filled example

```text
Context: A Python service ingests storefront order webhooks, stores the order in
SQLite, and pushes it to an ERP. A redelivery currently creates a second ERP
order because the idempotency key is random.

Task: Make redelivery idempotent without changing the public API.

Files: app/ingest.py (change), tests/test_acceptance.py (read only).

Pattern: follow app/ingest.py:120-140 for the retry loop and the logging calls.

Constraints:
- do not modify tests
- do not modify app/erp_client.py
- no new dependencies
- keep `ingest_order(payload, *, conn, erp, ...)`

Done when:
- `python3 -m pytest -q` passes
- `python3 -m pytest tests/test_acceptance.py::test_redelivery_is_idempotent -q` passes
- a second delivery returns the same order id and does not call the ERP again

First: give me a 3-line plan. Then wait for my OK before editing.
```

## Bad prompts

```text
Fix the duplicate order bug and clean up the code.
```

No files, no constraints, no verification. The agent will guess.

```text
Make the tests pass.
```

This invites test edits.

```text
Refactor ingest.py and also add a retry helper.
```

Two objectives. Split it.

## What the implementer should do with a bad prompt

Do not start. Ask for the missing piece:

```text
I can do this, but I need two things before editing:
1. which test proves the fix,
2. whether I may touch only app/ingest.py.
```

If the human does not answer, propose a default and mark it as an assumption.
