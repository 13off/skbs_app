# Global Voice Goal Planner v16

v16 adds a deterministic goal layer above the frozen v15 multi-step planner.

## Why

v15 understands explicit plans such as `найди -> выбери -> подготовь действие`.
v16 also understands an operational goal where the user does not enumerate every table to inspect.

Examples:

- `Разберись, кто завтра вылетает и у кого не всё готово.`
- `Проверь готовность кандидатов к вылету завтра и покажи только проблемы.`
- `Проверь готовность кандидатов к вылету завтра и подготовь всё, что можно.`
- `Что горит на объекте Талнах к завтрашнему дню?`
- `Покажи риски по компании к завтра.`

## Candidate readiness goal

The server joins the current role/company-scoped data from:

- `recruitment_applications`;
- `recruitment_flights`;
- `recruitment_documents`;
- `recruitment_messages`.

The readiness checks are deterministic:

1. required documents: passport, registration, SNILS, INN, policy;
2. responsible user assigned;
3. latest outbound message has a later inbound reply;
4. confirmed Telegram/MAX delivery channel exists;
5. flight belongs to the requested date when the goal is flight-specific.

`подготовь всё, что можно` does not grant arbitrary write access. The only automatically preparable action in this goal is a document reminder for candidates who both lack required documents and have a confirmed Telegram/MAX channel. It still uses `confirmation_required: true` and the existing action coordinator/audit pipeline. A single package is capped at 12 recipients.

## Operational risk goal

For admin/owner/developer and foreman the server combines:

- active employees + `attendance` marks;
- open `tasks` due by the target date;
- open `procurement_requests` needed by the target date;
- incoming candidate readiness for manager roles.

For a foreman, object scope is forced to the assigned object. Manager roles may ask for a named object or a company-wide scan.

A missing positive attendance mark is deliberately described only as a data signal. It is not labelled as a confirmed absence or misconduct. For a future date attendance is not interpreted at all, because marks may legitimately not exist yet.

Operational goal mode is read-only. It does not close tasks, advance procurement or write zero shifts merely because a deadline or mark is missing.

## Regression boundary

The exact v15 implementation is preserved in `multi_step_plan_v15.ts`.
`multi_step_plan.ts` is now a thin additive wrapper:

1. try v16 goal plan;
2. otherwise delegate to frozen v15 unchanged.

Neither goal module calls `.insert()`, `.update()` or `.delete()`.
