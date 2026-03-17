# Ticket Lifecycle

Canonical source file: [lib/models/ticket_status.dart](/c:/CODE/flutter_project/istakip_app/lib/models/ticket_status.dart)

## Core Flow

1. `draft`
2. `open`
3. `in_progress`
4. `panel_done_stock`
5. `panel_done_sent`
6. `done`
7. `archived`

Optional terminal branch:

- `cancelled`

## Status Semantics

| Status | Label | Meaning |
| --- | --- | --- |
| `draft` | Taslak | Prepared but not yet visible to standard operations. |
| `open` | Acik | Active work item waiting to be handled. |
| `in_progress` | Serviste | Work is currently being executed. |
| `panel_done_stock` | Panosu Yapildi Stokta | Panel work completed and waiting in stock. |
| `panel_done_sent` | Panosu Yapildi Gonderildi | Panel work completed and dispatched. |
| `done` | Is Tamamlandi | Operational work is complete. |
| `archived` | Arsivde | Historical archive state. |
| `cancelled` | Iptal | Closed outside the normal completion path. |

## Allowed Transitions

| From | To |
| --- | --- |
| `draft` | `open`, `cancelled` |
| `open` | `in_progress`, `panel_done_stock`, `panel_done_sent`, `done`, `cancelled` |
| `in_progress` | `panel_done_stock`, `panel_done_sent`, `done`, `cancelled` |
| `panel_done_stock` | `panel_done_sent`, `done`, `archived` |
| `panel_done_sent` | `done`, `archived` |
| `done` | `archived` |

## Operational Rules

- New-ticket notifications are emitted when a ticket moves from `draft` to an active state.
- Partner notifications are relevant for `panel_done_stock`, `panel_done_sent`, and `done`.
- Any new UI or service code must read labels and transition rules from `TicketStatus`, not duplicate strings.
