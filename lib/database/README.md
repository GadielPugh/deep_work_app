# Database layer

SQLite is used to store focus sessions locally. The schema is designed so you can export data for ML training later.

## Where things live

- **Directory**: `lib/database/`
- **Schema**: `schema.dart` – table and index definitions (single source of truth).
- **Open/init**: `app_database.dart` – opens the DB in the app documents directory, runs migrations.
- **CRUD**: `session_repository.dart` – insert/query sessions; use this everywhere instead of raw SQL.

Database file path (per platform):

- **iOS**: `NSDocumentDirectory/deep_work.db`
- **Android**: app documents dir `deep_work.db`

## What is stored (one row = one focus session)

| Column             | Type    | Description |
|--------------------|---------|-------------|
| id                 | INTEGER | Primary key (auto). |
| intention          | TEXT    | Thing to accomplish. |
| category           | TEXT    | Session type: `reading`, `writing`, `coding`, `review`, `work`, `other`. |
| started_at_ms      | INTEGER | When focus was started (UTC milliseconds). |
| stopped_at_ms      | INTEGER | When focus was stopped (UTC milliseconds). |
| duration_seconds   | INTEGER | Actual focus time in seconds. |
| outcome            | TEXT    | `yes`, `partially`, or `no`. |
| reflection         | TEXT    | What helped or distracted (nullable). |
| created_at_ms      | INTEGER | Row creation time (UTC ms). |

Indexes on `started_at_ms`, `category`, and `outcome` for fast filters and time-range queries.

## Exporting for ML

Use `SessionRepository.getAllRowsForExport()` to get all rows as `List<Map<String, dynamic>>`. You can then:

- Write to a CSV (e.g. one column per field, timestamps as UTC ms or ISO strings).
- Serialize to JSON and send to a training pipeline.
- Keep one row per session so each example has: intention, category, started_at, stopped_at, duration, outcome, reflection.

No extra tables are required for training; this flat table is enough to derive features (e.g. time of day from `started_at_ms`, success from `outcome`, text from `intention` and `reflection`).
