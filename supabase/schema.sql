-- Enable pgvector extension for semantic search
create extension if not exists vector;

-- Table to store Telegram messages with tags and vector embeddings
create table if not exists notes (
  id          uuid primary key default gen_random_uuid(),
  content     text        not null,
  tags        text[]      not null default '{}',
  embedding   vector(1536),           -- OpenAI text-embedding-ada-002 dimensions
  source      text        not null default 'telegram',
  telegram_chat_id bigint,
  telegram_message_id bigint,
  created_at  timestamptz not null default now()
);

-- Index for fast vector similarity search (cosine distance)
create index if not exists notes_embedding_idx
  on notes
  using ivfflat (embedding vector_cosine_ops)
  with (lists = 100);

-- Index for tag filtering
create index if not exists notes_tags_idx
  on notes using gin (tags);

-- Full-text search index on content
create index if not exists notes_content_fts_idx
  on notes
  using gin (to_tsvector('english', content));

-- -------------------------------------------------------
-- Helper function: semantic search
-- Usage:
--   select * from search_notes('your query embedding here', 0.7, 5);
-- -------------------------------------------------------
create or replace function search_notes(
  query_embedding vector(1536),
  similarity_threshold float default 0.7,
  match_count        int     default 10
)
returns table (
  id         uuid,
  content    text,
  tags       text[],
  similarity float,
  created_at timestamptz
)
language sql stable
as $$
  select
    n.id,
    n.content,
    n.tags,
    1 - (n.embedding <=> query_embedding) as similarity,
    n.created_at
  from notes n
  where 1 - (n.embedding <=> query_embedding) > similarity_threshold
  order by n.embedding <=> query_embedding
  limit match_count;
$$;

-- -------------------------------------------------------
-- Helper function: search by tag
-- -------------------------------------------------------
create or replace function search_notes_by_tag(tag text)
returns setof notes
language sql stable
as $$
  select * from notes where tags @> array[tag] order by created_at desc;
$$;
