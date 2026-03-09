# DeepFocus Architecture

This project follows the **UI → State Management → Service** layered architecture.

## Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  UI Layer                                                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ Home page UI    │  │ Sessions UI     │  │ Insights UI     │  ...         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘              │
│           │ Event              │ Event              │ Event                  │
└───────────┼────────────────────┼────────────────────┼────────────────────────┘
            ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  State Management Layer                                                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐              │
│  │ HomePageState   │  │ SessionsPage    │  │ InsightsPage    │              │
│  │                 │  │ State           │  │ State           │              │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘              │
│           │                    │                    │                        │
│           │         ┌──────────┴──────────┐         │                        │
│           └────────►│ SessionsState       │◄────────┘                        │
│                     │ (session list)      │                                  │
│                     └──────────┬──────────┘                                  │
└────────────────────────────────┼────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  Service Layer                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │ SessionStorageService (abstract)                                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│       │                    │                    │                            │
│       ▼                    ▼                    ▼                            │
│  LocalSessionStorage   FakeSessionStorage   (RemoteStorage)                  │
│  (SQLite)              (tests)              (future)                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Directory layout

| Layer | Path | Description |
|-------|------|-------------|
| **Models** | `lib/models/` | Shared data types: `Session`, `CompletionStatus`, `InsightsData` |
| **UI** | `lib/ui/` | Pages and widgets. Sends **events**, receives **new state** |
| **State** | `lib/state/` | Page logic. Processes events, talks to Storage, `notifyListeners()` |
| **Service** | `lib/services/` | Storage abstraction and implementations |
| **Database** | `lib/database/` | SQLite schema and repository (used by LocalSessionStorageService) |

## Flow

1. **UI** sends an event (e.g. `load`, `saveSession`, `setFilter`).
2. **State** handles the event: calls `SessionStorageService`, updates internal state, calls `notifyListeners()`.
3. **UI** rebuilds on new state (via `addListener` / `setState`).

## Key files

- `lib/services/app_services.dart` – Central service wiring (swap `sessionStorage` for tests).
- `lib/state/sessions_state.dart` – Single source of truth for the session list.
- `lib/state/sessions_page_state.dart` – History page filters and search.
- `lib/state/home_page_state.dart` – Home page metrics (today’s focus).
- `lib/state/insights_page_state.dart` – Insights charts and stats.
