# AIRAMP Hybrid Architecture & System Truth

> **Document Version:** 1.0  
> **Last Updated:** November 17, 2026  
> **Purpose:** Single source of truth for the AIRAMP cloud infrastructure, data partitioning, and synchronization model. Prevents hallucination and outlines exact roles for Cloudflare R2, Supabase, Firebase, and Local SQLite.

---

## 1. Architectural Map: Who Owns What?

```
+---------------------------------------------------------------------------------------------------+
|                                        AIRAMP CLIENTS                                             |
|                     (Flutter Web: aira-demo-live.web.app | Android Mobile App)                    |
+---------------------------------------------------------------------------------------------------+
        |                                       |                                    |
        | 1. High-Speed Binary Files            | 2. Relational & Realtime Chat      | 3. Auth & Notifications
        v                                       v                                    v
+-------------------------------+   +------------------------------------+   +---------------------+
|        CLOUDFLARE R2          |   |          SUPABASE (PostgreSQL)     |   |   GOOGLE FIREBASE   |
+-------------------------------+   +------------------------------------+   +---------------------+
| - Handout PDFs & Docs         |   | - Real-time Chat (`messages`,      |   | - Firebase Auth     |
| - Student Submission Files    |   |   `conversations`)                 |   | - Cloud Messaging   |
| - Curriculum Media & Images   |   | - Relational Tables (`users`,      |   |   (FCM Push)        |
| - Chat Image Attachments      |   |   `assignments`, `quizzes`,        |   | - Firebase Hosting  |
| - $0 Egress Bandwidth Fees    |   |   `submissions`, `sections`)       |   |   (Web App CDN)     |
| - 10 GB Free Storage Tier     |   | - Zero Quota Exhaustion            |   |                     |
+-------------------------------+   +------------------------------------+   +---------------------+
```

---

## 2. Service Matrix & Configuration Details

### A. Cloudflare R2 (Binary Object Storage)
* **Role:** Stores all user-uploaded binary files. Replaces Google Drive and Firebase Storage to eliminate bandwidth/egress costs.
* **Bucket Name:** `aira-storage`
* **Account ID:** `04f40ee82af58f1db27171ca2c8cd61e`
* **Public Dev URL:** `https://pub-4e41421375a34cc8b467d100681fa8e0.r2.dev`
* **S3 Endpoint:** `https://04f40ee82af58f1db27171ca2c8cd61e.r2.cloudflarestorage.com`
* **Implementation:** `CloudflareR2Service` in `airamp_flutter/lib/src/core/services/cloudflare_r2_service.dart`. Uses standard AWS Signature Version 4 (SigV4) signed HTTP `PUT` requests.
* **CORS Policy (Required for Web Uploads):**
  In the Cloudflare Dashboard under **R2 > `aira-storage` > Settings > CORS Policy > "+ Add"**, paste this exact JSON:
  ```json
  [
    {
      "AllowedOrigins": [
        "*"
      ],
      "AllowedMethods": [
        "GET",
        "PUT",
        "POST",
        "DELETE",
        "HEAD"
      ],
      "AllowedHeaders": [
        "*"
      ],
      "ExposeHeaders": [],
      "MaxAgeSeconds": 3600
    }
  ]
  ```

---

### B. Supabase (Database & Real-time WebSockets)
* **Role:** Handles high-frequency real-time messaging, chat rooms, direct messages, and structured relational records. Eliminates the Firebase Firestore 50,000 read/day limit that was previously exhausted by 4-second chat polling loops.
* **Project Name:** `AIRA-Platform`
* **Project URL:** `https://rwwbqcadfsevazgquier.supabase.co`
* **Region:** Singapore (`ap-southeast-1`)
* **Anon / Publishable Key:** `sb_publishable_YdkBZMTJZPEsB6rJM3bpQg_-rJf4zMw`
* **Active Tables (11 Total):**
  1. `users`
  2. `sections`
  3. `subjects`
  4. `announcements`
  5. `assignments`
  6. `submissions`
  7. `quizzes`
  8. `quiz_attempts`
  9. `conversations`
  10. `conversation_participants`
  11. `messages`
* **Realtime Replication Enabled On:** `messages`, `announcements`.
* **Flutter Integration:** `SupabaseService` in `airamp_flutter/lib/src/core/database/supabase_service.dart`. Chat streams use native WebSockets instead of HTTP polling.

---

### C. Google Firebase (Authentication & Static Web Hosting)
* **Project ID:** `aira-demo-live`
* **Hosting URL:** `https://aira-demo-live.web.app`
* **Role:**
  - **Firebase Auth:** Handles user authentication tokens and login sessions.
  - **Firebase Cloud Messaging (FCM):** Delivers push notifications to mobile devices.
  - **Firebase Hosting:** Hosts the compiled production Flutter Web application.
  - **Legacy Cloud Firestore:** Deprecated for chat and active polling. Maintained only as fallback sync during transitional migration.

---

### D. Local SQLite Engine (`DatabaseHelper`)
* **Role:** High-speed offline caching and local transactions.
* **Web:** Runs in-memory (`inMemoryDatabasePath`) with cloud synchronization.
* **Mobile (Android):** Runs persistent SQLite database file on device storage (`airamp_local.db`).

---

## 3. Why Deleted Quizzes and Assignments Reappeared

When the teacher clicked the delete icon on quiz (`bbbb`) or assignments (`haha`, `Ngaton`), they reappeared upon page refresh or app reload. This occurred due to three specific factors:

### Factor 1: The Client Code Was Stale (Environment Mismatch)
* The user was testing against:
  - The live Firebase Hosting web app: `https://aira-demo-live.web.app/#/teacher/subjects`
  - The previously installed Android APK on the mobile device.
* Firebase Hosting serves **statically compiled JavaScript files** from the previous deployment.
* The mobile device runs **pre-compiled bytecode**.
* Code edits made locally in the repository do **not** take effect in the browser or on the phone until `deploy_hosting.bat` is executed and the mobile app is rebuilt. The running client was still executing the old buggy logic.

### Factor 2: The Unawaited Cloud Deletion Race Condition
* In the old codebase, `deleteAssignment` and `deleteQuiz` contained:
  ```dart
  // OLD CODE:
  unawaited(FirestoreService().deleteDocument('assignments', cloudId));
  ```
* Immediately after deleting locally in SQLite, the screen UI called:
  ```dart
  ref.invalidate(subjectAssignmentsProvider(subjectId));
  ```
* In Riverpod, `subjectAssignmentsProvider` immediately ran:
  ```dart
  await DatabaseHelper().syncCloudAssignmentsToLocal(force: true);
  ```
* Because `deleteDocument` was **unawaited**, the cloud sync fetch request was sent to Firestore *while the deletion was still processing on Google's servers*. Firestore returned the assignment or quiz back to the client, and `syncCloudAssignmentsToLocal` re-inserted it into SQLite!

### Factor 3: Absence of Local Tombstones (Resurrection)
* In distributed offline-first databases, simply executing `DELETE FROM assignments WHERE id = ?` leaves no trail that the user explicitly deleted the record.
* On the next sync cycle, the incoming cloud document was treated as a "new" item and resurrected.
* **Solution Implemented:**
  1. We introduced persistent **Tombstone Tracking** via `SharedPreferences` (`permanently_deleted_assignments` and `permanently_deleted_quizzes`).
  2. All cloud deletions across Supabase and Firestore are now **awaited** before `deleteAssignment` or `deleteQuiz` returns.
  3. `syncCloudAssignmentsToLocal` and `syncCloudQuizzesToLocal` check the tombstone register and strictly skip any deleted record.
  4. Query methods `getAssignmentsForSubject`, `getAssignmentsForStudent`, and `getQuizzesForSubject` actively purge leftover rows from SQLite and omit tombstoned records from UI lists.

---

## 4. Google Drive Removal Status

* **Teacher Side:** Removed all Google Drive folder input fields, folder URL persistence, and auto-upload toggle switches from `create_assignment_dialog.dart`. Handout files are now routed directly to Cloudflare R2.
* **Student Side:** Removed Google Drive submission upload pathways and the "Google Drive Sync Enabled" banner from `submissions_screen.dart`. All student submissions (files, images, text) upload directly to Cloudflare R2 with metadata saved to the relational database.

---

## 5. Deployment & Verification Steps

To ensure both Web and Mobile devices run the new synchronized codebase:

1. **Add the CORS Policy to Cloudflare R2:**
   - Go to [Cloudflare Dashboard](https://dash.cloudflare.com) > **R2 Object Storage** > `aira-storage` > **Settings**.
   - Under **CORS Policy**, click **+ Add**.
   - Paste the CORS JSON from Section 2A and click **Save**.

2. **Deploy the Web App to Firebase Hosting:**
   Run `deploy_hosting.bat` in the project root:
   ```cmd
   deploy_hosting.bat
   ```
   This compiles Flutter Web into `airamp_flutter/build/web` and uploads it to `https://aira-demo-live.web.app`.

3. **Purge Browser Cache:**
   On `https://aira-demo-live.web.app`:
   - Press `Ctrl + Shift + R` (or `Ctrl + F5`) to force a hard reload and load the newly deployed JavaScript bundles.

4. **Update the Mobile App:**
   Re-install or launch the mobile app from the project root:
   ```cmd
   cd airamp_flutter
   flutter run -d <device-id>
   ```
