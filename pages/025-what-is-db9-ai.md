db9.ai is serverless Postgres designed for AI agents.

That sounds like a small sentence, but it implies a fairly different product shape from the usual "managed database" story. Traditional databases assume a human developer, an application server, a deployment pipeline, a cloud account, and a pile of surrounding infrastructure. Agents don't work that way. They want to create state quickly, inspect it directly, branch it safely, attach files to it, and tear it down when the run is over.

The shortest description is:

> db9 is a workspace for agent state: SQL tables, files, vectors, jobs, and environment branches in one place.

## Why agents need a different database interface

An agent is not just a web app with a different UI. A useful agent does a lot of small operational things:

- creates temporary environments
- stores intermediate results
- writes logs, reports, and artifacts
- remembers structured state
- retrieves context from documents
- calls tools from shell scripts
- retries work after failure
- hands state to another agent

For humans, a database is usually something hidden behind an application. For agents, the database often *is* the workbench.

That means the interface matters. Agents need something they can use from the terminal without ceremony:

```bash
db9 create my-workspace
db9 sql my-workspace -q "select now()"
db9 fs write my-workspace:/notes/summary.md summary.md
```

No console clicking. No Terraform module. No waiting for a cloud project to be prepared. The database should appear when work starts and disappear when the work is done.

## Postgres as the durable core

Postgres is still the right center of gravity.

It gives agents a durable and well-understood place to put structured state:

- task queues
- run metadata
- user profiles
- extracted entities
- permissions
- audit trails
- relational facts
- JSONB documents
- vectors and search indexes

The important part is not just compatibility. It is that SQL gives an agent a precise language for asking questions about its own work.

Instead of inventing a bespoke memory API, an agent can query:

```sql
select id, status, updated_at
from runs
where status in ('pending', 'failed')
order by updated_at asc
limit 20;
```

That is a better substrate than a pile of opaque blobs.

## Files next to tables

But agents do not only produce rows. They produce files:

- transcripts
- markdown reports
- source snapshots
- CSV exports
- screenshots
- model outputs
- scratch notes
- build artifacts

Putting all of that in S3 is possible, but it creates another system to configure, secure, index, and remember. db9's file layer, fs9, makes files part of the same workspace as the database.

The key idea is simple: structured state belongs in Postgres; unstructured context and artifacts belong in files; both should live under the same operational boundary.

So an agent can keep:

```text
/tables/runs                 -> SQL metadata
/files/reports/final.md      -> final report
/files/context/source.txt    -> raw source material
/files/artifacts/chart.png   -> generated output
```

And because the file layer is queryable and scriptable, the debugging story stays simple. `ls`, `cat`, SQL, and CLI commands are enough to inspect what happened.

## Branching the whole environment

One of the strongest ideas in db9 is that branching should apply to the environment, not only to tables.

For agent work, a branch is useful when you want to say:

> Try this risky operation against realistic state, but don't damage the original workspace.

A useful branch should include data, files, permissions, jobs, and the rest of the working context. That lets agents test migrations, run experiments, review PRs, or validate customer scenarios without constructing fake fixtures from scratch.

This is especially important for autonomous workflows. Agents make mistakes. A good backend makes those mistakes cheap, isolated, and inspectable.

## Built-in primitives for agent applications

db9 is not trying to replace every piece of infrastructure. It is trying to remove the most common glue that agent applications keep rebuilding.

At a high level, the built-in primitives are:

- **Serverless Postgres** — create and query databases from the CLI.
- **fs9 files** — store, read, and organize artifacts beside SQL state.
- **Vector search and embeddings** — keep retrieval close to the data.
- **HTTP from SQL** — call external services without building another worker for every tiny integration.
- **Cron and jobs** — schedule recurring work without leaving the workspace.
- **Branching** — clone environments for testing, review, and experiments.
- **Type generation** — let applications and agents consume schemas more safely.

The product direction is agent-native, but the primitives are boring on purpose. Postgres, files, SQL, cron, HTTP, types. These are the things that compose.

## What this enables

A few patterns become much easier when the backend is shaped this way.

### Personal assistants and copilots

Store user preferences, task state, and long-term memory in tables. Store transcripts, uploaded files, and generated summaries in fs9. Use SQL to answer "what do we know?" and files to preserve raw context.

### Research and coding agents

Keep source documents as files. Store chunks, metadata, citations, and vectors in Postgres. Let the agent retrieve grounded context and write final reports into the same workspace.

### Multi-agent automation

Use tables for run state and coordination. Use files as handoff artifacts between agents. Use environment branches to let one agent test a change while another reviews it.

### Product backends

For small applications, db9 can be the first backend: SQL database, file storage, scheduled jobs, and CLI operations without the usual cloud scaffolding.

## The philosophy

The philosophy behind db9 is not "make a database smarter." It is closer to:

> Give agents a backend they can understand and operate by themselves.

That means the system should be:

- **CLI-first** — usable from a shell, script, or agent loop.
- **Inspectable** — state should be easy to list, query, and debug.
- **Composable** — based on primitives that already work well together.
- **Branchable** — safe experimentation should be a default workflow.
- **Durable** — agent runs should survive crashes, retries, and handoffs.

If the next generation of software is partially written and operated by agents, then the backend has to become more agent-operable too.

db9.ai is one attempt at that shape: Postgres as the core, files as the natural companion, and environment-level workflows built for agents from the start.

Try it here: <https://db9.ai>
