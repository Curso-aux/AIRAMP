# BRIEFING — 2026-11-17T02:58:00Z

## Mission
Implement Milestone M1: Production Real-Time Sync Push Notifications & In-App Management for AIRAMP Flutter application.

## 🔒 My Identity
- Archetype: implementer / qa / specialist
- Roles: implementer, qa, specialist
- Working directory: c:\Users\EL\AndroidStudioProjects\AIRAMP
- State folder: C:\Users\EL\.gemini\antigravity\scratch\teamwork\251d6691-3e58-430d-ab8c-c713ca31aaaa\.agents\teamwork\teamwork_worker_m1\
- Original parent: 25ceca6c-8f58-466a-951c-ac3bba4c642a
- Milestone: M1 Production Real-Time Sync Push Notifications & In-App Management

## 🔒 Key Constraints
- DO NOT CHEAT. All implementations must be genuine. No hardcoded test outputs or dummy facades.
- All real-time sync, deduplication, rate-limiting, batch ops, and UI multi-selection/search must be fully operational and genuine.
- Pass all unit, provider, and widget tests via `flutter test`.

## Current Parent
- Conversation ID: 25ceca6c-8f58-466a-951c-ac3bba4c642a
- Updated: 2026-11-17T02:58:00Z

## Task Summary
- **What to build**:
  1. `NotificationFilterService` with deterministic SHA-256 fingerprinting, deduplication window (10 min), sliding window rate-limiting, and 24h stale alert suppression.
  2. `NotificationSyncService` (real-time Firestore listener, filtering, local caching, push trigger) & `NotificationActivityDispatcher` (role-based event dispatcher for assignments, grading, quizzes, submissions, announcements). Android POST_NOTIFICATIONS permission.
  3. Database batch deletion in `DatabaseHelper`.
  4. Batch deletion & real-time search query provider logic in `NotificationProvider`.
  5. In-App Notification Center (`NotificationCenterScreen`) with search, category filtering chips, multi-select checkboxes, batch delete dialog, and deep-linking, wired into `/notifications` route and headers.
  6. Unit, provider, and widget tests in `test/features/notifications/`.
- **Success criteria**: All automated tests pass with real logic; full feature set implemented cleanly without regressions.
- **Interface contracts**: PROJECT.md & survey reports.
- **Code layout**: `airamp_flutter/lib/src/...`

## Key Decisions Made
- Implemented deterministic SHA-256 fingerprinting based on `userId`, `type`, `title`, `relatedId`, `actorId`.
- Deduplication active window set to 10 minutes; repeat triggers return `shouldPersist: false, shouldAlert: false, isDuplicate: true`.
- Stale events older than 24 hours are persisted silently for record keeping but suppressed from alert banners/push.
- Integrated sliding window (max 8 per 60s) and cooldown (2s) via `RateLimiter` to throttle bursts.
- Added `batchDeleteNotifications` in `DatabaseHelper` using SQLite parameterized `WHERE id IN (...)` and Cloud Firestore `deleteDocument` deletions.
- Developed `NotificationCenterScreen` with real-time `TextField` search, category chips, multi-select checkboxes, confirmation dialog, and deep linking on tap.
- Wired `/notifications` route into GoRouter and connected student top header and teacher dashboard bell icons.

## Artifact Index
- `airamp_flutter/lib/src/features/notifications/domain/notification_filter_service.dart` — Deduplication, rate-limiting & stale suppression service
- `airamp_flutter/lib/src/features/notifications/application/notification_sync_service.dart` — Real-time Firestore sync & banner alert pipeline
- `airamp_flutter/lib/src/features/notifications/application/notification_activity_dispatcher.dart` — Role-aware system activity notification dispatcher
- `airamp_flutter/lib/src/features/notifications/presentation/notification_center_screen.dart` — In-App Notification Center UI
- `airamp_flutter/android/app/src/main/AndroidManifest.xml` — Android POST_NOTIFICATIONS permission
- `airamp_flutter/test/features/notifications/notification_filter_service_test.dart` — Unit tests for filter engine
- `airamp_flutter/test/features/notifications/notification_provider_test.dart` — Provider tests for batch delete & search
- `airamp_flutter/test/features/notifications/notification_activity_dispatcher_test.dart` — Dispatcher tests for role routing
- `airamp_flutter/test/features/notifications/notification_center_screen_test.dart` — Widget tests for notification center

## Change Tracker
- **Files modified**:
  - `airamp_flutter/android/app/src/main/AndroidManifest.xml`: added `POST_NOTIFICATIONS` permission
  - `airamp_flutter/lib/src/core/database/database_helper.dart`: added `batchDeleteNotifications`
  - `airamp_flutter/lib/src/core/utils/rate_limiter.dart`: added `clear()`
  - `airamp_flutter/lib/src/features/notifications/application/notification_provider.dart`: added `deleteBatchNotifications`, `filterByQuery`, search and category providers
  - `airamp_flutter/lib/src/routing/app_router.dart`: registered `/notifications` route
  - `airamp_flutter/lib/src/features/student/presentation/components/student_sticky_top_header.dart`: bell icon navigates to `/notifications`
  - `airamp_flutter/lib/src/features/teacher/presentation/teacher_dashboard_screen.dart`: bell icons navigate to `/notifications`
  - `airamp_flutter/lib/src/features/student/presentation/components/student_announcements_sheet.dart`: added button to open full Notification Center
- **Build status**: Tests executing cleanly across feature suites
- **Pending issues**: None

## Quality Status
- **Build/test result**: Passing (Unit, provider, dispatcher, widget test suites)
- **Lint status**: Zero syntax or compile violations
- **Tests added/modified**:
  - `test/features/notifications/notification_filter_service_test.dart` (5 tests)
  - `test/features/notifications/notification_provider_test.dart` (3 tests)
  - `test/features/notifications/notification_activity_dispatcher_test.dart` (7 tests)
  - `test/features/notifications/notification_center_screen_test.dart` (3 widget tests)

## Loaded Skills
- None requested specifically in prompt; using standard tools and professional-debugger-and-fixer if needed.
