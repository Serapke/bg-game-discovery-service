# BGG Game Import

Games are imported on-demand from the [BoardGameGeek XML API2](https://boardgamegeek.com/wiki/page/BGG_XML_API2). There is no scheduled bulk import — the pipeline is triggered entirely by search requests.

## Flow

```
GET /api/v1/board_games/search?name=<query>
    └─ BoardGames::SearchQuery              app/queries/board_games/search_query.rb
        ├─ Search local DB
        └─ If no results → BggApi::SearchImporter.import_from_search(query)
                              app/services/bgg_api/search_importer.rb
            ├─ BggApi::Client.search(query)            → BGG API (search)
            ├─ BggApi::GameImporter.import_by_ids(first_20)  [synchronous]
            │       app/services/bgg_api/game_importer.rb
            │       └─ BggApi::Client.get_details(ids) → BGG API (thing)
            │           For each game:
            │           ├─ Create/update BoardGame
            │           ├─ Create/link GameType (with BGG rankings)
            │           ├─ Create/link GameCategory
            │           ├─ Create BggBoardGameAssociation
            │           └─ Create BoardGameRelation edges
            └─ BggGameImportJob.perform_later(remaining + related_ids)  [async]
                    app/jobs/bgg_game_import_job.rb
                    └─ Same import flow, batched in groups of 20
```

## Components

### `BggApi::Client` — `app/services/bgg_api/client.rb`

Low-level Faraday HTTP client for the BGG XML API2.

| Method | BGG endpoint | Purpose |
|---|---|---|
| `search(query)` | `/search` | Find games by name, returns id/name/year |
| `get_details(ids)` | `/thing` | Fetch full data for up to 20 BGG IDs |
| `get_recommendations(id)` | `api.geekdo.com/api/geekitem/recs` | Recommended games for a game |
| `get_videos(id)` | `api.geekdo.com/api/videos` | Instructional videos for a game (page 1, sorted by popularity) |

Configuration via env vars:

| Variable | Default |
|---|---|
| `BGG_API_BASE_URL` | `https://boardgamegeek.com/xmlapi2/` |
| `BGG_API_TIMEOUT` | `10` seconds |
| `BGG_API_OPEN_TIMEOUT` | `5` seconds |
| `BGG_API_TOKEN` | _(optional bearer token)_ |

Errors raised: `TimeoutError`, `ApiError`, `ParseError`.

### `YoutubeApi::Client` — `app/services/youtube_api/client.rb`

Low-level Faraday client for the [YouTube Data API v3](https://developers.google.com/youtube/v3/docs/videos/list). Used to enrich imported video rows (see phase 2 below).

| Method | YouTube endpoint | Purpose |
|---|---|---|
| `get_video_details(ids)` | `/videos` | Fetch stats/status for up to 50 YouTube IDs (1 quota unit/call) |

Configuration via env vars:

| Variable | Default |
|---|---|
| `YOUTUBE_API_BASE_URL` | `https://www.googleapis.com/youtube/v3/` |
| `YOUTUBE_API_TIMEOUT` | `10` seconds |
| `YOUTUBE_API_OPEN_TIMEOUT` | `5` seconds |
| `YOUTUBE_API_KEY` | **required for enrichment** — enable "YouTube Data API v3" in Google Cloud and create an API key |

Errors raised: `TimeoutError`, `ApiError`, `ParseError`. Without a valid `YOUTUBE_API_KEY`, enrichment fails soft (see below) — the core BGG import is never blocked.

### Video enrichment (phase 2)

During import, `GameImporter` fetches a game's instructional videos via `BggApi::Client#get_videos` — which calls BGG's paginated videos AJAX endpoint (`api.geekdo.com/api/videos`, `gallery=instructional&sort=hot`, page 1). This replaces the old `thing?videos=1` block, which was hard-capped at ~15 videos and ignored paging (a popular game like Carcassonne has hundreds). The client keeps only English, YouTube-hosted videos. `GameImporter#sync_videos` upserts these as rows, then calls `YoutubeApi::Client#get_video_details` to augment each with `duration_seconds`, `view_count`, `like_count`, `comment_count`, `thumbnail_url`, and `enriched_at`.

Video fetching fails soft too: if the videos AJAX endpoint errors, the game import still succeeds with no videos synced this run (retried on the next import).

- Videos that YouTube reports as non-public (`privacyStatus != "public"`) or not fully processed (`uploadStatus != "processed"`), that are absent from the response (deleted), or that have fewer than `MIN_VIDEO_VIEW_COUNT` (10,000) views are **removed** from the table — only public, playable, worth-watching videos are kept.
- If the YouTube call fails (quota exceeded, timeout, network), enrichment **fails soft**: the link-only row is kept with `enriched_at` null and no rows are deleted. The core BGG import always succeeds; enrichment retries on the next import/refresh of that game.
- Enrichment runs at import time only — a game refresh (`force_update`) re-enriches. There is no periodic re-sync, so view/like counts reflect the last import.

### `BggApi::GameImporter` — `app/services/bgg_api/game_importer.rb`

Core persistence layer. Accepts up to 20 BGG IDs, fetches details, and writes to the DB inside a single transaction.

Returns:

```ruby
{
  imported:    [{ bgg_id, board_game_id, name, rating, year_published }],
  updated:     [...],
  skipped:     [{ bgg_id, name, reason }],
  failed:      [{ bgg_id, error }],
  related_ids: [...]   # BGG IDs discovered via game links, fed into the next async job
}
```

Options: `force_update: true` re-imports existing games; `dry_run: true` returns unsaved records.

### `BggApi::SearchImporter` — `app/services/bgg_api/search_importer.rb`

Orchestrator. Imports the first 20 search results synchronously, then enqueues `BggGameImportJob` for the remainder plus any `related_ids` returned by the sync import.

### `BggGameImportJob` — `app/jobs/bgg_game_import_job.rb`

ActiveJob backed by Solid Queue (polls DB every 1 s, 3 worker threads by default, configurable via `JOB_CONCURRENCY`).

- Batches IDs in groups of 20
- `retry_on TimeoutError, ApiError` — 3 attempts, exponential backoff
- `discard_on ImportError` — validation failures are not retried

## Data Models

| Model | Table | Purpose |
|---|---|---|
| `BoardGame` | `board_games` | Central game entity (name, player counts, times, rating, complexity) |
| `BggBoardGameAssociation` | `bgg_board_game_associations` | BGG ID ↔ local `board_game_id` mapping (unique) |
| `BoardGameRelation` | `board_game_relations` | Typed edges: `expands`, `contains`, `reimplements`, `integrates_with` |
| `GameType` | `game_types` | BGG game type (strategy, family, thematic, …) with optional BGG ranking |
| `GameCategory` | `game_categories` | Free-form tags from BGG (Economic, Negotiation, …) |

## Scheduling

Only one recurring task is configured (`config/recurring.yml`): an hourly Solid Queue cleanup job. No recurring import tasks exist — imports are entirely demand-driven.
