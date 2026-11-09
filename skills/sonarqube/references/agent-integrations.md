# Agent-integration routes (2026 study)

Four real routes bring SonarQube to an AI coding agent. They are complements,
not competitors — most setups end with scanner+API as the gate and one of the
others as the interactive layer.

## 1. Scanner + API (the review-gate route)

What: `sonar-scanner` (binary or the `sonarsource/sonar-scanner-cli` Docker
image) uploads an analysis; the Compute Engine processes it; the Quality Gate
API returns OK/ERROR with failed conditions.

Why it wins for review steps:

- Deterministic verdict (gate pass/fail) an agent can block on — no judgment
  drift, no prompt sensitivity.
- Works against Community Build (free, self-hosted) — no entitlements.
- Same command in a feature session, CI, and the human's terminal.

Costs: a full scan per review (seconds for small repos, minutes for large);
needs a reachable server.

## 2. Official MCP server (`sonarsource/sonarqube-mcp`)

What: Sonar's official Model Context Protocol server (Docker image or npm).
Tools span issues, security hotspots, quality gates, coverage, measures,
dependency risks, plus snippet/file analysis.

Setup (stdio, SonarQube Server):

```json
{
  "sonarqube": {
    "command": "docker",
    "args": ["run", "--init", "--pull=always", "-i", "--rm",
             "-e", "SONARQUBE_TOKEN", "-e", "SONARQUBE_URL",
             "sonarsource/sonarqube-mcp"],
    "env": { "SONARQUBE_TOKEN": "<user token>", "SONARQUBE_URL": "http://<server>:9000" }
  }
}
```

Hard requirements and gotchas (as of 2026):

- **Server version**: SonarQube Server ≥ 2025.1 or Community Build ≥ 25.1 —
  older 9.x/10.x/24.x instances are rejected at startup.
- **User token required** — project/global tokens fail against Server.
- Narrow the tool surface: `SONARQUBE_TOOLSETS=issues,quality-gates` cuts
  context bloat; `SONARQUBE_READ_ONLY=true` for reviewer agents.
- `analyze_code_snippet` is deprecated; the IDE-bridge (`analyze_file_list`,
  needs a running SonarQube for IDE on ports 64120-64130) and Vortex
  `run_advanced_code_analysis` (commercial entitlement) replace it.
- It is **per-user agent config**, not repo-portable — a harness install
  cannot ship it; document it instead (that is what this reference is).

Best for: interactive sessions — "what does the server think about this file
since last week", hotspot triage, coverage maps. Not a gate.

## 3. SonarQube CLI (`sonar`)

What: Sonar's terminal CLI (v1.7.x). `sonar analyze` (git-changed files),
`sonar analyze secrets`, `sonar quality-gate status`, `sonar list issues`,
`sonar api get …`, `sonar integrate <agent>`.

Caveats:

- `sonar analyze` full analysis leans on **SonarQube Cloud / Vortex
  entitlements**; against a plain self-hosted Server it degrades or refuses
  (the local secrets stage also refuses without credentials).
- `sonar api get` works against Server and Cloud — it is a thin,
  authenticated HTTP client; useful for exactly the recipes in
  [api-recipes.md](api-recipes.md) without curl boilerplate.

Best for: Cloud-backed teams, secrets scanning, agents that prefer a CLI over
raw API calls.

## 4. SonarQube for IDE (formerly SonarLint)

What: the free IDE extension (VS Code, JetBrains) that analyzes on-the-fly.
Since v13 it ships an **AI Integrations** panel: SonarQube CLI onboarding and
per-agent MCP configuration.

The study question — *can the IDE plugin serve an agent's review step?* —
resolves to:

- **The plugin itself is for the human.** An agent in a terminal cannot
  receive its editor diagnostics. Install it for yourself, not for the loop.
- **The MCP bridge is real but fragile**: the official MCP server can
  connect to a running IDE (`SONARQUBE_IDE_PORT`, 64120-64130) and call
  `analyze_file_list` — but only while the IDE is open with the project
  loaded. A headless review step must not depend on a GUI process.
- **Headless SLOOP** (the IDE's analysis engine) can be driven offline by
  third-party harnesses (pinned `sonarlint-backend-cli` + private socket
  protocol). It works, but it is an unofficial protocol Sonar can change,
  it downloads analyzers separately, and it yields file-level findings with
  no Quality Gate semantics. Not recommended as a review gate.
- **Connected mode** (IDE ↔ server) syncs quality profiles — valuable for
  the human seeing exactly what the server would enforce.

## Decision table

| You need | Route |
|---|---|
| A review step that blocks on a red gate | **1** (harness `sonarqube` module) |
| Agent browsing issues/hotspots in-session | **2** (MCP, read-only toolsets) |
| Secrets scan before push, Cloud orgs | **3** (`sonar analyze secrets`) |
| The human seeing gate-accurate findings while editing | **4** (IDE + connected mode) |
| Offline analysis, no server at all | 4-headless (unofficial) or linters — not a gate |

**Harness default**: route 1 in the review step; routes 2–4 documented for
the human and the interactive layer. The review gate must run headless,
deterministic, and against the same server CI uses.
