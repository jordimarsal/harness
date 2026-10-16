---
name: wekan-tasks
description: Mirror workflow states on a Wekan kanban board — create a feature card, move it between state lists, comment progress. Built for the harness SDD flow (create at pending, spec_ready, in_progress, blocked, done) and driven by harness/wekan.json, but usable whenever an agent should keep a Wekan board in sync with its work. Use when running harness with the wekan-tickets module, or when asked to mirror task state, comment progress, or track features on Wekan.
author: jordimarsal
version: "1.0"
tags:
  - wekan
  - kanban
  - project-management
  - workflow
  - integration
---

# wekan-tasks — Wekan ticket mirror for the harness SDD flow

The harness is the source of truth (`harness/feature_list.json`); Wekan is the
**visible trace**. Every workflow state transition is mirrored on the board: the
card IS the ticket. Wekan sync must NEVER block the SDD flow — on any failure,
log it in `harness/progress/current.md` and continue.

## Configuration and secrets

All connection data lives in `harness/wekan.json`:

- `url` — base URL of the self-hosted Wekan instance.
- `board_name` — board title (empty = project name from `harness/feature_list.json`).
- `list_map` — SDD state → list title. Default lists: `pending`, `spec_ready`,
  `in_progress`, `blocked`, `done`. Card position == feature status.
- `credentials_file` — path to a **gitignored** env file defining
  `WEKAN_API_BEARER_TOKEN` and `WEKAN_API_USER_ID`.
- `enabled` — kill switch. If `false`, or if `harness/wekan.json` is absent, skip
  every Wekan action silently.

**Secret handling — the agent never reads the credentials file.** The file is
gitignored and deliberately kept outside the agent's reach; that is
intentional. The operator (or the session bootstrap) exports
`WEKAN_API_BEARER_TOKEN` and `WEKAN_API_USER_ID` as environment variables
before dispatch. The agent:

- reads only the two environment variables;
- sends the token **only** to the configured Wekan `url` — never to logs,
  error messages, progress notes, or any other host;
- never disables TLS verification (`-k`/`--insecure` is forbidden on any
  request that carries the token; use `--cacert` with the system CA bundle
  or the operator-provided CA file);
- never quotes the token value back in any output. If a request fails with
  401/403, say "credentials rejected by the server" and stop — do not retry
  with variations.

If the environment variables are absent, skip syncing, note it once in
`harness/progress/current.md`, and continue the SDD flow without Wekan.

Session setup (the only wiring an agent does — `url` is not a secret; the
credentials come from the environment):

```bash
CFG_URL="$(sed -n 's/^"url"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' harness/wekan.json)"
AUTH=(-H "Authorization: Bearer $WEKAN_API_BEARER_TOKEN" -H "X-User-Id: $WEKAN_API_USER_ID")
CURL=(curl -sS --cacert "${WEKAN_CA_FILE:-/etc/ssl/certs/ca-certificates.crt}")
# every request below: "${CURL[@]}" "${AUTH[@]}" "$CFG_URL/..."
```

## Resolve the board (once per session)

1. **Board lookup:** `GET /api/boards` only lists PUBLIC boards. Try it first;
   if the board is private, ask the operator for the board id (they can read
   it from the Wekan UI URL or run any mongo lookup themselves) and export it
   as `WEKAN_BOARD_ID`. The agent never connects to the database.

   ```bash
   "${CURL[@]}" "${AUTH[@]}" "$CFG_URL/api/boards"   # public boards, [{_id,title},...]
   ```

2. **Create if missing** (idempotent; the creator becomes board admin) and ensure
   the five `list_map` lists exist:

   ```bash
   BOARD=$(("${CURL[@]}" "${AUTH[@]}" -X POST "$CFG_URL/api/boards" \
     -H "Content-Type: application/json" -d '{"title":"<project>"}' \
     | python3 -c "import json,sys; print(json.load(sys.stdin)['_id'])"))
   # POST returns {_id, defaultSwimlaneId}; keep the swimlane id
   SWIMLANE=$("${CURL[@]}" "${AUTH[@]}" "$CFG_URL/api/boards/$BOARD" | python3 -c "import json,sys; print(json.load(sys.stdin)['defaultSwimlaneId'])")
   for L in pending spec_ready in_progress blocked done; do
     "${CURL[@]}" "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/lists" \
       -H "Content-Type: application/json" -d "{\"title\":\"$L\"}"
   done
   ```

3. **Resolve list ids** once and reuse them:

   ```bash
   "${CURL[@]}" "${AUTH[@]}" "$CFG_URL/api/boards/$BOARD/lists"   # [{_id,title},...]
   ```

## Role traces (who does what, when)

| Event | Agent | Wekan action |
|---|---|---|
| Feature added / first seen at session start | leader | Create card (or reuse the card id from the feature's `"wekan_card"`); fill title + description (title, description, acceptance criteria) |
| Spec written | spec-author | Move card → `spec_ready`; comment with the spec path |
| Human approves spec | leader | Move card → `in_progress` |
| Implementation starts | implementer | Set `startAt` to today |
| Task progresses / blocked | implementer | Comment with progress; if blocked move → `blocked` (and back when unblocked) |
| Review verdict | reviewer | Comment with verdict; on approval move → `done` and set `endAt` to today |
| Rework requested | reviewer | Move card back → `in_progress`; comment with findings |

The leader records the created card id in the feature object:
`"wekan_card": "<cardId>"` in `harness/feature_list.json` — agents then never
re-search the board for the card.

## Operations

```bash
# Create a card — swimlaneId is REQUIRED (500 without it)
"${CURL[@]}" "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/lists/$LIST_PENDING/cards" \
  -H "Content-Type: application/json" \
  -d '{"title":"<feature title>","description":"<desc + acceptance>","authorId":"'$WEKAN_API_USER_ID'","swimlaneId":"'$SWIMLANE'"}'
# → {"_id":"<cardId>"}

# Move a card to another list (= state transition)
"${CURL[@]}" "${AUTH[@]}" -X PUT "$CFG_URL/api/boards/$BOARD/lists/$OLD_LIST/cards/$CARD" \
  -H "Content-Type: application/json" -d '{"listId":"'$NEW_LIST'"}'

# Comment
"${CURL[@]}" "${AUTH[@]}" -X POST "$CFG_URL/api/boards/$BOARD/cards/$CARD/comments" \
  -H "Content-Type: application/json" -d '{"comment":"spec_ready — see harness/specs/<name>/"}'

# Set startAt / endAt / dueAt (ISO 8601; date-only saves as T00:00:00Z)
"${CURL[@]}" "${AUTH[@]}" -X PUT "$CFG_URL/api/boards/$BOARD/lists/$LIST/cards/$CARD" \
  -H "Content-Type: application/json" -d '{"startAt":"2026-09-07","endAt":"2026-09-08"}'
```

## Common errors

| Symptom | Cause and fix |
|---|---|
| 401/403 listing `/api/boards` | That route only returns PUBLIC boards; get the board id from the operator for private boards. |
| 401 Unauthorized | `WEKAN_API_BEARER_TOKEN` truncated (tokens may end with `=` — never cut on `=`) or `WEKAN_API_USER_ID` missing. Re-export both and retry once; always send both headers. |
| 500 "Swimlane ID is required" | Add `swimlaneId` when creating the card. |
| 405 Method Not Allowed | Wrong route/method. |
| Empty board lookup | Board does not exist yet → create it (see above). |

## Never do

- Never put secrets in `harness/wekan.json` or commit the credentials file.
- Never use `POST /users/login` to obtain a token (fails for API users).
- Never block the SDD flow on Wekan errors — log and continue.
- Never invent dates: leave `dueAt`/`startAt`/`endAt` empty unless specified.

---

Part of the [harness](https://github.com/jordimarsal/harness) SDD suite (MIT).
