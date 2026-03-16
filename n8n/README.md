# Telegram → Supabase (Tags + Semantic Search)

Send any message to your Telegram bot and n8n will:
1. Extract the message text
2. Use GPT-4o-mini to auto-generate tags
3. Generate a vector embedding (OpenAI `text-embedding-ada-002`)
4. Store everything in Supabase
5. Reply to you with the saved tags

---

## Architecture

```
Telegram message
      │
      ▼
n8n Telegram Trigger
      │
      ▼
Extract Message text / chat metadata
      │
      ▼
GPT-4o-mini → generate tags (JSON array)
      │
      ▼
OpenAI Embeddings API → 1536-dim vector
      │
      ▼
Supabase REST API → INSERT into notes table
      │
      ▼
Telegram reply → "✅ Saved! #tag1 #tag2 ..."
```

---

## Setup

### 1. Supabase

1. Go to your Supabase project → **SQL Editor**
2. Run the contents of `../supabase/schema.sql`
3. This creates the `notes` table, pgvector index, and helper functions

Note down your:
- **Project URL**: `https://<project-ref>.supabase.co`
- **Service Role Key**: Settings → API → `service_role` key (keep secret)

### 2. Telegram Bot

1. Chat with [@BotFather](https://t.me/botfather) on Telegram
2. Create a new bot: `/newbot`
3. Copy the **Bot Token**

### 3. OpenAI API Key

Get your key from https://platform.openai.com/api-keys

### 4. n8n Credentials

In n8n, create the following credentials:

| Name | Type | Value |
|------|------|-------|
| `Telegram Bot` | Telegram API | Your bot token |
| `OpenAI API` | OpenAI API | Your OpenAI key |
| `OpenAI Bearer Token` | HTTP Header Auth | Header: `Authorization`, Value: `Bearer sk-...` |
| `Supabase Service Key` | HTTP Header Auth | Header: `apikey`, Value: your service role key |

### 5. Import the Workflow

1. In n8n: **Workflows → Import from file**
2. Select `telegram-supabase-workflow.json`
3. Update credential references in each node to match the credentials you created
4. Update the `Insert into Supabase` node URL to use your Supabase project URL:
   - Change `https://YOUR_PROJECT.supabase.co/rest/v1/notes`
5. **Activate** the workflow

### 6. Set Telegram Webhook

n8n sets the webhook automatically when you activate the workflow. If it doesn't work, trigger it manually:

```
https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook?url=<YOUR_N8N_WEBHOOK_URL>
```

The n8n webhook URL appears in the Telegram Trigger node settings.

---

## Semantic Search

Once data is in Supabase, you can search semantically:

```sql
-- First embed your query using the same model (from your app/n8n)
-- Then call:
select * from search_notes(
  '[0.012, -0.034, ...]'::vector,   -- your query embedding
  0.75,                              -- similarity threshold (0-1)
  5                                  -- max results
);
```

Or filter by tag:

```sql
select * from search_notes_by_tag('productivity');
```

---

## Supabase Table Structure

| Column | Type | Description |
|--------|------|-------------|
| `id` | uuid | Primary key |
| `content` | text | Original message text |
| `tags` | text[] | Auto-generated tags |
| `embedding` | vector(1536) | Semantic vector |
| `source` | text | Always `telegram` |
| `telegram_chat_id` | bigint | Telegram chat ID |
| `telegram_message_id` | bigint | Telegram message ID |
| `created_at` | timestamptz | Insert timestamp |
