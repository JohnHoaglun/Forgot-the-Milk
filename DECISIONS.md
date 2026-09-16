# Decisions

| Date | Decision | Rationale |
| --- | --- | --- |
| 2026-09-15 | Keep local persistence as the source of truth. | The app must remain usable offline; CloudKit is a reconciliation layer. |
| 2026-09-15 | Use Apple frameworks only for v1. | The specification calls for no dependencies or custom backend. |
