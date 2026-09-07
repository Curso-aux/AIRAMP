# Phase 2: Admin Core — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: subagent-driven-development

**Goal:** Connect admin screens to real backend/SQLite data + shared components.

**Architecture:** Continue existing SQLite-backed repositories (admin_repository.dart already has full CRUD); add shared widgets at `core/components/`; wire dashboard stats via Provider; wire subjects to `/v1/api/subjects`; wire profile PUT to `/v1/api/users/{id}`.

**Tech Stack:** Flutter 3.12, Riverpod 3.4, Dio 5.11, SQLite sqflite 2.4.

**Spec:** `docs/superpowers/specs/2026-09-07-rork-migration-design.md`

---

## Global Constraints

- Keep existing backend (Cloudflare Durable Objects).
- All screens must work end-to-end.
- Replace existing admin presentation where hardcoded.
- TDD pattern required.
- Subagent-Driven Development with ledger at `.superpowers/sdd/2026-09-07-rork-migration-phase-2-admin-core/progress.md`.

---

### Task 1: Shared Component Library

**Files:**
- Create: `lib/src/core/components/status_badge.dart`, `progress_bar.dart`, `skeleton_loader.dart`, `empty_state.dart`

**Steps:**
- [ ] Step 1: Write failing test for StatusBadge
- [ ] Step 2: Implement minimal StatusBadge widget
- [ ] Step 3: Repeat for ProgressBar, SkeletonLoader, EmptyState
- [ ] Step 4: Commit

---

### Task 2: Admin Dashboard Statistics

**Files:**
- Modify: `lib/src/features/admin/presentation/admin_dashboard_screen.dart`

**Steps:**
- [ ] Step 1: Write test asserting stats come from real providers (subjects count, sections count)
- [ ] Step 2: Replace hardcoded '1','0','1' with provider reads from `admin_repository.dart`
- [ ] Step 3: Commit

---

### Task 3: Admin Subjects Backend Connection

**Files:**
- Modify: `lib/src/features/admin/presentation/admin_subjects_screen.dart` / `subjects_mgmt_screen.dart`

**Steps:**
- [ ] Step 1: Write failing test that expects `/v1/api/subjects` call
- [ ] Step 2: Wire repository call through ApiClient with authInterceptor
- [ ] Step 3: Commit

---

### Task 4: Admin Profile PUT Integration

**Files:**
- Modify: `lib/src/features/admin/presentation/admin_profile_screen.dart`
- Modify: `lib/src/features/auth/application/auth_provider.dart` (updateProfile)

**Steps:**
- [ ] Step 1: Write failing test for PUT `/v1/api/users/{id}`
- [ ] Step 2: Implement profile update through ApiClient
- [ ] Step 3: Commit

---

### Task 5: Shared Widget Library (combined with Task 1)

**Merged** — covered by Task 1 above.

---

### Task 6: End-to-End Admin Smoke Test

**Files:**
- Modify: `test/features/admin/admin_smoke_test.dart`

**Steps:**
- [ ] Step 1: Write smoke test navigating all admin screens
- [ ] Step 2: Verify passes with FFI SQLite
- [ ] Step 3: Commit
