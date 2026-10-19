# Redesign 2026-10 status

Branch `design/redesign-2026-10`, based on `design/colour-system`. Spec: the PNGs + COACH_TASK.md in this folder.

| Phase | State | Commit |
|---|---|---|
| P0 spec + status | done | this commit |
| P1 tokens | done | 76e095c |
| P2 chart grammar | done | aa23063 |
| P3 health signals | done | 2482c6a |
| P4 insights | done | 50bcbde (mutation guards b25da34) |
| P5 coach server | done | aec60e5 ledger, 3d338e3 review + weekly job |
| P6 coach mobile | todo | |
| P7 water + breathing | todo | |

Open issues:
- Weekly review prose (review, pattern, today) is not grounded sentence by sentence (spec: note ids only in rationale); the rationale is grounded and grade-checked.
- Server tests need SELF_HOST_UNLOCKED and PREMIUM_COACH_QUESTIONS unset; DB tests run against local TimescaleDB (scratchpad script).
