Recently I built a small archive site for ECM album covers:

<https://ecm-archive-site.db9.workers.dev/>

The dataset is not huge—1,647 albums—but it is a very typical “small data, large text fields” problem. Each album has a cover, title, artist, catalog number, release date, recording information, and several blocks of descriptive text. The front-end is a pure cover wall, images are served from Cloudflare R2, the API lives in a Cloudflare Worker, and metadata/search are stored in db9.

At first glance this should have been easy. In practice, the first version of search felt much slower than the rest of the site.

This post is a record of how I diagnosed it, what actually helped, what did not help, and why the final result was more about reducing unnecessary work than chasing a single magic index.

## The setup

The site architecture is intentionally simple:

* Static front-end for the cover wall
* Cloudflare Worker for `/api/search`
* Cover images in R2
* Album metadata in a PostgreSQL-compatible db9 database

A quick note on db9, since it is an important part of the story: I used it here as a small hosted PostgreSQL-compatible database that was easy to query from a Worker without having to run and babysit a separate database service myself. For a site like this, that matters more than chasing some theoretical maximum benchmark.

The db9 features I actually used in this project were very down-to-earth:

* regular relational tables for album metadata
* plain SQL queries from the Worker search API
* generated columns for `search_document` and `search_vector`
* PostgreSQL full-text search primitives such as `tsvector`, `websearch_to_tsquery`, and `ts_rank_cd`
* normal btree indexes for exact-ish lookups on title, artist, and catalog
* a GIN index on the stored full-text search vector
* pgwire / `psql` access as an operational fallback when heavier DDL was awkward over the HTTP SQL API

In other words, I was not using db9 for anything exotic. I was using it for the kind of boring database features that become very powerful when you combine them carefully.

The original search implementation tried to be generous. It searched title, artist, catalog number, intro, description, background, press reactions, track text, and recording information. Ranking also tried to be smart: exact title/artist matches got more weight, fuzzy matches got less, full-text rank was mixed in as another scoring term.

That sounds reasonable. The problem was how the query was built.

## The first version: correct, but too expensive

The first version of the Worker generated SQL roughly like this:

* build `to_tsvector(...)` dynamically per row
* concatenate multiple weighted text vectors in a `LATERAL` subquery
* run both `websearch_to_tsquery('english', ...)` and `websearch_to_tsquery('simple', ...)`
* OR them together with a large set of `ILIKE '%...%'` predicates
* sort everything by a computed score

In other words: every search paid the full cost of constructing a search document, scanning large text fields, and ranking all matches on the fly.

On only 1,647 rows, that still turned out to be slow enough to be noticeable.

Measured against the live search endpoint, the original latency looked like this:

* `keith jarrett`: ~4.50s
* `ludwigsburg`: ~4.07s
* `free at last`: ~3.99s

The first lesson is a boring one, but still true: if you do enough unnecessary work, “small data” is not small anymore.

## The root causes

After tracing the whole path, the latency came from four places.

### 1. The SQL did too much work per request

The most obvious bottleneck was the database query itself. The expensive part was not the number of rows; it was repeated per-row text processing and too many fallback predicates.

I was effectively rebuilding the search index at query time.

### 2. The Worker had no edge cache for repeated queries

People search the same things over and over again: artist names, catalog numbers, recording locations. Every identical query still went all the way through the Worker and into the database.

### 3. The front-end was too eager

The search box debounced at 180ms, so typing a phrase could fire a request almost every couple of keystrokes.

### 4. The browser fallback was heavier than it needed to be

I had also added a client-side fallback that loaded the large `albums.json` file and scanned all text fields in the browser. That was useful as a safety net, but the first version was too aggressive.

## The fixes that clearly helped

The final improvement came from a combination of smaller changes.

### Precompute the search document

Instead of rebuilding the searchable text in every query, I added two generated columns to `ecm_albums`:

* `search_document`: a stored concatenation of all searchable text fields
* `search_vector`: a stored weighted `tsvector`

Conceptually it looks like this:

```sql
ALTER TABLE ecm_albums
  ADD COLUMN search_document TEXT GENERATED ALWAYS AS (
    concat_ws(E'\n',
      coalesce(title, ''),
      coalesce(artist, ''),
      coalesce(catalog, ''),
      coalesce(release_date, ''),
      coalesce(decade, ''),
      coalesce(recording_info, ''),
      coalesce(intro, ''),
      coalesce(description, ''),
      coalesce(background, ''),
      coalesce(press_reactions, ''),
      coalesce(tracks_text, '')
    )
  ) STORED;
```

and:

```sql
ALTER TABLE ecm_albums
  ADD COLUMN search_vector tsvector GENERATED ALWAYS AS (
    setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(artist, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(catalog, '')), 'A') ||
    setweight(to_tsvector('simple', coalesce(release_date, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(decade, '')), 'B') ||
    setweight(to_tsvector('simple', coalesce(recording_info, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(intro, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(background, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(press_reactions, '')), 'C') ||
    setweight(to_tsvector('english', coalesce(tracks_text, '')), 'C')
  ) STORED;
```

This changed the query shape immediately: search became “query precomputed columns” instead of “compute everything first, then search”.

### Add cheap btree support where it matters

I also added lowercased btree indexes on the fields that matter for ranking and exact-ish matches:

* `lower(title)`
* `lower(artist)`
* `lower(catalog)`

These are not glamorous, but for real user queries they matter a lot. Users often search titles, artists, and catalog numbers, not arbitrary prose buried inside a paragraph.

### Simplify the Worker query

The Worker query was rewritten to do less work:

* keep exact and near-exact matches heavily weighted
* use `search_vector` directly instead of computing vectors dynamically
* use a single `search_document ILIKE` as the broad fallback instead of many separate `ILIKE` checks
* lower the default amount of over-fetching

The interesting part is that I did **not** need a radically smarter ranker. I mostly needed a less expensive one.

### Cache identical searches at the edge

I added a cache layer in the Worker using `caches.default`.

That meant repeated searches like `keith jarrett` or `ludwigsburg` could return from the edge without hitting the database every time.

This was especially effective because search traffic on this kind of site is highly repetitive.

### Make the front-end less trigger-happy

On the client side I made four changes:

* debounce increased from 180ms to 360ms
* search requires at least 2 characters
* identical queries are cached in memory in the browser
* the large album-details JSON is no longer preloaded during idle time

I also kept the local full-text fallback only for actual API failures, instead of treating it like a normal second-stage search path.

This improved perceived speed and reduced unnecessary load at the same time.

## What the numbers looked like afterwards

After these changes, the first uncached request was already much better:

* `keith jarrett`: ~1.04s
* `ludwigsburg`: ~1.04s
* `free at last`: ~0.96s

The repeated queries, once cached, became effectively instant:

* `keith jarrett`: ~0.09s
* `ludwigsburg`: ~0.12s
* `free at last`: ~0.08s

So the practical outcome was:

* roughly a 4x improvement on cold searches
* near-instant repeated searches

For a small static-ish archive, this is exactly the kind of result I wanted.

## The GIN index story

Of course, once you introduce a `tsvector`, the next obvious move is to build a GIN index on it.

So I did:

```sql
CREATE INDEX idx_ecm_albums_search_vector
ON ecm_albums USING GIN (search_vector);
```

The index exists, and I verified that it can be used.

For example, a query like:

```sql
SELECT id
FROM ecm_albums
WHERE search_vector @@ websearch_to_tsquery('simple', 'keith jarrett')
LIMIT 20;
```

does use:

```text
Index Scan using idx_ecm_albums_search_vector on ecm_albums
```

So far, so good.

But then something interesting happened: forcing the query structure to be more “GIN-centric” did **not** make the end-to-end request faster. In one experiment, I rewrote the SQL into a UNION-based candidate pipeline to try to separate simple full-text hits, english full-text hits, and the `ILIKE` fallback more explicitly.

That version looked more “database-engineering-correct”, but on this workload it was slower in practice.

This is one of the more useful reminders from the whole exercise:

> an index being valid is not the same thing as that index dominating the real request latency.

The site is small enough that the total cost is still a mix of Worker overhead, HTTP round trips, ranking, result hydration, and rendering. GIN helps. It just was not the whole story.

So the final live query kept the simpler, faster end-to-end behavior, while still leaving the GIN index in place for the full-text path.

## Operational notes

A small but annoying operational detail: on db9, heavier DDL over the HTTP SQL API could time out with a `504 Gateway Time-out`. For the larger index/DDL operations I had to fall back to `psql` over the pgwire endpoint.

That turned out to be the more reliable path for “real database work” such as long-running `ALTER TABLE` or index creation.

## What I learned

A few takeaways from this small tuning exercise:

### 1. Small datasets can still be slow

1,647 rows is tiny. But 1,647 rows times several large text fields times per-request text-vector construction times many fallback predicates is not tiny.

### 2. Generated columns are a great fit for this kind of search

If the content changes rarely and gets queried frequently, generated search columns are a very natural solution.

### 3. Edge caching matters more than people expect

For a browse-heavy archive, repeated search terms are common. Caching the search response at the edge is one of the highest-leverage changes you can make.

### 4. Front-end restraint is performance work too

A debounced search box and a saner fallback strategy matter just as much as SQL tuning.

### 5. Do not optimize for planner aesthetics

I was tempted to keep the version that looked more obviously “index-friendly”. But the user does not care whether the plan is elegant; the user cares whether the site feels fast.

That sounds obvious, yet it is easy to forget.

## The current result

The archive is now much more pleasant to use, and the search path is simple enough that I can still reason about it when I come back later.

The live site is here again:

<https://ecm-archive-site.db9.workers.dev/>

If I revisit this later, the next likely step would be splitting the search path more aggressively:

* exact title/artist/catalog matches first
* broader full-text matching second
* potentially a dedicated lighter search projection for the Worker

But for now, the main problem is solved, and the system is comfortably fast for the scale it serves.
