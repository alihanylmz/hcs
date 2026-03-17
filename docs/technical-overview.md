# Technical Overview

## Project Structure

| Path | Responsibility |
| --- | --- |
| `lib/main.dart` | App bootstrap, config loading, auth gate, theme. |
| `lib/config` | Build-time runtime configuration. |
| `lib/core` | Cross-cutting infrastructure such as logging. |
| `lib/features` | Feature-scoped application and data layers. |
| `lib/models` | Shared domain models and canonical enums/constants. |
| `lib/pages` | Screen widgets and orchestration-heavy UI. |
| `lib/services` | Legacy service facade layer used by pages. |
| `lib/widgets` | Shared UI building blocks. |
| `docs` | Product, release, and operations documentation. |

## Key Service Boundaries

| Component | Responsibility |
| --- | --- |
| `TicketRepository` | Ticket CRUD, notes, storage uploads, data access. |
| `TicketNotificationCoordinator` | Ticket-related notification business rules. |
| `TicketService` | Backwards-compatible facade consumed by UI. |
| `AdminAccessController` | Loads current profile and resolves admin-area access. |
| `NotificationService` | Notification persistence and push invocation via Edge Function. |
| `UserService` | Profile and role management. |
| `UpdateService` | App version check and update prompt. |

## Core Supabase Tables

| Table | Purpose |
| --- | --- |
| `profiles` | App role, partner assignment, signature, display identity. |
| `tickets` | Main work-order record. |
| `ticket_notes` | Service and partner note history. |
| `customers` | Customer information related to tickets. |
| `partners` | Partner-company catalog. |
| `notifications` | In-app notification inbox. |
| `inventory` | Stock and critical-level tracking. |
| `teams` | Team records for Kanban collaboration. |
| `team_members` | Team membership and team role mapping. |
| `app_versions` | Update-check metadata. |
| `user_push_tokens` | Push identity mapping for notifications. |

## Operational Architecture Notes

- Supabase is the primary backend for auth, data, storage, and functions.
- OneSignal push send operations must remain server-side through `send-notification`.
- `run_local.ps1` / `run_local.bat` are the supported local launch entry points.
- `TicketStatus` is the canonical lifecycle definition and should be reused everywhere.
