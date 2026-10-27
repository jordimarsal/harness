# Agent task — human checklist

> Operational version: quick path, then commands and prompts per phase.
> Agent skill: `delegated-task-discipline` · Command: `/task-protocol`

**Rule zero:** you are the tech lead; the agent is a fast junior. You own the
decisions and the gates. The agent owns the typing.

## Quick path

| Phase | Output | Gate |
|---|---|---|
| 0 Pre-flight | baseline: X passed / Y failed; starting commit | said out loud |
| 1 Clarify | 3–5 criteria in your words | confirmed |
| 2 Recon | pattern file + 3 risks | written |
| 3 Spec | EARS + case table + red test | fails for the right reason |
| 4 Prompt loop | reviewed diffs; suite green | 0 existing tests modified |
| 5 Review | 10 points, untracked files, mutation | exclusions listed |
| 6 Close | suite + lint + reconcile | 30-second summary |
| 7 Post-mortem | 1 improvement | logged |

## 0 · Pre-flight (5 min)

**Run**

```bash
pwd
git status --short
git log --oneline -5
git rev-parse --short HEAD
```

- [ ] Clean tree. If dirty, note what is pre-existing; do not mix it with your change.
- [ ] Timer + recording; notifications off; font large; camera/mic tested.
- [ ] Agent authenticated; you know how to stop it and how to see its diff.
- [ ] Data policy: *"Any restriction on sending this repo to a hosted model?"*

**Baseline — use the repo's command**

```bash
python3 -m pytest -q                  # full suite
python3 -m pytest path::test -q       # one test
# Node: npm test / pnpm test
# Java: ./mvnw -q test / ./gradlew test
```

- [ ] Baseline: `____ passed, ____ failed`.
- [ ] Single-test command: `________________`.

**Say** — after the command has your repo, timebox and criteria

> "Before anything else: give me the exact commands for the full suite and a single test. Do not edit anything yet; read only what you need to answer."

**Gate:** you can say the baseline out loud.

## 1 · Clarify (5 min)

**Say**

> "Let me restate the acceptance criteria: A, B, C. Is that right?"

**Ask at most three**

> "How do you run the tests here, and what is your definition of done?"
> "Is there an existing module I should follow as the pattern?"
> "Any constraint — no new dependencies, no schema changes, no network?"

- [ ] Write down assumptions; do not block on ambiguity.
- [ ] Agent restates:

> "Restate my criteria in one sentence each, list your assumptions, and ask at most three questions. Do not edit."

**Gate:** 3–5 criteria confirmed aloud.

## 2 · Recon (8–10 min)

**Run**

```bash
git ls-files | head -80
git ls-files | sed 's#/[^/]*$##' | sort -u
cat README.md
cat pyproject.toml 2>/dev/null || cat package.json 2>/dev/null || true
```

- [ ] Read one similar file end to end:

```bash
sed -n '1,240p' path/to/pattern-file
```

- [ ] Exact commands: full suite, single test, lint/typecheck.
- [ ] What "done" means in this repo's CI.
- [ ] Check that the tree stayed clean:

```bash
git status --short
git diff HEAD --stat
```

**Say**

> "There are `N` failing tests. Read the repo, identify the pattern to follow, and map each failure to its root cause. Don't change anything yet. Write `REPO_PATTERN.md` with: layout, pattern file, exact test commands, and 3 risks."

If the suite starts green, replace the first sentence with: *"Read the repo and
identify the pattern for `<feature>`. Don't change anything yet."*

**Gate:** pattern file + 3 risks written.

## 3 · Spec (10–15 min)

**Say — cases**

> "Build `CASES.md` with a case table: case, input, expected result. Cover the cases that apply: happy path, empty, limit, 429/5xx, timeout after accept, duplicate, and race. Don't write code."

**Say — EARS**

> "Read the brief (`BRIEF.md` if present). Format the criteria into EARS: *When …, the system shall …* / *If …, the system shall …*. Give each requirement a stable ID, map it to at least one case, and append the table to `CASES.md`. Flag open decisions; do not assume them."

**Say — red test**

> "Write the failing test for `BEHAVIOUR` first, at the behaviour level. Do not touch `APP_PATH`. Show me the test and the failure output."

**Run**

```bash
python3 -m pytest path::test -q
```

- [ ] It fails for the right reason, not an import error or a typo.
- [ ] Decisions before code: idempotency key, retry policy, states.

**Gate:** criteria + cases + decisions + red test.

## 4 · Prompt loop (18–30 min)

**Say — plan**

> "Give me a 3-line plan: what you will change, where, and how you will verify it. Wait for my OK."

**Implementation prompt — fill this in**

```text
Context: <one paragraph: what the service does, where this change fits>
Task: <one objective, imperative>
Files: <exact paths to read and to change>
Pattern: follow <file:line> — same error handling, same logging.
Constraints:
- do not modify tests
- do not modify <external client / public API>
- no new dependencies
- keep the existing signature
Done when:
- `<test command>` passes, including <test names>
- <behavioural criterion>
First: give me a 3-line plan. Then wait for my OK before editing.
```

**Say — after OK**

> "Approved. Implement only that. Run the narrow test, then the full suite. Report: objective, changed files, command + result, and what you did not verify."

**Run — after every diff**

```bash
git status --short
git diff HEAD --stat
git diff HEAD
git diff --check HEAD
```

- [ ] One objective per prompt. Split "and also".
- [ ] Review the diff before the next prompt.
- [ ] New files are untracked: `git diff HEAD` does not show them. Open each one
      explicitly (`sed -n '1,240p' path/to/new-file`).
- [ ] Diff ≤200 lines; split if bigger.
- [ ] No edits to existing tests (new tests only when asked), no new deps, no
      external client changes.
- [ ] Two failures in a row → stop, read, re-spec.

**Say — review the diff**

> "Explain this diff line by line. Stop at any line you cannot justify."

**If the agent edited an existing test**

```bash
git diff --name-only HEAD -- tests/
git restore path/to/test-file   # destructive: only the modified test
```

> "Do not modify existing tests. Revert that hunk and repeat the change."

If the agent added a **new** test file when you asked for one, review it; do not
restore it. If you did not ask for it, remove only that file after checking
`git status`.

**If the diff is too big**

> "This diff is `N` lines. Stop. Split it into `A` and `B`. Do not edit until I approve the split."

**Say — logging**

> "Add one log line per state transition and one metric per outcome. No PII, no secrets. Follow the repo's logger; if there is no precedent, use the platform standard (SLF4J, stdlib logging, console) and say it is new. Mark the resolved decisions in `CASES.md`. Do not change behaviour."

**Say — failure-path tests**

> "Add tests for the failure paths: timeout after accept, 429, 5xx, exhausted retries, duplicate, race. Keep existing assertions untouched. Show me the commands and results."

**Say — docs**

> "Update the docs in present tense. Restore any pre-existing test files to their original formatting. Do not change behaviour."

**Run — after each change**

```bash
python3 -m pytest path::test -q
python3 -m pytest -q
```

**Gate:** every diff reviewed; suite green; 0 existing tests modified.

## 5 · Review (8–12 min)

**Run**

```bash
git status --short
git diff HEAD --stat
git diff HEAD --numstat
git diff HEAD
git diff --name-only HEAD
python3 -m pytest -v -o addopts=""
```

**Check — in this order**

- [ ] **Spec** — does it do what was asked, or a plausible cousin?
- [ ] **Tests** — assertions untouched? would they catch a break?
- [ ] **Failure modes** — timeout, 429/5xx, partial, empty, null, duplicate.
- [ ] **Idempotency** — stable key? replay safe?
- [ ] **Money** — decimal, currency, rounding.
- [ ] **Time** — UTC inside, timezone at the boundary, DST.
- [ ] **Security** — secrets not logged, tokens out of URLs, HMAC, input validated.
- [ ] **Observability** — correlation id, metric, no PII.
- [ ] **Performance** — N+1, pagination, batch size.
- [ ] **Scope/style** — repo conventions, no dead code, no new deps.
- [ ] **Untracked** — open each new file; `git diff HEAD` does not show it.

**Say**

> "Which requirement does this line satisfy? Which test proves it?"
> "What did you not verify?"
> "What would break this in production?"

**Check — existing tests unchanged**

```bash
git diff --name-only HEAD -- tests/     # empty = no existing test modified
git status --short -- tests/            # new tests: review them
```

The first command must be empty. The second shows new test files as `??`; they
are allowed only if you asked for them. Adjust `tests/` if the repo keeps tests
elsewhere.

**Mutation test — if time**

> "Do not change anything. I will mutate `CONDITION` and run `TEST`. Tell me which test should catch it."

```bash
# human mutates, runs the test, then restores
git restore path/to/file
```

- [ ] The test fails. If it passes, the test is decorative.

**Gate:** checklist done + suite green + deliberate exclusions listed.

## 6 · Close (4–8 min)

**Run**

```bash
python3 -m pytest -q
<lint/typecheck>
git diff --check HEAD
git status --short
git diff HEAD --stat
```

- [ ] Full suite + lint/typecheck green.
- [ ] Reconcile counts and sums with the source; sample 20 records end to end.

**Say**

> "Compare counts and sums with the source system; sample 20 records end to end. If the source is unavailable, say so and list it as residual risk."

**Say — 30-second summary**

> "Give me the 30-second close: what changed, what it does now, how it is verified, residual risk, and what you would add with more time. No new scope."

**Gate:** summary said without reading.

## 7 · Post-mortem (2–5 min, after)

**Say**

> "Write `POSTMORTEM.md`: timeline, root cause, impact, what went well, what did not, action items with owners. Add the review evidence to `REVIEW.md`. Mark unknown numbers as unknown."

**Say — gate script**

> "Create `check.sh`: format check, lint, typecheck, tests; stop at the first failure. Scope the formatter to the files that are actually formatted."

**Say — README**

> "Add `./check.sh` to the README and update the documented commands and counts."

**Say — docs audit**

> "Are any documents outdated? Check counts, commands, cross-references, and the file tree."

**Prompt log — one row per interaction**

```text
| # | Phase | Objective | Prompt (summary) | Diff | Result | What I caught |
|---|---|---|---|---|---|---|
| 1 | Recon | Map the repo; change nothing | "..." | 0 | REPO_PATTERN.md | ... |
```

- [ ] Time per phase; where you got stuck.
- [ ] Prompts used; how many to the first acceptable diff.
- [ ] Traps caught (file:line + review item).
- [ ] Tests added; existing tests modified? Target: 0.
- [ ] Final diff size.
- [ ] One change for next time.

## Git moves

```bash
git status --short
git diff HEAD --stat
git diff HEAD
git diff --check HEAD
git diff --name-only HEAD
git status --short -- tests/
git log --oneline -3
git show --stat HEAD
```

Safe undo:

```bash
git restore path/to/file        # discard changes in one file (destructive)
git restore path/to/test-file   # discard edits to one existing test (destructive)
git stash push -u -m "wip"      # park changes
```

- If the agent committed without asking:

```bash
git log --oneline -3
git show --stat HEAD
git reset --soft HEAD~1     # uncommit, keep changes
```

- Never `git reset --hard` or `git checkout .` during the interview.
- `git restore` is destructive: confirm the path only contains agent changes.
- `git restore` only affects tracked files; new test files stay behind. Remove
  them explicitly only if you did not ask for them.
- If the tree was dirty at the start, do not restore the whole path; you will
  lose your own work.

## Commit (only if the format asks)

```bash
git add -p
git diff --cached
git commit -m "fix: describe the change"
git log --oneline -3
git show --stat HEAD
```

- [ ] One logical change per commit; the message says what changed, not "wip".
- [ ] `git diff --cached` is the review gate; do not commit unreviewed hunks.
- [ ] Commit after the diff is reviewed; the suite is green unless the format
      asks for a red-test commit.
- [ ] If the agent committed without asking, see "Git moves" above.

## Checks by stack

| Stack | Tests | Format | Lint | Types |
|---|---|---|---|---|
| Python | `python3 -m pytest -q` | `black --check <paths>` | `ruff check <paths>` | `mypy <paths>` |
| Node | `npm test` / `pnpm test` | `npx prettier --check .` | `npx eslint .` | `npx tsc --noEmit` |
| Java | `./mvnw -q test` / `./gradlew test` | `./mvnw -q spotless:check` | `./mvnw -q checkstyle:check` | `./mvnw -q -DskipTests compile` / `./gradlew compileJava` |

Use the repo's own commands; these are fallbacks.

## Stop rules

| Signal | Action |
|---|---|
| Diff > 200 lines | Stop; split into two prompts. Revert only if unreviewable. |
| Agent edits an existing test | Revert that hunk; repeat with "do not modify existing tests". |
| Two failures in a row | Stop prompting; read the error; adjust the spec. |
| 50% of time, main criterion not started | Freeze scope: criteria 1–2 only. |
| Red suite at 80% of time | Return to the last green; finish the smallest criterion. |
| No agent allowed | Manual mode: same phases, you type. |
| Agent proposes a new dependency | Reject by default; justify only if essential. |

## Review phrases

- *"Let me restate the acceptance criteria before I touch anything."*
- *"Give me a three-line plan before you edit anything."*
- *"I don't trust this diff yet — let me verify it against the source."*
- *"That's plausible, but it's not what the spec says."*
- *"Before shipping I'd reconcile counts and sums with the source system."*
- *"What did you not verify?"*
