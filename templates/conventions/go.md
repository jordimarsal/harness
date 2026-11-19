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
## Code quality

- `go vet`, `gofmt -l .` empty, `govulncheck ./...` in CI.
- Structured logging via `log/slog` with fields; no `fmt.Println` outside
  `cmd/`.
<!-- /quality -->
