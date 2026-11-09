---
name: sonarqube
description: Operate a SonarQube server (local Docker, homelab, or company instance) from an agent session — check server health and auth, resolve the project key, run a scanner analysis, wait for the Quality Gate, query issues and hotspots, wire the project's review step to the gate, and install or troubleshoot the server itself. Also compares the 2026 agent-integration routes (scanner + API, official MCP server, SonarQube CLI, SonarQube for IDE / SonarLint). Use when the user mentions SonarQube, SonarCloud, quality gate, sonar-scanner, SonarLint, SonarQube for IDE, sonar-project.properties, or wants code-quality gating in a review or CI step.
author: jordimarsal
version: "1.0"
tags:
  - quality
  - static-analysis
  - code-quality
  - review
  - ci
---

# SonarQube for agents

SonarQube verifies code quality and security against a server that stores
results and applies a **Quality Gate** — the green/red verdict a review step
can block on. This skill covers operating an existing server from a session,
installing one locally, and choosing the agent-integration route.

## Preflight (always first)

Run from the project root, in order, and stop at the first red:

```bash
curl -s --max-time 5 "${SONAR_HOST_URL:-http://localhost:9000}/api/system/status"
# → {"status":"UP"} continues; anything else → server down or wrong URL
command -v sonar-scanner || command -v docker   # at least one analysis route
test -n "${SONAR_TOKEN:-}"                      # credentials present
```

No token and no server is a legitimate outcome: record it and continue
without SonarQube evidence — a missing server is never a code-quality pass.

Token rules:

- A **user** token (My Account → Security), not a project token — some APIs
  (project create, gate binding) reject project tokens.
- Never echo it, never write it into tracked files. Use `SONAR_TOKEN` in the
  environment or a gitignored file (harness projects: `harness/sonar.env`,
  see `harness/sonar.env.example`).

## Resolve the project before querying it

Use the exact project key, not the display name. In order:

1. Key given by the user.
2. `sonar.projectKey` in `sonar-project.properties` at the repo root.
3. Git remote → `owner:repo` (`git@host:owner/repo.git` → `owner:repo`).
4. Directory name.

Ambiguous matches: list projects first (`curl -u "$SONAR_TOKEN:" "$SONAR_HOST_URL/api/projects/search?q=<term>"`),
ask, never guess between multiple matches.

## Analyze and gate

Fast path — a reachable server and one command:

```bash
bash harness/tools/sonar-review.sh          # harness installs: scan + gate + exit code
# without harness: scanner, then poll the gate (recipes in references/api-recipes.md)
```

Mode semantics (harness tool): `auto` scans when a scanner or Docker exists,
else reads the last stored analysis (`api`); `--report-only` reports a failed
gate without blocking. Exit codes: `0` gate passed · `1` gate failed (the
reviewer rejects) · `2` SonarQube unavailable (skip, record) · `3` analysis
error (skip, record — never treat as a pass).

Interpret results honestly:

- **First analysis of a project** has no baseline: every issue counts as new
  code. A red gate on a brand-new project is information, not a tool bug.
- A green gate is maintainability evidence. It never replaces requirement
  traceability or tests — do not cite it as test coverage.
- Fix findings at the source. `// NOSONAR` suppressions need a written
  justification in the feature's progress notes, one per suppression.

## Wire the review step (harness projects)

```bash
bash init.sh --update --add-modules=sonarqube   # or --modules=sonarqube on install
```

The module installs `harness/tools/sonar-review.sh` + `docs/sonarqube-protocol.md`,
gitignores `harness/sonar.env`, and the reviewer runs the tool before every
verdict: gate failed → `CHANGES_REQUESTED`; server unreachable → recorded
skip. Full rules in the installed `docs/sonarqube-protocol.md`.

## Install a local server (when none exists)

Docker Compose recipe (Community Build + PostgreSQL, zero host ports), token
provisioning, and scanner installation live in
[references/installation.md](references/installation.md). Local servers that
publish no host ports are reached via the container's bridge IP — the harness
tool does this discovery automatically.

## Choosing the agent-integration route

| Route | Needs | Best for |
|---|---|---|
| **Scanner + API** (this skill, harness module) | server + token + scanner | review gates, CI, reproducible verdicts |
| **Official MCP server** (`sonarsource/sonarqube-mcp`) | Docker, Server ≥ 2025.1 / CB ≥ 25.1 | interactive issue/hotspot browsing in agent context |
| **SonarQube CLI** (`sonar`) | install + login | `sonar analyze` on changed files (Cloud-leaning), secrets scan |
| **SonarQube for IDE** (ex-SonarLint) | desktop IDE running | the human in the editor; agents only via its MCP bridge while open |

Full comparison, setup snippets and the decision rationale:
[references/agent-integrations.md](references/agent-integrations.md).

## API recipes

Gate status, failed conditions, issue search filtered to changed files,
hotspot triage and cleanup: [references/api-recipes.md](references/api-recipes.md).

## Troubleshooting

| Symptom | Cause → fix |
|---|---|
| `Insufficient privileges` on admin APIs | user token without admin — grant or use an admin token for setup tasks only |
| `Project not found` on gate query | no analysis ever ran — scan once (`auto` mode does it) |
| Scanner can't reach `localhost:9000` | server is docker-network-only — use container-IP discovery or join its network (`SONAR_SCANNER_NETWORK`) |
| `sonar.java.binaries` missing analysis depth | compile first (`mvn compile` / `gradle classes`); Maven/Gradle projects should use their build plugin instead of raw scanner |
| Compute Engine stuck / gate unreadable | check `/api/ce/task?id=<id>`; CE needs RAM — raise `SONAR_WEB_JAVAOPTS`/`SONAR_CE_JAVAOPTS` on small hosts |
| Gate flaps between runs | coverage report found on one run, not the next — generate it in the same command (`pytest --cov`, `vitest --coverage`, JaCoCo) |

## Hard rules

- ❌ Never commit tokens; never echo them in logs, reports or chat.
- ❌ Never approve a feature citing only a green gate — it is one evidence
  line, not the review.
- ❌ Never mutate server config (gates, quality profiles, users) from a
  feature session without an explicit human instruction.
- ✅ Record every skip/error verdict with its reason — silence hides a
  missing gate behind an assumed pass.
