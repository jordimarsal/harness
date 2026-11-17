# Joplin Data API — cheat sheet

Base: `http://localhost:41184` (probe 41184–41194 with `GET /ping`, expected
answer `JoplinClipperServer`). Every call needs `?token=<token>`.
Official reference: https://joplinapp.org/api/references/rest_api/

## Shapes and conventions

- List endpoints return `{"items": [...], "has_more": bool}`. Always pass
  `limit=100` and loop while `has_more`.
- `fields=` selects columns (`id,title,body,parent_id`) — request only what
  you need; `body` can be huge.
- Timestamps are epoch milliseconds. `user_updated_time` can be set manually
  and is what the UI shows; setting it also updates `updated_time`.
- Item type ids in the DB: 1=note, 2=folder, 4=resource, 5=tag, 6=note-tag.
  Relevant only if you ever read exports; use REST resources, not the DB.

## Folders (notebooks)

| Call | What |
|---|---|
| `GET /folders?limit=100` | all notebooks with `id`, `parent_id`, `title` |
| `POST /folders` | `{"title":"nom","parent_id":"<id>"}` — omit `parent_id` for top level |
| `GET /folders/:id/notes?limit=100` | notes in a notebook |
| `DELETE /folders/:id` | delete notebook **and its notes** — confirm first |

Build a path `A / B / C` bottom-up: find or create `A`, then `B` under it,
then `C`. Compare titles case-sensitively; reuse before creating.

## Notes

| Call | What |
|---|---|
| `GET /notes?limit=100&fields=id,title,parent_id` | all notes (page through) |
| `GET /notes/:id?fields=title,body` | one note |
| `POST /notes` | `{"title","body","parent_id"}` — body is Markdown |
| `PUT /notes/:id` | update fields; send only what changes |
| `DELETE /notes/:id` | to trash (recoverable until purge) |
| `GET /notes/:id/tags` | tags of a note |
| `POST /notes/:id/tags` | `{"id":"<tag_id>"}` — attach tag |

Note properties worth knowing: `is_todo` (0/1), `todo_completed` (epoch ms or
0), `markup_language` (1=Markdown, 2=HTML — leave at 1).

## Resources (attachments)

| Call | What |
|---|---|
| `POST /resources` | multipart upload — fields **`data`** (file) + `props` (JSON) |
| `GET /resources/:id` | metadata (`id`, `title`, `mime`, `size`, `filename`) |
| `GET /resources/:id/file` | the bytes — use this to verify an upload |
| `DELETE /resources/:id` | delete — breaks any note linking it |

Upload:

```bash
curl -s -X POST "http://localhost:41184/resources?token=$TOKEN" \
  -F 'data=@doc.pdf;type=application/pdf' \
  -F 'props={"title":"doc.pdf"}'
```

Multipart field names are `data` and `props` — nothing else. `file` triggers
`Resource cannot be created without a file`.

Link from a note body (Markdown):

```
[doc.pdf](:/<resource_id>)
```

Images embed with `![alt](:/<resource_id>)`. Resource ids are 32-hex.

## Search

```bash
curl -s "http://localhost:41184/search?token=$TOKEN&query=<query>&type=note&limit=20"
```

- `type`: `note` | `folder` | `tag`.
- Returns items ordered by relevance; same pagination envelope.
- If results are empty for known-existing text, the search index may not be
  built (fresh install / disabled plugin) — fall back to listing and grepping.

## Tags

| Call | What |
|---|---|
| `GET /tags?limit=100` | all tags |
| `POST /tags` | `{"title":"etiqueta"}` |
| `GET /tags/:id/notes` | notes with this tag |

## curl quick reference

```bash
TOKEN=$(python3 -c "import json;print(json.load(open('$HOME/.config/joplin-desktop/settings.json'))['api.token'])")
BASE="http://localhost:41184"

# paginated full walk of one endpoint
page=1
while :; do
  json=$(curl -s "$BASE/folders?token=$TOKEN&limit=100&page=$page")
  echo "$json" | python3 -c "import json,sys;[print(f['title']) for f in json.load(sys.stdin)['items']]"
  echo "$json" | python3 -c "import json,sys;exit(0 if json.load(sys.stdin)['has_more'] else 1)" || break
  page=$((page+1))
done
```

## Token location per install type

| Install | Path |
|---|---|
| macOS desktop | `~/.config/joplin-desktop/settings.json` → `api.token` |
| Linux desktop | `~/.config/joplin-desktop/settings.json` → `api.token` |
| Windows desktop | `%USERPROFILE%\.config\joplin-desktop\settings.json` → `api.token` |
| Terminal CLI | `~/.config/joplin/settings.json` → `api.token` |

The token is regenerated whenever the user toggles the Web Clipper service —
if a previously working script starts getting 403, re-read the file.
