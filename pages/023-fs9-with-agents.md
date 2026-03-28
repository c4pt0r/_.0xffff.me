# The Simplest Agent-to-Agent Communication: Just Use a Filesystem

Every few months, we reinvent agent communication.

A new acronym appears, a new “standard” repo hits the front page, and suddenly your two little agents “need” an RPC layer, a schema registry, a broker, and three dashboards.

But most agent systems aren’t distributed systems in the classic sense.

They’re *scripts with opinions* — brittle, iterative, and constantly changing. What they need is not a protocol. What they need is a medium that is:

- dead simple
- inspectable with boring tools
- durable across crashes
- flexible enough to hold whatever today’s payload happens to be

For a surprisingly large class of workloads, we already have that medium:

A filesystem.

---

## The problem (and why queues feel like overkill)

You have two AI agents:

- Agent A dispatches work.
- Agent B executes it.

The default playbook says: set up Redis/RabbitMQ/Kafka, define schemas, manage serialization, handle backpressure, operate the thing, debug the thing.

For two agents passing JSON tasks around, that’s often mass overkill.

---

## Files as messages

Here’s the idea: one agent writes a file, another agent watches for it.

```
Agent A writes: /inbox/task-001.json
Agent B sees:  CREATE /inbox/task-001.json
Agent B reads: {"action":"summarize","url":"https://..."}
Agent B writes: /outbox/result-001.json
Agent A sees:  CREATE /outbox/result-001.json
```

No SDKs. No protocol negotiation. No bespoke serialization layers.

The debugging story is unbeatable:

- `ls` shows queue depth
- `cat` shows payloads
- `rm` clears broken messages
- your editor is the best UI

This is not a new idea. Maildir has worked this way for decades.

### The catch: eventing and durability

Traditional filesystems give you `inotify`-style notifications, but:

- it’s local-only
- it can be lossy under load
- it doesn’t naturally work across machines/containers/regions
- you end up bolting on a separate queue anyway

So the filesystem-as-message-bus idea is great — you just need a filesystem with a *real* event stream.

---

## Enter db9’s fs9 + `fs watch`

[db9](https://db9.ai) is a serverless Postgres with a built-in filesystem (fs9). Every database comes with its own persistent, remote filesystem namespace — and it supports `fs watch`: a **cursor-based event stream** over file changes.

```bash
db9 fs watch myapp:/inbox/
00:00:00.000 CREATE /inbox/task-001.json
00:00:01.234 MODIFY /inbox/task-001.json
00:00:05.678 DELETE /inbox/temp.txt
```

What makes this different from `inotify`:

- **Durable**: events are stored as a stream. If your agent crashes, it can resume from its last cursor.
- **Remote**: your “/inbox” is cloud-backed. Two agents on different machines can coordinate without VPN gymnastics.
- **Queryable**: files can be queried from SQL (so your “queue” is also a dataset).

> The exact ordering/retention semantics depend on the stream implementation and how you structure directories. For agent workloads, the key properties are: **resume** and **inspect**.

---

## A concrete example: dispatcher + worker

Let’s build a two-agent pipeline:

- a **dispatcher** that drops URL tasks
- a **worker** that picks them up, processes them, and writes results

### Dispatcher: write tasks (SQL)

Write a task JSON file into a “pending” directory:

```sql
SELECT fs9_write(
  '/tasks/pending/t-' || gen_random_uuid() || '.json',
  '{"url":"https://example.com/article","requested_by":"user-42"}'
);
```

### Worker: watch + claim + process (CLI + SQL)

If you run multiple workers, you need **claim semantics**.
The simplest pattern: when a worker sees a task, it **atomically moves** it from `/pending/` to `/processing/`. If the move succeeds, it owns the task.

```bash
db9 fs watch myapp:/tasks/pending/ --json | while read -r event; do
  path=$(echo "$event" | jq -r '.path')
  type=$(echo "$event" | jq -r '.event_type')

  [ "$type" = "CREATE" ] || continue

  processing_path=$(echo "$path" | sed 's|/pending/|/processing/|')

  # Claim by atomic move. If it fails, someone else claimed it.
  if ! db9 sql myapp -q "SELECT fs9_move('$path', '$processing_path')" --output raw >/dev/null 2>&1; then
    continue
  fi

  task=$(db9 sql myapp -q "SELECT fs9_read('$processing_path')" --output raw)
  url=$(echo "$task" | jq -r '.url')

  # Your agent logic here
  summary="Summarized content of $url"

  done_path=$(echo "$processing_path" | sed 's|/processing/|/done/|')
  db9 sql myapp -q "SELECT fs9_write('$done_path', $(jq -Rn --arg s \"$summary\" '$s'))"

  db9 sql myapp -q "SELECT fs9_remove('$processing_path')"
done
```

If you want retries/leases/timeouts, you can layer in a Postgres table for state.
The point is: you don’t *start* with Kafka.

---

## Why this works well for agents

Most agents don’t need ultra-low latency or massive throughput. They need:

1. **Simplicity** — fewer moving parts when the LLM makes a dumb call
2. **Inspectability** — you can see the entire system state with `ls` and `cat`
3. **Persistence** — if an agent dies mid-task, the message is still there
4. **Flexibility** — today JSON tasks, tomorrow CSV batches, next week model checkpoints

A filesystem is the lowest-common-denominator abstraction every toolchain already understands.

---

## The SQL escape hatch (where it gets fun)

Because fs9 is queryable from SQL, you can run ops and analytics on your “queue” without ETL:

```sql
-- How many tasks are pending?
SELECT count(*) FROM extensions.fs9('/tasks/pending/');

-- What's the oldest unprocessed task?
SELECT path, mtime
FROM extensions.fs9('/tasks/pending/')
ORDER BY mtime ASC
LIMIT 1;

-- Read pending tasks as structured data (depending on your file format)
SELECT line->>'url' AS url, line->>'requested_by' AS requester
FROM extensions.fs9('/tasks/pending/*.json');
```

Your message bus becomes queryable, auditable, and scriptable with the same database you already rely on.

---

## Patterns that fall out naturally

- **Request/Response**: `/requests/{id}.json` → `/responses/{id}.json`
- **Fan-out workers**: many workers watch `/tasks/pending/`, claim via atomic move
- **Event log**: append-only writes to `/events/YYYY-MM-DD/`, consumers keep cursors
- **Config reload**: watch `/config/settings.json`, reload on modify
- **Batch pipelines**: write CSV/JSONL shards, let workers process per-file

---

## Tradeoffs (be honest)

| Dimension | Filesystem messages (fs9) | Broker (Kafka/RabbitMQ/etc.) |
|---|---|---|
| Best for | “agent scale” pipelines, human-debuggable ops | high throughput, complex routing, many consumers |
| Inspectability | `ls/cat` level obvious | requires broker tooling and dashboards |
| Durability | durable files + durable watch cursor | durable logs/queues by design |
| Claim semantics | atomic rename/move (simple) | consumer groups / ack / offsets (powerful) |
| Ordering | don’t assume global ordering | strong per-partition ordering |
| Exactly-once | you build it (or avoid needing it) | supported patterns exist (still tricky) |
| Ops complexity | low | higher (but more capabilities) |

---

## When you should still use Kafka (or a real broker)

Use a broker when you truly need broker-shaped features:

- 100K msg/sec or internet-scale fanout
- multiple consumer groups with complex topologies
- strict partitioning and ordering guarantees
- mature ecosystem integrations and connectors
- formalized replay semantics across many services

If your workload is “a handful of agents passing tasks and artifacts around”, you’ll often get 80% of the value with 20% of the complexity by using files.

---

## Closing thought

Agent communication doesn’t have to be a protocol design exercise.

Most of the time, it’s a bookkeeping problem:
“What work is queued?”, “What’s stuck?”, “What did we send?”, “What did we get back?”, “Can we replay it?”

A filesystem answers those questions with the most boring tools imaginable. Add durability, remote access, a real event stream, and SQL queryability — and you get a message bus that’s easy to debug *even when the agent logic is chaotic*.

Sometimes the best infrastructure is the kind that looks almost too simple.

---

## Try it (in 5 minutes)

1) Create a db:

```bash
db9 create --name my-agents
```

2) Start a worker that watches `/tasks/pending/` and claims tasks by moving them to `/tasks/processing/`.

3) Drop a JSON task into `/tasks/pending/`.

If you can `ls` your queue and `cat` your messages, you’re already ahead of most “agent protocol” stacks.
