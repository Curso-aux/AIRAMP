# SDD ledger — plan: docs/superpowers/plans/2026-09-07-rork-migration-phase-4-backend.md
Status: IN PROGRESS (started 2026-09-07)
Base: d881795 (end Phase 3)

## Completed Phases 1-3:
- Phase 1 Auth: 2 commits
- Phase 2 Admin: 5 commits (components, stats, subjects, profile, smoke)
- Phase 3 Student: 4 commits (repository, home stats, courses, smoke)

## Phase 4 Backend Integration + Sync Tasks:
1. Wire chat_repository to /v1/chat/ws via ApiClient authInterceptor (replace localhost hardcoded URL with FUNCTIONS_URL env)
2. Wire sync provider (if exists) to /v1/sync endpoint
3. Confirm all entity endpoints (/v1/api/{entity}) use AuthHeaders properly (already done in api_client)
4. End-to-end backend smoke test (admin + student + chat)

Scan: chat_repository uses hardcoded ws://localhost:8787 — conflict with FUNCTIONS_URL env. Ruling: update to use String.fromEnvironment('FUNCTIONS_URL') with /v1/chat/ws path.
Task 1 complete; Task 2 (sync) has no repo file found; Task 3 auth headers already done; Task 4 smoke pending.
Ruling: chat_repository now derives URL from FUNCTIONS_URL via String.fromEnvironment with wss/https replacement; repo.connect() now called from provider with auth token. No sync repository exists (no /v1/sync provider) — skip Task 2 until spec defines. AuthHeaders used in ApiClient.authInterceptor() (confirmed). End-to-end smoke deferred to Task 4 after backend deploy.
