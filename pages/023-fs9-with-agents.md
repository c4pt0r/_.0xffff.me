# The Simplest Agent-to-Agent Communication: Just Use a Filesystem

Every few months, a new agent communication protocol appears. But for most agent workloads, the simplest answer is something we've had since the 1970s: a filesystem.

## Files as messages

One agent writes a file, another agent watches for it.

```
Agent A writes: /inbox/task-001.json
Agent B sees:  CREATE /inbox/task-001.json
Agent B reads: {"action":"summarize","url":"https://..."}
Agent B writes: /outbox/result-001.json
```

No SDKs. No protocol negotiation. The debugging story is unbeatable:

- `ls` shows queue depth
- `cat` shows payloads
- `rm` clears broken messages

This is not a new idea. Maildir has worked this way for decades.

## The missing piece: durable event streams

Traditional filesystems give you `inotify`-style notifications, but they're local-only, lossy under load, and don't work across machines.

What you want is a filesystem with a *real* event stream — durable, resumable, remote.

## fs9: a queryable filesystem with watch

[db9](https://db9.ai) includes fs9, a cloud-backed filesystem namespace. It supports `fs watch`: a cursor-based event stream over file changes.

```bash
db9 fs watch myapp:/inbox/
00:00:00.000 CREATE /inbox/task-001.json
00:00:01.234 MODIFY /inbox/task-001.json
00:00:05.678 DELETE /inbox/temp.txt
```

Key properties:

- **Durable**: events are stored as a stream. If your agent crashes, it resumes from its last cursor.
- **Remote**: two agents on different machines coordinate without VPN gymnastics.
- **Queryable**: files can be queried from SQL.

## Example: dispatcher + worker

A dispatcher writes tasks:

```sql
SELECT fs9_write(
  '/tasks/pending/t-' || gen_random_uuid() || '.json',
  '{"url":"https://example.com/article","requested_by":"user-42"}'
);
```

A worker watches and claims tasks via atomic move:

```bash
db9 fs watch myapp:/tasks/pending/ --json | while read -r event; do
  path=$(echo "$event" | jq -r '.path')
  type=$(echo "$event" | jq -r '.event_type')

  [ "$type" = "CREATE" ] || continue

  processing_path=$(echo "$path" | sed 's|/pending/|/processing/|')

  # Claim by atomic move
  if ! db9 sql myapp -q "SELECT fs9_move('$path', '$processing_path')" --output raw >/dev/null 2>&1; then
    continue
  fi

  # Process the task...
  task=$(db9 sql myapp -q "SELECT fs9_read('$processing_path')" --output raw)
  # your agent logic here
done
```

## SQL escape hatch

Because fs9 is queryable from SQL, you can run ops on your "queue" directly:

```sql
-- How many tasks are pending?
SELECT count(*) FROM extensions.fs9('/tasks/pending/');

-- What's the oldest unprocessed task?
SELECT path, mtime
FROM extensions.fs9('/tasks/pending/')
ORDER BY mtime ASC
LIMIT 1;
```

## Common patterns

- **Request/Response**: `/requests/{id}.json` → `/responses/{id}.json`
- **Fan-out**: many workers watch the same directory, claim via atomic move
- **Event log**: append-only writes to `/events/YYYY-MM-DD/`, consumers keep cursors
- **Config reload**: watch `/config/settings.json`, reload on modify

## Why this works for agents

Most agents don't need ultra-low latency or massive throughput. They need:

- **Simplicity** — fewer moving parts
- **Inspectability** — see the state with `ls` and `cat`
- **Persistence** — if an agent dies, the message is still there
- **Flexibility** — JSON today, CSV tomorrow, model checkpoints next week

A filesystem is the lowest-common-denominator abstraction every toolchain already understands. Adding durability, remote access, and SQL queryability makes it surprisingly capable.

## Try it

```bash
db9 create --name my-agents
```

If you can `ls` your queue and `cat` your messages, you're in good shape.
