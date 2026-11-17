---
name: joplin
description: Manage Joplin notes through the local Data API (Web Clipper service on localhost:41184) — notebooks, notes, tags, attachments (resources) and full-text search. Use when the user asks to save, copy, search, organise or update anything in Joplin, references a notebook path like "Agenda / CV / docs", or wants local files attached as Joplin resources.
author: jordimarsal
version: "1.0"
tags:
  - notes
  - knowledge-management
  - joplin
  - local-api
---

# Joplin — manage notes via the local Data API

Talk to a running Joplin desktop/CLI app over its local HTTP API: create and
organise notebooks, write notes, attach files as resources, full-text search.
No `joplin` terminal binary and no external MCP needed — only the app running
with the Web Clipper service enabled.

Reference: [references/api.md](references/api.md) — endpoint cheat sheet,
pagination, resource linking syntax, error catalogue.

## Setup (30 seconds, no questions asked)

1. **Find the port.** Probe `GET http://localhost:<p>/ping` for p in
   41184..41194. The answer `JoplinClipperServer` is the live server.
2. **Get the token.** Read it from the desktop config:
   `~/.config/joplin-desktop/settings.json` → key `api.token`.
   Do not ask the user first — read the file. If both file and port fail,
   then ask: token is under *Tools → Options → Web Clipper*.
3. **Never echo the token** in output, logs, examples or chat. It is a
   credential with full read/write to every note.

```bash
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/.config/joplin-desktop/settings.json'))['api.token'])")
curl -s "http://localhost:41184/ping"   # -> JoplinClipperServer
```

## Ground rules

- **Read before write.** List the notebook tree first. Reuse the existing
  notebook that matches the user's path (match its exact casing — the tree
  may mix `Cirql` and `sparta`). Create a notebook only when nothing matches.
- **Dedupe.** Before creating a note, check the target folder for a note with
  the same title. If it exists, report and ask: update, replace or skip.
- **Copies are snapshots.** When copying files into Joplin, the original
  workspace stays the source of truth. Joplin never becomes the canonical
  location for versioned documents.
- **Destructive operations** (delete note, delete folder, overwrite a note
  body) need an explicit instruction. Restating the request is not enough.
- **Never touch `database.sqlite`** or the `resources/` directory on disk.
  Everything goes through the API — direct DB writes corrupt sync.
- **Verify every upload.** After creating a resource, download it back
  (`GET /resources/:id/file`) and check byte size and magic bytes
  (`%PDF`, PNG signature). A 200 with an empty body is a silent failure.

## Core operations

### Notebook tree

```bash
curl -s "http://localhost:41184/folders?token=$TOKEN&limit=100" \
  | python3 -c "import json,sys;[print(f['parent_id'],f['id'],f['title']) for f in json.load(sys.stdin)['items']]"
```

Notebook = folder. `parent_id` builds the tree. Responses are paginated
(`{"items": [...], "has_more": true}`) — use `limit=100` and follow pages.

### Notes

```bash
# notes of a folder
curl -s "http://localhost:41184/folders/$FID/notes?token=$TOKEN&fields=id,title&limit=100"

# create
curl -s -X POST "http://localhost:41184/notes?token=$TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"title\":\"Titol\",\"body\":\"markdown aqui\",\"parent_id\":\"$FID\"}"
```

Body is Markdown. To link an attachment inside a note body use the resource
syntax: `[file.pdf](:/<resource_id>)`.

### Attachments (resources) — the gotcha

The file field is named **`data`**, not `file`. With the wrong field name the
API answers `Resource cannot be created without a file`, which reads like a
missing file but is a field-name problem.

```bash
curl -s -X POST "http://localhost:41184/resources?token=$TOKEN" \
  -F 'data=@document.pdf;type=application/pdf' \
  -F 'props={"title":"document.pdf"}'
```

Then link it from a note body with `[document.pdf](:/<returned_id>)`.

### Search

```bash
curl -s "http://localhost:41184/search?token=$TOKEN&query=kafka+idempotent&type=note&limit=20"
```

`type` = `note` | `folder` | `tag`. Full-text search needs the desktop app
running; if it returns empty results for text you know exists, fall back to
listing folders and grepping note bodies via `GET /notes?fields=id,title,body`.

## Recipe — snapshot workspace docs into a notebook

Common case: "copy these docs to Joplin, in `A / B / company`".

1. Walk the notebook path; create missing folders bottom-up with
   `POST /folders {"title": ..., "parent_id": ...}`.
2. One note per document, following the target notebook's existing note
   pattern (check an older sibling notebook first — note titles like
   `Fitxa` / `carta` / `CV` are conventions, not accidents).
3. Markdown files go as note bodies; binaries (PDF, images) go as resources
   with a thin note whose body is just the resource link.
4. Report back: notebook path, note titles, resource ids. The workspace
   original files remain canonical.

## Error catalogue

| Signal | Meaning | Action |
|---|---|---|
| `/ping` empty on all ports | Clipper service off | ask user to enable *Tools → Options → Web Clipper* |
| HTTP 403 or `error` in JSON | bad token | re-read `settings.json`; the token rotates |
| `Resource cannot be created without a file` | multipart field is `file` instead of **`data`** | rename the field |
| note body shows raw `(:/id)` instead of an attachment | resource id wrong or deleted | re-create the resource, update the body |
| `{}` or truncated JSON | pagination hit | follow `has_more` / use `limit=100` |

## Hard rules

- ❌ Never print, commit or log the API token.
- ❌ Never create duplicate notebooks or notes when one exists — link, don't
  fork the knowledge base.
- ❌ Never edit the Joplin SQLite database or resource files on disk.
- ✅ Always verify an uploaded resource by reading it back.
- ✅ Always confirm before deleting or overwriting existing notes.
