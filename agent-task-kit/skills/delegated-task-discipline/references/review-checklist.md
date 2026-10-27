# Review checklist

Run this after the diff, before saying "done". Say what you look at and why. If
you cannot explain a line, do not ship it.

## 1. Spec

- Does the diff implement the requested behaviour, or a plausible cousin?
- Is every acceptance criterion covered?
- Is anything extra included? Extra scope is a defect, not a bonus.

**Red flag:** a new abstraction that the task did not ask for.

## 2. Tests

- Were existing assertions changed? They must not be.
- Would the new test fail if the fix were removed? If not, it is decorative.
- Is the test at the behaviour level, not the implementation level?
- Is there a test for the failure path, not only the happy path?

**Red flag:** a test that asserts a private method or a mock call count with no
behavioural meaning.

## 3. Failure modes

- Timeout after the remote system accepted: is the retry safe?
- 429 / 5xx: retried? with backoff? capped?
- Partial response, empty list, null field, duplicate delivery.
- What happens after the retry budget is exhausted? Is the order parked, lost,
  or silently marked as success?

**Red flag:** `except Exception: pass`.

## 4. Idempotency

- Is the key deterministic or persisted? A random key per attempt is not
  idempotent.
- Does a retry produce the same effect once?
- Does a race between two deliveries create one effect or two?
- Is the uniqueness enforced by the database, not only by application code?

**Red flag:** `SELECT` then `INSERT` with no unique constraint.

## 5. Money

- Decimal, not binary float.
- Currency stored with the amount.
- Rounding rule explicit; no double rounding.
- Taxes and discounts applied in the right order.

**Red flag:** `float` for a monetary amount.

## 6. Time

- UTC inside the system; timezone at the boundary.
- DST transitions handled.
- Timestamps stored with a timezone or a documented convention.
- Idempotency windows and retry windows use the same clock.

**Red flag:** `datetime.now()` without a timezone.

## 7. Security

- Secrets not logged; tokens not in URLs.
- HMAC or signature verified with a constant-time comparison.
- Input validated at the boundary; no raw SQL string concatenation.
- Error messages do not leak stack traces or personal data.

**Red flag:** a token in a log line or a query string.

## 8. Observability

- One log line per state transition, with a correlation id.
- A metric for success, failure and retry.
- No PII in logs.
- The operator can tell what happened to one order from the logs.

**Red flag:** silent retries; no way to count failures.

## 9. Performance

- No N+1 query in a loop.
- Pagination or streaming for large result sets.
- Batch size bounded.
- The new index exists if the query needs it.

**Red flag:** a query inside a loop over the order lines.

## 10. Scope and style

- Follows the repo's naming, error handling and logging.
- No dead code, commented-out code or debug prints.
- No new dependency without an explicit decision.
- The diff is small enough to review in one pass.

**Red flag:** reformatting unrelated files.

## Mutation test (if time)

Break one condition on purpose — invert an `if`, remove a retry, return early.
Run the test. If it still passes, the test is not protecting the behaviour.
Revert the mutation immediately.
