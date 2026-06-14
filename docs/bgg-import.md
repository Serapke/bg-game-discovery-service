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

Configuration via env vars:

| Variable | Default |
|---|---|
| `BGG_API_BASE_URL` | `https://boardgamegeek.com/xmlapi2/` |
| `BGG_API_TIMEOUT` | `10` seconds |
| `BGG_API_OPEN_TIMEOUT` | `5` seconds |
| `BGG_API_TOKEN` | _(optional bearer token)_ |

Errors raised: `TimeoutError`, `ApiError`, `ParseError`.

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
