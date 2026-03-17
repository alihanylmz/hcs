# Permission Matrix

This matrix documents the operational access policy inferred from the current source code on 2026-03-17.

## Roles

| Role | Description |
| --- | --- |
| `admin` | Full back-office access. |
| `manager` | Management access except hard admin-only infrastructure tasks. |
| `supervisor` | Can open and coordinate jobs, but not full admin management. |
| `technician` | Field user focused on tickets and execution. |
| `partner_user` | External partner visibility limited to assigned partner scope. |
| `pending` | Logged-in but approval-limited account. |

## Screen Access

| Screen / Module | admin | manager | supervisor | technician | partner_user | pending |
| --- | --- | --- | --- | --- | --- | --- |
| Login / Auth | Yes | Yes | Yes | Yes | Yes | Limited |
| Ticket List | Yes | Yes | Yes | Yes | Yes | Limited |
| Ticket Detail | Yes | Yes | Yes | Yes | Yes | Limited |
| New Ticket | Yes | Yes | Yes | No | No | No |
| Edit Ticket | Yes | Yes | Limited | Limited | No | No |
| Dashboard | Yes | Yes | No | No | No | No |
| Stock Overview | Yes | Yes | Limited | Limited | No | No |
| Archived Tickets | Yes | Yes | Yes | Read-only | Read-only | Read-only |
| User Management | Yes | Yes | No | No | No | No |
| Partner Management | Yes | Yes | No | No | No | No |
| Profile | Yes | Yes | Yes | Yes | Yes | Yes |
| Teams / Kanban | Team-role based | Team-role based | Team-role based | Team-role based | Team-role based | No |

## Action Policy

| Action | admin | manager | supervisor | technician | partner_user | pending |
| --- | --- | --- | --- | --- | --- | --- |
| View active tickets | Yes | Yes | Yes | Yes | Partner scoped | Limited |
| View draft tickets | Yes | Yes | No | No | No | No |
| Create ticket | Yes | Yes | Yes | Yes | No | No |
| Change ticket status | Yes | Yes | Limited | Limited | No | No |
| Add service note | Yes | Yes | Yes | Yes | No | No |
| Add partner note | No | No | No | No | Yes | No |
| Manage users and roles | Yes | Yes | No | No | No | No |
| Manage partner firms | Yes | Yes | No | No | No | No |
| Delete stock records | Yes | Yes | No | No | No | No |

## Notes

- `partner_user` access depends on `partner_id` scope and RLS policies in Supabase.
- Team / Kanban permissions are controlled by `owner`, `admin`, and `member` team roles in addition to app roles.
- `pending` users are blocked at login flow for most productive actions until approved.
