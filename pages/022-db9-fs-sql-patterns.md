This is a practical, db9-flavored pattern for building agent workflows where **artifacts stay as files** but **state stays queryable**.

## What db9 is (the 20-second version)
db9 is PostgreSQL (wire-compatible) plus a set of compiled-in extensions aimed at agent workloads:

- **fs9**: query/read/write files from SQL, and expose CSV/JSONL/Parquet as relations
- **embedding + vector**: generate embeddings server-side with `embedding()` and search with pgvector operators + HNSW
- **http + pg_cron + branching**: API calls, scheduling, and safe experiments (all close to the data)

In practice: keep agent outputs as **real files** (logs/markdown/diffs), keep indexes/governance as **tables** (JSONB/FTS/vectors), and use **SQL as the glue**.

## The core idea
Agent systems accumulate two kinds of state:

- **Artifacts (file-shaped):** prompts, plans, logs, traces, cached responses, patches, reports.
- **Queryable state (table-shaped):** metadata, dedup keys, chunk indexes, run status.

Most stacks split these across object storage + DB + vector DB + queue, then glue them in application code. db9’s model is simpler: **files + Postgres, unified by SQL**.

## 1) Files are not blobs: they participate in SQL
Minimal examples:

```sql
create extension if not exists fs9;

-- write/read/inspect an artifact
select extensions.fs9_write('/reports/hello.txt', 'hello from db9');
select extensions.fs9_read('/reports/hello.txt');
select extensions.fs9_exists('/reports/hello.txt'), extensions.fs9_size('/reports/hello.txt');

-- treat files as query sources
select * from extensions.fs9('/data/users.csv') limit 5;
select _line_number, line
from extensions.fs9('/logs/run.jsonl')
where line->>'level' = 'error';
```

Once files are queryable as relations, “debugging” stops being a bespoke UI problem. It becomes SQL.

## 2) A compact pipeline (docs → chunks → retrieval → report)
This is the minimal RAG-ish loop: **files for source + output**, **tables for indexing + retrieval**.

### Step A — Source docs live as files
If you already have docs, great. If you want this to be copy/paste runnable, just write a tiny markdown doc into the db9 filesystem first:

```sql
create extension if not exists fs9;

select extensions.fs9_write(
  '/docs/agents/intro.md',
  $$
# Agents + Files + SQL

Agents produce artifacts (plans/logs/reports). Files are the natural format.

Postgres turns this into a computable system: query, rank, dedup, schedule.
  $$
);
```

### Step B — Materialize a chunk index in Postgres
Keep the table boring (that’s the point):

```sql
create table if not exists doc_chunks (
  path text not null,
  chunk_idx int not null,
  content text not null,
  meta jsonb not null default '{}',
  primary key (path, chunk_idx)
);
```

Chunking in db9 is built-in: `CHUNK_TEXT(content, max_chars, overlap_chars, title)` is markdown-aware and prefers natural breakpoints.

```sql
insert into doc_chunks (path, chunk_idx, content, meta)
select
  '/docs/agents/intro.md' as path,
  c.chunk_index as chunk_idx,
  c.chunk_text as content,
  jsonb_build_object('source','docs','chunk_pos',c.chunk_pos)
from CHUNK_TEXT(
  content => extensions.fs9_read('/docs/agents/intro.md'),
  max_chars => 3600,
  overlap_chars => 540,
  title => 'agents/intro'
) as c
on conflict (path, chunk_idx) do update
set content = excluded.content,
    meta = excluded.meta;
```

### Step C — Retrieval with FTS (fast, debuggable)

```sql
alter table doc_chunks
add column if not exists search_vector tsvector
generated always as (to_tsvector('english', coalesce(content, ''))) stored;

create index if not exists doc_chunks_search_gin
on doc_chunks using gin(search_vector);

select path, chunk_idx, content
from doc_chunks
where search_vector @@ plainto_tsquery('english', 'filesystem sql agents')
order by ts_rank_cd(search_vector, plainto_tsquery('english', 'filesystem sql agents')) desc
limit 8;
```

### (Optional) Semantic retrieval with built-in embeddings
If you want embeddings, db9 supports server-side generation via `embedding()` (no separate embedding service). *(Per db9 docs, `embedding()` typically requires admin/superuser permissions.)*

```sql
create extension if not exists embedding;
create extension if not exists vector;

-- default model returns 1024-d vectors
alter table doc_chunks add column if not exists vec vector(1024);

update doc_chunks
set vec = embedding(content)::vector(1024)
where vec is null;

-- cosine distance (lower = more similar)
select path, chunk_idx, content
from doc_chunks
order by vec <=> embedding('how do agents use filesystem + postgres?')::vector(1024)
limit 8;

-- convenience helpers: auto-embed the query text
select path, chunk_idx, content
from doc_chunks
order by VEC_EMBED_COSINE_DISTANCE(vec, 'how do agents use filesystem + postgres?')
limit 8;
```


### Step D — Write the answer as a file, track it as a row

```sql
create table if not exists artifacts (
  path text primary key,
  kind text not null,
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);

select extensions.fs9_write('/reports/db9-fs-sql-patterns.md', '# Notes\n\n...generated summary...\n');

insert into artifacts (path, kind, meta)
values ('/reports/db9-fs-sql-patterns.md', 'report', '{"inputs":["/docs/agents/intro.md"]}'::jsonb)
on conflict (path) do update
set meta = excluded.meta;

select a.path, extensions.fs9_read(a.path)
from artifacts a
where a.kind = 'report'
order by a.created_at desc
limit 1;
```

## Why this composition works
- **Files** keep artifacts transparent and inspectable.
- **Tables** keep structure queryable and enforceable.
- **SQL** is the workflow language (filter/join/rank/dedup) close to the data.

That’s the operational win: agent state stays visible, and the “why did it do that?” questions become answerable with SQL.
