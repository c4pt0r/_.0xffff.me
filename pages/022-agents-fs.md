This is the practical case for combining filesystem artifacts with Postgres state in one runtime (db9-style).

Agent systems accumulate two kinds of state:

- **Artifacts** (file-shaped): prompts, plans, logs, traces, cached responses, patches, reports.
- **Queryable state** (table-shaped): metadata, dedup keys, chunk indexes, run status, schedules.

Most stacks split these across object storage + DB + vector DB + a queue, then glue them together in application code. That works, but inspection/debugging becomes slow and expensive.

**db9’s model is: keep artifacts as files, keep structure in Postgres, and let SQL operate across both.**

## 1) Files are not blobs: they participate in SQL
Write and read artifacts directly:

```sql
select fs9_write('/reports/hello.txt', 'hello from db9');
select fs9_read('/reports/hello.txt');
select fs9_exists('/reports/hello.txt'), fs9_size('/reports/hello.txt');
```

Turn common formats into relations via **fs9**:

```sql
-- CSV as a table
select * from extensions.fs9('/data/users.csv') limit 5;

-- JSONL logs (assuming `line` is json)
select _line_number, line
from extensions.fs9('/logs/run.jsonl')
where line->>'level' = 'error';
```

Once files can be queried as relations, you can build pipelines where artifacts remain inspectable files, but the “working index” lives in Postgres.

## 2) A minimal end-to-end pipeline (docs → chunks → retrieval → report)
Below is a compact RAG-ish workflow that uses **files for source + output**, and **tables for indexing + retrieval**.

### Step A — Drop source docs as files
Assume you upload markdown files into something like:

- `/docs/agents/*.md`

(How you upload doesn’t matter; the point is the source remains a file.)

### Step B — Chunk into a table (the compute layer)
Create a chunk table with metadata. Keep it boring and queryable.

```sql
create table if not exists doc_chunks (
  id bigserial primary key,
  path text not null,
  chunk_idx int not null,
  content text not null,
  meta jsonb not null default '{}',
  created_at timestamptz not null default now(),
  unique (path, chunk_idx)
);

create index if not exists doc_chunks_path_idx on doc_chunks(path);
create index if not exists doc_chunks_meta_gin on doc_chunks using gin(meta);
```

Now ingest chunks from the filesystem. The exact chunking function name may vary by environment; conceptually:

```sql
-- PSEUDO-SQL: replace CHUNK_TEXT / fs9_read with your actual db9 functions
insert into doc_chunks (path, chunk_idx, content, meta)
select
  '/docs/agents/intro.md' as path,
  c.chunk_index,
  c.chunk_text,
  jsonb_build_object('kind','md','source','docs')
from CHUNK_TEXT(fs9_read('/docs/agents/intro.md')) c
on conflict (path, chunk_idx) do update
set content = excluded.content,
    meta = excluded.meta;
```

This is the important point: **source stays a file**, but you materialize a query index as a table.

### Step C — Add full-text search (cheap, debuggable, good enough)
Embeddings are optional on day one. FTS gives you fast iteration.

```sql
alter table doc_chunks
add column if not exists search_vector tsvector
generated always as (to_tsvector('english', coalesce(content, ''))) stored;

create index if not exists doc_chunks_search_gin
on doc_chunks using gin(search_vector);
```

Retrieve:

```sql
select path, chunk_idx, content,
       ts_rank_cd(search_vector, plainto_tsquery('english', 'filesystem sql agents')) as score
from doc_chunks
where search_vector @@ plainto_tsquery('english', 'filesystem sql agents')
order by score desc
limit 8;
```

### Step D — (Optional) Add embeddings for semantic retrieval
If your environment supports an embedding function, store vectors per chunk.

```sql
-- Optional: requires a vector type + embedding function
alter table doc_chunks add column if not exists embedding vector;

-- PSEUDO-SQL: replace EMBED_TEXT(model, text) with your function
update doc_chunks
set embedding = EMBED_TEXT('titan-v2', content)
where embedding is null;

-- Similarity search (PSEUDO-SQL for operator)
select path, chunk_idx, content
from doc_chunks
order by embedding <=> EMBED_TEXT('titan-v2', 'how do agents use filesystem + postgres?')
limit 8;
```

The point is not the specific model/operator. The point is: **it’s still Postgres + SQL**, not a separate vector service.

### Step E — Write the output report back as a file
Generated output is an artifact. Keep it as a file and register it.

```sql
create table if not exists artifacts (
  id bigserial primary key,
  path text not null unique,
  kind text not null,
  meta jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- Write report
select fs9_write(
  '/reports/agents-fs.md',
  '# Notes\n\n...generated summary here...\n'
);

insert into artifacts (path, kind, meta)
values (
  '/reports/agents-fs.md',
  'report',
  '{"topic":"agents","inputs":["/docs/agents/*.md"]}'
)
on conflict (path) do update
set meta = excluded.meta;

-- Query latest report + read it
select a.path, fs9_read(a.path)
from artifacts a
where a.kind = 'report'
order by a.created_at desc
limit 1;
```

## Why this composition works
- **Files** remain the honest, inspectable artifacts (inputs, outputs, traces).
- **Tables** hold the query index and governance state.
- **SQL** does the filtering, joins, ranking, dedup, and scheduling close to the data.

This isn’t about “agents love X”. It’s about making an agent runtime **operable**: you can inspect every artifact, and you can query every decision.
