#!/usr/bin/env bash
# tests/e2e-go.sh — R11 end-to-end for the go stack (requires the Go toolchain).
# Builds a minimal real module, installs harness on it and runs the copied
# gate: the test block must execute the real `go test ./... -race -count=1`
# and pass. CI runs this on a runner with setup-go; locally it needs go on
# PATH (tarball install to ~/.local/go is enough).
# Exit codes: 0 = e2e green · 1 = verification failed · 2 = go not on PATH.
set -u
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
INIT="$REPO_DIR/init.sh"
PASS=0; FAIL=0
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

command -v go >/dev/null 2>&1 || {
  echo "FAIL: go is not on PATH — this e2e requires the real toolchain (https://go.dev/dl/)"
  exit 2
}
echo "Go toolchain: $(go version)"

d="$TMP_ROOT/e2e-go"
mkdir -p "$d/greet"
cd "$d" || exit 1
go mod init example.com/e2e >/dev/null

cat > greet/greet.go <<'EOF'
package greet

import "fmt"

func Hello(name string) string {
	if name == "" {
		return "Hello, world!"
	}
	return fmt.Sprintf("Hello, %s!", name)
}
EOF

cat > greet/greet_test.go <<'EOF'
package greet

import "testing"

func TestHello(t *testing.T) {
	cases := []struct{ name, in, want string }{
		{"empty name falls back to world", "", "Hello, world!"},
		{"named greeting", "Jordi", "Hello, Jordi!"},
	}
	for _, c := range cases {
		if got := Hello(c.in); got != c.want {
			t.Errorf("%s: Hello(%q) = %q, want %q", c.name, c.in, got, c.want)
		}
	}
}
EOF

t="go stack e2e: install detects, wires commands, gate runs the real go test"
echo "=== $t ==="
if bash "$INIT" --tool=opencode > install.log 2>&1; then
  PASS=$((PASS + 1))
else
  echo "FAIL: install exited non-zero"; tail -n 20 install.log; exit 1
fi
grep -q "Detected stack: go" install.log || { echo "FAIL: stack not detected as go"; exit 1; }
grep -qF 'go test ./... -race -count=1' opencode.json || { echo "FAIL: test command not wired"; exit 1; }
PASS=$((PASS + 2))

if ./harness/init.sh > gate.log 2>&1; then
  PASS=$((PASS + 1))
else
  echo "FAIL: copied gate did not pass (test block must run go test green)"
  tail -n 30 gate.log
  exit 1
fi

# The race detector must have actually executed (it is part of done, R4/D4).
grep -qE '^(ok|PASS)' gate.log || grep -q 'go test' gate.log || {
  echo "FAIL: gate log shows no evidence of the go test run"; tail -n 30 gate.log; exit 1
}
PASS=$((PASS + 1))

echo ""
echo "go-stack e2e: PASS: $PASS  FAIL: $FAIL"
exit 0
