# Design: Go as the 8th supported stack

**Date:** 2026-11-19
**Status:** Approved (Spec Gate — maintainer, 2026-11-19)
**Source:** motivation: a Go practice repo (post Java/Python, 9y backend) must be
born inside the harness protocol; the conventions chunk is the safety net that
keeps every agent dispatch writing idiomatic Go instead of translated Java.

## 1. Goal

Add stack `go` with the same surface every other stack has: detection,
test/build commands, a language conventions chunk, a security-audit branch,
module-manifest compatibility, the Claude hybrid template, docs and version
bump. No new mechanisms — this feature is a direct application of the existing
stack architecture (`detect_stack` → conventions composition → module stacks).

Why it matters here: `docs/conventions.md` is what an implementer reads
**before writing code**. Encoding Go idioms once means every future dispatch in
any Go project inherits them. The chunk (Appendix A) is the actual product of
this feature; everything else is wiring.

## 2. Requirements (EARS)

- **R1 — detection.** WHEN `init.sh` runs in a directory containing `go.mod`
  and none of the higher-priority markers (`tsconfig.json`, `package.json`,
  gradle+manifest, `build.gradle`/`pom.xml`, python markers), the system SHALL
  detect stack `go`.
- **R2 — commands.** WHEN the detected stack is `go`, `init.sh` SHALL set
  `TEST_CMD="go test ./... -race -count=1"` and
  `BUILD_CMD="go build ./..."`, surfaced through the same wiring as the other
  stacks (init output + test block).
- **R3 — conventions generation.** WHEN the detected stack is `go`,
  `docs/conventions.md` SHALL be generated from
  `templates/conventions/go.md` via the existing `generate_conventions`
  (`init.sh:957`), containing the six marked sections
  (`style`, `naming`, `structure`, `tests`, `errors`, `quality`).
- **R4 — conventions content.** The chunk SHALL encode, at minimum:
  (a) `gofmt`/`goimports` + `golangci-lint` (errcheck, staticcheck, revive,
  gosec) zero-warning baseline, `//nolint` needs a why-comment;
  (b) visibility by capitalization; bare getters (no `GetHolder`);
  initialisms capitalized (`ServeHTTP`, `apiKey`);
  (c) package names short/lowercase/content-addressed — no `utils`/`common`;
  (d) layout: `cmd/<name>/main.go` thin assembly, `internal/` by default,
  domain packages importing no framework, ORM or transport;
  (e) interfaces at the consumer, 1–3 methods — with the explicit hexagonal
  exception: ports live in the domain package, named by role;
  (f) errors as values: returned or handled (`_ = err` banned), wrapped with
  `%w`, matched with `errors.Is/As`, no log-and-return, no `panic` outside
  `main` and startup;
  (g) `context.Context` first parameter of anything doing I/O; cancellation
  always propagates;
  (h) tests: table-driven as the default shape, stdlib assertions, `-race`
  part of done, every goroutine has an owner (errgroup / done channel /
  context) — leaks are review-blocking;
  (i) logging via `log/slog` with fields; no `fmt.Println` outside `cmd/`.
- **R5 — dependency scan.** WHEN `audit-security.sh` runs with stack `go` and
  `govulncheck` is on PATH, it SHALL run it and map the result to the existing
  HIGH contract: exit 0 → clean; exit 3 (vulnerabilities found) → `HIGH=1`;
  any other non-zero → recorded skip (tool failure is never a finding).
  WHEN absent, it SHALL record a SKIPPED entry naming the install command
  (`go install golang.org/x/vuln/cmd/govulncheck@latest`), in both text and
  `--json` modes.
- **R6 — SAST.** WHEN stack is `go`, the audit SHALL emit hint lines for
  `go vet` (executes when the `go` binary is present — it ships with every
  toolchain) and `staticcheck`/`golangci-lint` (hint only, mirroring the
  clippy pattern of the rust branch at `audit-security.sh:182`).
- **R7 — manifests.** The 11 stack-enumerating module manifests SHALL include
  `"go"`: architecture-catalog, clarity, decision-memory, gauntlet,
  iterative-refinement, log-reader, performance-benchmarks, security-audit,
  sonarqube, vertical-slices, wekan-tickets. `project-scanner` SHALL remain
  python-only (scan.py analyzes Python projects).
- **R8 — Claude hybrid.** WHEN installed with `--hybrid` on a go project,
  `CLAUDE.md` SHALL be copied from `templates/stacks/go/CLAUDE.md.tpl`
  (generic base + a `## Stack: Go` section with build/test/lint/format and key
  conventions), within the existing `STACK_TPL_BUDGET` (7000 bytes,
  `tests/test-install.sh:1556` — the glob covers the new file automatically).
- **R9 — docs & version.** README SHALL list Go among supported stacks
  ("8 stacks", `README.md:326`); the release pins SHALL agree in the three
  places the release contract demands (`install.sh` `HARNESS_REF:-` default,
  `package.json`, newest CHANGELOG heading) at `v0.12.0`. The version stamp
  itself comes from the git tag (`resolve_harness_version`, `init.sh:50`) —
  tag `v0.12.0` at merge.
- **R10 — tests, no toolchain required.** `tests/test-install.sh` SHALL gain a
  `test_go_stack` (fixture: `new_project` + `touch go.mod` → detected stack in
  output, `go test ./... -race -count=1` as test command, generated
  `docs/conventions.md` contains the six go sections) and a
  `test_security_audit_go_stack` covering the audit degradation path (no
  `govulncheck`/`go` on PATH → JSON `skipped` mentions them,
  `"stack":"go"`). All string-level: the suite stays green on machines
  without Go. *(Amended 2026-11-19: both tests live in `tests/test-install.sh`
  next to the existing security-audit degradation tests —
  `tests/test-security.sh` is the security-remediation regression suite, not
  the audit-tool suite.)* Both tests run against a **hermetic stub PATH**
  (`hermetic_bin`): stripping go from `$PATH` proved insufficient — hosted
  runners ship `/usr/bin/go`, and `/usr/bin` also owns bash/grep/mktemp
  (merged-usr), so the strip guts the toolchain the scripts run on.
- **R11 — end-to-end, toolchain required.** In a temp project with `go.mod`
  (`go mod init`), one tiny package and one table-driven test, `init.sh`
  SHALL complete with the test block green, executing the real
  `go test ./... -race -count=1`. Verified locally after installing Go and in
  CI via a new job.

## 3. Design decisions

- **D1 — detection priority: python < go < rust.** `go.mod` at the root is
  unambiguous and collides with no existing marker. Root-only, like every
  other marker; mixed repos (e.g. `go.mod` + root `package.json`) resolve to
  the higher-priority stack — accepted, same semantics as today.
- **D2 — chunk mirrors `rust.md`.** Same six marked sections, same density
  (~35 lines), same declarative voice. Distilled from Effective Go, Go Code
  Review Comments, Google Go Style Guide (decisions + best practices), and
  *100 Go Mistakes* (Harsanyi). The maintainer reviews the full text at the
  gate — highest-judgment file of the feature.
- **D3 — minimal audit surface.** Only `govulncheck` executes (it is the
  official vulnerability scanner); `go vet` executes when `go` exists;
  `staticcheck`/`golangci-lint` stay hint lines. Exit-code contract mirrors
  the sonarqube module philosophy: findings vs unavailable vs error are
  distinct states.
- **D4 — `-race -count=1` in TEST_CMD.** Race detection is part of "done" in
  the conventions, so the harness test block must run it; `-count=1` defeats
  Go's test cache so a green block is a fresh verification, not a replay.
- **D5 — no scaffolding.** `init.sh` never creates `go.mod` or runs
  `go mod init`. Detection requires an existing marker, exactly like
  `Cargo.toml`/`pyproject.toml`. Bootstrap stays with the user.
- **D6 — toolchain prerequisite, local.** Go is not on PATH on this machine
  (verified 2026-11-19). Unit tests don't need it (R10); the R11 e2e check
  does. Install via the official tarball (apt's golang lags); ≥1.23. This is
  on the critical path of the practice repo anyway.
- **D7 — CI job.** Extend `.github/workflows/ci.yml` with one job
  (`setup-go`, stable) running the same suite; keeps the whole suite honest
  on a machine where the toolchain exists, mirroring the existing
  single-job structure.
- **D8 — version 0.12.0 (minor).** New capability, non-breaking, no installer
  migration.

## 4. Files touched

| File | Change |
|---|---|
| `templates/conventions/go.md` | new — the chunk (Appendix A) |
| `init.sh` | `detect_stack()` go branch (~365); `go)` case in the tooling block (~582) |
| `init-verify.sh` | go branch in the gate's test-command detection (~109) — discovered by R11: without it the copied gate reports "No test framework detected" on a Go module and fails closed |
| `templates/modules/security-audit/audit-security.sh` | `go.mod` in its own stack detection; `go)` branch in the `case "$STACK"` (109), after the rust branch |
| `templates/modules/*/manifest.json` × 11 | add `"go"` to `stacks` |
| `templates/stacks/go/CLAUDE.md.tpl` | new — generic base + `## Stack: Go` |
| `tests/test-install.sh` | `test_go_stack` + `test_security_audit_go_stack` |
| `tests/e2e-go.sh` | new — R11 e2e: real module, real `go test -race` through the copied gate (exit 2 without toolchain) |
| `.github/workflows/ci.yml` | `go-stack` job (setup-go, runs the e2e); `tests/e2e-go.sh` in the shellcheck list |
| `README.md:326` · `CHANGELOG.md` · `package.json` · `install.sh` REF | 8 stacks · v0.12.0 entry · 0.12.0 · `HARNESS_REF:-v0.12.0` (three-pin release contract + tag) |

## 5. Tasks (batches of one dispatch each)

**Batch 1 — chunk + wiring**
- T1: `templates/conventions/go.md` (Appendix A verbatim unless the gate
  amends it).
- T2: `init.sh` — `detect_stack` branch + `go)` tooling case; add
  `test_go_stack` to `tests/test-install.sh`; suite green.

**Batch 2 — audit + compatibility**
- T3: `audit-security.sh` `go)` branch (R5/R6 contract); `"go"` into the 11
  manifests; degradation test in `tests/test-security.sh`; suite green.
- T4: `templates/stacks/go/CLAUDE.md.tpl` (R8); byte-budget check picks it
  up via the existing glob.

**Batch 3 — docs, version, e2e**
- T5: README stacks line, CHANGELOG `v0.12.0` entry (house voice), package.json
  `0.12.0`.
- T6: e2e verification per R11 (local, after Go install) + ci.yml go job;
  full suite green on both runners.

## 6. Verification

1. `bash tests/test-install.sh && bash tests/test-security.sh` — all green,
   no Go toolchain required (R10).
2. E2E (R11): `bash tests/e2e-go.sh` — temp dir → `go mod init example.com/x`
   → one package with a table-driven test → `harness/init.sh` finishes with
   the test block green executing `go test ./... -race -count=1`. Requires go
   on PATH (exit 2 otherwise); CI covers it on the `go-stack` job.
3. `shellcheck tests/e2e-go.sh` (CI runs it as part of the quality job).
3. Human eye on the generated `docs/conventions.md` of that temp project —
   the chunk is the deliverable; the gate reviews Appendix A, the install
   proves it composes.
4. Merge → tag `v0.12.0` → a later `install.sh --update` stamps
   `harness_version: v0.12.0`.

## 7. Non-goals

- No `golangci-lint` auto-install and no `.golangci.yml` template (a future
  module if ever wanted).
- No Go project scaffolding inside installed projects (D5).
- No changes to `skills/` or the Anthropic PR pipeline — stack wiring ships
  with the installer; the FOLLOW-UPS §13 gates are untouched.
- `scan.py`/project-scanner stay Python-only (R7).

## 8. Risks

- **Chunk quality is the product.** A wrong rule propagates to every Go
  dispatch. Mitigation: sources in D2, full text reviewed at the gate
  (Appendix A), amendable in T1 before anything ships.
- **Tool version drift** (vet/lint behavior across Go releases): floor is
  `go 1.23` in the e2e fixture and conventions header; CI tracks stable.
- **govulncheck exit semantics**: contract in R5 keeps "tool failed" and
  "vulnerabilities found" distinct — no fake highs, no silent passes.

## Appendix A — draft `templates/conventions/go.md`

```markdown
<!-- language: Go (1.23+) -->
<!-- style -->
- `gofmt`/`goimports` non-negotiable; `golangci-lint` (errcheck, staticcheck,
  revive, gosec) at zero warnings — `//nolint` needs a why-comment.
- Model the domain in types: small structs; closed sets as typed constants
  (`type Status int` + `iota`); no boolean-trap fields.
- Interfaces at the consumer, 1–3 methods, named after the behavior
  (`Notifier`, `PolicyStore`); accept interfaces, return concrete structs.
  Hexagonal exception: ports live in the domain package, named by role —
  adapters satisfy them implicitly (no `implements`).
- Composition over inheritance: embedding is implementation reuse, never
  is-a modeling.
<!-- /style -->
<!-- naming -->
- Visibility by case: `CamelCase` exported, `camelCase` internal — there is
  no `public`/`private`.
- Getters bare (`p.Holder()`), never `GetHolder`; `SetX` allowed. Initialisms
  consistently capitalized: `ServeHTTP`, `apiKey`.
- Package names short, lowercase, singular, content-addressed (`telemetry`,
  never `utils`/`helpers`/`common`); the package name is half the API:
  `telemetry.Sink`, not `TelemetrySink`.
<!-- /naming -->
<!-- structure -->
- One `go.mod` at root; binaries in `cmd/<name>/main.go` — thin assembly
  only, zero business logic.
- `internal/` for everything not meant to be imported; `pkg/` only with a
  real external consumer (default: no).
- Domain packages import no framework, ORM or transport: I/O at the edges,
  behind small interfaces.
<!-- /structure -->
<!-- tests -->
- Tests next to the code (`xxx_test.go`); table-driven is the default shape;
  stdlib assertions, no testify unless a spec says so.
- `go test ./... -race -count=1` green is part of done.
- Every goroutine has an owner: lifecycle via `errgroup`, done channel or
  `context` — leaks are review-blocking. Fuzz (`go test -fuzz`) for parsers.
<!-- /tests -->
<!-- errors -->
- Errors are values: returned or explicitly handled — `_ = err` banned. No
  `panic` outside `main` and startup failures.
- Wrap with context (`fmt.Errorf("loading policy %s: %w", id, err)`); match
  with `errors.Is/As`, never string matching. The caller decides what an
  error means — no log-and-return.
- `context.Context` is the first parameter of anything doing I/O;
  cancellation always propagates.
<!-- /errors -->
<!-- quality -->
- `go vet`, `gofmt -l .` empty, `govulncheck ./...` in CI.
- Structured logging via `log/slog` with fields; no `fmt.Println` outside
  `cmd/`.
<!-- /quality -->
```
