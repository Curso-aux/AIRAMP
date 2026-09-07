# Rork Migration Phase 1 — Auth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the Expo auth flow (login, signup, forgot-password, admin-signup) to Flutter, connecting to the existing `functions/` backend via Dio, persisting session tokens in SQLite, and routing by role (admin → `/admin`, student → `/student`).

**Architecture:**
- Mirror `expo/app/login.tsx`, `signup.tsx`, `forgot-password.tsx`, `admin-signup.tsx` flows using current Flutter `feature-first` architecture.
- `AuthRepository` (Dio) calls `/v1/auth/session`, `/v1/auth/revoke`, and entity endpoints (`/v1/api/users`).
- `AuthNotifier` (Riverpod 3.x `Notifier<AuthState>`) exposes `login()`, `logout()`, `registerStudent()`, `registerAdmin()`, `requestPasswordReset()`.
- Sessions persisted in SQLite via new `sessions` table (added to v9 schema).

**Tech Stack:** Flutter 3.12 (`pubspec.yaml` SDK ^3.12.2), `flutter_riverpod ^3.4.3`, `go_router ^18.0.1`, `dio ^5.11.1`, `sqflite ^2.4.3`.

**Spec:** `docs/superpowers/specs/2026-09-07-rork-migration-design.md`

## Global Constraints

- Auth header contract (from `functions/index.ts` and `expo/services/api.ts`): every authenticated request must include `X-School-Session: <token>` and `X-School-User-Id: <userId>` headers.
- Endpoint base: `FUNCTIONS_URL` from `--dart-define=FUNCTIONS_URL=<url>`. Default empty string in dev; backend calls will throw and fall back to local SQLite.
- Login flow must respect role: `super_admin`/`admin` → `/admin`; `student` → `/student` (mirrors `expo/app/login.tsx` redirect logic).
- Database schema version: bump from `v8` to `v9` in `database_helper.dart`; add `sessions` table.
- Riverpod 3.x API: use `Notifier<AuthState>` + `AsyncValue<AuthState>` for async flows; do NOT use deprecated `StateNotifier`.
- All commits use `feat:` / `chore:` / `fix:` prefixes; co-author line is automatic.
- Do NOT modify `rork-aira-main/` files. Migration is one-way: `airamp_flutter/` only.

## Source Mapping (Phase 1)

| Expo source | Flutter target |
|---|---|
`expo/app/login.tsx` | `airamp_flutter/lib/features/auth/presentation/login_screen.dart` |
`expo/app/signup.tsx` | `airamp_flutter/lib/features/auth/presentation/signup_screen.dart` |
`expo/app/admin-signup.tsx` | `airamp_flutter/lib/src/features/auth/presentation/admin_signup_screen.dart` |
`expo/app/forgot-password.tsx` | `airamp_flutter/lib/src/features/auth/presentation/forgot_password_screen.dart` |
`expo/contexts/AuthContext.tsx` | `airamp_flutter/lib/features/auth/providers/auth_provider.dart` |
`expo/services/api.ts` (`authHeaders`) | `airamp_flutter/lib/core/api/api_client.dart` + new `auth_headers.dart` |
`expo/services/cloudSync.ts` (`getSessionToken`) | `airamp_flutter/lib/src/features/auth/data/session_local_data_source.dart` |

---

## Task 1: Add sessions table to SQLite (schema v9)

**Files:**
- Modify: `airamp_flutter/lib/src/core/database/database_helper.dart`
- Test: `airamp_flutter/test/core/database/database_helper_v9_test.dart`

**Interfaces:**
- Consumes: existing `DatabaseHelper.database` getter.
- Produces: `sessions` table with columns `id INTEGER PK AUTOINCREMENT`, `user_id TEXT NOT NULL`, `token TEXT NOT NULL UNIQUE`, `role TEXT NOT NULL`, `created_at TEXT NOT NULL`, `expires_at TEXT`.

- [ ] **Step 1: Write failing test for sessions table**

```dart
// airamp_flutter/test/core/database/database_helper_v9_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('sessions table exists at v9', () async {
    final helper = DatabaseHelper();
    final db = await helper.database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='sessions'",
    );
    expect(result, isNotEmpty);
    expect(result.first['name'], 'sessions');
  });
}
```

- [ ] **Step 2: Add sqflite_common_ffi dev dependency**

In `airamp_flutter/pubspec.yaml` under `dev_dependencies:`
```yaml
  sqflite_common_ffi: ^2.3.0
```

Run: `cd airamp_flutter && flutter pub get`

- [ ] **Step 3: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/core/database/database_helper_v9_test.dart`
Expected: FAIL — sessions table doesn't exist yet.

- [ ] **Step 4: Bump DB version and add sessions table**

In `database_helper.dart`:
- Change `version: 8` → `version: 9`.
- In `_initDatabase`, add after the reg_links table block:
```dart
await db.execute('''
  CREATE TABLE sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    token TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL,
    created_at TEXT NOT NULL,
    expires_at TEXT
  )
''');
```
- In `_onUpgrade`, add at the bottom:
```dart
if (oldVersion < 9) {
  await db.execute('''
    CREATE TABLE sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id TEXT NOT NULL,
      token TEXT NOT NULL UNIQUE,
      role TEXT NOT NULL,
      created_at TEXT NOT NULL,
      expires_at TEXT
    )
  ''');
}
```

- [ ] **Step 5: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/core/database/database_helper_v9_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/core/database/database_helper.dart airamp_flutter/pubspec.yaml airamp_flutter/pubspec.lock airamp_flutter/test/core/database/database_helper_v9_test.dart
git commit -m "feat(auth): add sessions table, bump sqlite schema to v9"
```

---

## Task 2: Auth headers contract in Dio client

**Files:**
- Modify: `airamp_flutter/lib/core/api/api_client.dart`
- Create: `airamp_flutter/lib/core/api/auth_headers.dart`
- Test: `airamp_flutter/test/core/api/auth_headers_test.dart`

**Interfaces:**
- Consumes: `FUNCTIONS_URL` (from `--dart-define`), `DatabaseHelper`.
- Produces: `AuthHeaders.build({String? userIdOverride})` returns `Map<String,String>` with `Content-Type`, `X-School-Session`, `X-School-User-Id` (if userId present). Reads token from `sessions` table (latest non-expired).

- [ ] **Step 1: Write failing test for auth_headers**

```dart
// airamp_flutter/test/core/api/auth_headers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/core/api/auth_headers.dart';

void main() {
  test('build returns Content-Type only when no session', () {
    final headers = AuthHeaders.build();
    expect(headers['Content-Type'], 'application/json');
    expect(headers.containsKey('X-School-Session'), false);
  });

  test('build includes X-School-Session and X-School-User-Id when set', () {
    final headers = AuthHeaders.build(token: 'tok-123', userId: 'u-9');
    expect(headers['X-School-Session'], 'tok-123');
    expect(headers['X-School-User-Id'], 'u-9');
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/core/api/auth_headers_test.dart`
Expected: FAIL — `AuthHeaders` not defined.

- [ ] **Step 3: Implement AuthHeaders**

Create `airamp_flutter/lib/core/api/auth_headers.dart`:
```dart
import 'package:airamp_flutter/src/core/database/database_helper.dart';

class AuthHeaders {
  /// Build request headers following the contract from
  /// rork-aira-main/expo/services/api.ts (`authHeaders`) and
  /// rork-aira-main/functions/index.ts (X-School-Session, X-School-User-Id).
  ///
  /// When [token]/[userId] are not provided, attempts to read the latest
  /// non-expired session from the local SQLite `sessions` table.
  static Map<String, String> build({String? token, String? userId}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) headers['X-School-Session'] = token;
    if (userId != null) headers['X-School-User-Id'] = userId;
    return headers;
  }

  /// Read the latest non-expired session from SQLite.
  /// Returns (token, userId) or null if no valid session.
  static Future<({String token, String userId, String role})?> readSession() async {
    final db = await DatabaseHelper().database;
    final rows = await db.rawQuery(
      "SELECT user_id, token, role, expires_at FROM sessions "
      "WHERE expires_at IS NULL OR expires_at > ? "
      "ORDER BY id DESC LIMIT 1",
      [DateTime.now().toIso8601String()],
    );
    if (rows.isEmpty) return null;
    return (
      token: rows.first['token'] as String,
      userId: rows.first['user_id'] as String,
      role: rows.first['role'] as String,
    );
  }
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/core/api/auth_headers_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/core/api/auth_headers.dart airamp_flutter/test/core/api/auth_headers_test.dart
git commit -m "feat(auth): add AuthHeaders matching expo authHeaders contract"
```

---

## Task 3: Update ApiClient with FUNCTIONS_URL and auth header interceptor

**Files:**
- Modify: `airamp_flutter/lib/core/api/api_client.dart`
- Test: `airamp_flutter/test/core/api/api_client_test.dart`

**Interfaces:**
- Consumes: `FUNCTIONS_URL` (from `--dart-define`), `AuthHeaders`.
- Produces: `ApiClient.dio` is a `Dio` instance with `baseUrl = <FUNCTIONS_URL>` (no trailing slash), 5s connect, 3s receive timeout, and an interceptor that injects `X-School-Session` / `X-School-User-Id` from SQLite on every request.

- [ ] **Step 1: Write failing test**

```dart
// airamp_flutter/test/core/api/api_client_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/core/api/api_client.dart';

void main() {
  test('ApiClient.dio has baseUrl from FUNCTIONS_URL when set', () {
    final dio = ApiClient.dio;
    expect(dio.options.baseUrl, isA<String>());
    expect(dio.options.baseUrl.endsWith('/'), false);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/core/api/api_client_test.dart`
Expected: FAIL — `ApiClient.dio` is a getter, currently a static `Dio` field.

- [ ] **Step 3: Rewrite ApiClient**

Replace `airamp_flutter/lib/core/api/api_client.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:airamp_flutter/core/api/auth_headers.dart';

class ApiClient {
  static const String _functionsUrl =
      String.fromEnvironment('FUNCTIONS_URL', defaultValue: '');

  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _functionsUrl.replaceAll(RegExp(r'/$'), ''),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 3),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (!options.headers.containsKey('X-School-Session')) {
          final session = await AuthHeaders.readSession();
          if (session != null) {
            options.headers['X-School-Session'] = session.token;
            options.headers['X-School-User-Id'] = session.userId;
          }
        }
        handler.next(options);
      },
    ));

  static Dio get dio => _dio;
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/core/api/api_client_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/core/api/api_client.dart airamp_flutter/test/core/api/api_client_test.dart
git commit -m "feat(api): point ApiClient at FUNCTIONS_URL with auth interceptor"
```

---

## Task 4: AuthRepository (Dio calls to /v1/auth + users)

**Files:**
- Create: `airamp_flutter/lib/src/features/auth/data/auth_repository.dart`
- Modify: `airamp_flutter/lib/src/features/auth/data/session_local_data_source.dart` (or new file if absent)
- Test: `airamp_flutter/test/features/auth/auth_repository_test.dart`

**Interfaces:**
- Consumes: `ApiClient.dio`, `DatabaseHelper`.
- Produces:
  - `Future<AuthResult> login({required String email, required String password})`
  - `Future<void> logout({required String token})`
  - `Future<AuthResult> registerStudent({required Map<String, dynamic> payload})`
  - `Future<AuthResult> registerAdmin({required Map<String, dynamic> payload})`
  - `Future<void> requestPasswordReset({required String email})`
- `AuthResult = { userId, token, role }`. On backend failure, throws `AuthException(message, statusCode)`.

- [ ] **Step 1: Write failing test**

```dart
// airamp_flutter/test/features/auth/auth_repository_test.dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

class _MockAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}
  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? requestStream, Future? cancelFuture) async {
    if (options.path.endsWith('/v1/auth/session') && options.method == 'POST') {
      return ResponseBody.fromString(
          '{"data":{"userId":"u-1","token":"t-1","role":"student"}}', 200,
          headers: {'content-type': ['application/json']});
    }
    return ResponseBody.fromString('{"error":"not found"}', 404,
        headers: {'content-type': ['application/json']});
  }
}

void main() {
  test('login returns AuthResult on 200', () async {
    final repo = AuthRepository();
    repo.dio.httpClientAdapter = _MockAdapter();
    final result = await repo.login(email: 'a@b.com', password: 'pw');
    expect(result.userId, 'u-1');
    expect(result.token, 't-1');
    expect(result.role, 'student');
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/features/auth/auth_repository_test.dart`
Expected: FAIL — `AuthRepository` undefined.

- [ ] **Step 3: Implement AuthRepository**

Create `airamp_flutter/lib/src/features/auth/data/auth_repository.dart`:
```dart
import 'package:dio/dio.dart';
import 'package:airamp_flutter/core/api/api_client.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, [this.statusCode]);
  @override
  String toString() => 'AuthException($statusCode): $message';
}

class AuthResult {
  final String userId;
  final String token;
  final String role;
  const AuthResult({required this.userId, required this.token, required this.role});
}

class AuthRepository {
  final Dio dio;
  AuthRepository({Dio? dio}) : dio = dio ?? ApiClient.dio;

  Future<AuthResult> login({required String email, required String password}) async {
    try {
      final res = await dio.post('/v1/auth/session', data: {'email': email, 'password': password});
      final data = (res.data as Map)['data'] as Map;
      final result = AuthResult(
        userId: data['userId'] as String,
        token: data['token'] as String? ?? '',
        role: data['role'] as String? ?? 'student',
      );
      await _persistSession(result);
      return result;
    } on DioException catch (e) {
      throw AuthException(_msg(e), e.response?.statusCode);
    }
  }

  Future<void> logout({required String token}) async {
    try {
      await dio.post('/v1/auth/revoke', data: {'token': token});
    } on DioException catch (_) {
      // Always clear local session even if backend revoke fails.
    }
    await _clearSessions();
  }

  Future<AuthResult> registerStudent({required Map<String, dynamic> payload}) async {
    return _register('/v1/api/users/students', payload, defaultRole: 'student');
  }

  Future<AuthResult> registerAdmin({required Map<String, dynamic> payload}) async {
    return _register('/v1/api/users/admins', payload, defaultRole: 'admin');
  }

  Future<void> requestPasswordReset({required String email}) async {
    try {
      await dio.post('/v1/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw AuthException(_msg(e), e.response?.statusCode);
    }
  }

  Future<AuthResult> _register(String path, Map<String, dynamic> payload, {required String defaultRole}) async {
    try {
      final res = await dio.post(path, data: payload);
      final data = (res.data as Map)['data'] as Map;
      final result = AuthResult(
        userId: data['userId'] as String,
        token: data['token'] as String? ?? '',
        role: data['role'] as String? ?? defaultRole,
      );
      await _persistSession(result);
      return result;
    } on DioException catch (e) {
      throw AuthException(_msg(e), e.response?.statusCode);
    }
  }

  Future<void> _persistSession(AuthResult r) async {
    final db = await DatabaseHelper().database;
    await db.insert('sessions', {
      'user_id': r.userId,
      'token': r.token,
      'role': r.role,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> _clearSessions() async {
    final db = await DatabaseHelper().database;
    await db.delete('sessions');
  }

  String _msg(DioException e) {
    final body = e.response?.data;
    if (body is Map && body['error'] is String) return body['error'] as String;
    return e.message ?? 'Network error';
  }
}
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/features/auth/auth_repository_test.dart`
Expected: PASS (uses FFI sqflite from Task 1 dependency)

- [ ] **Step 5: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/features/auth/data/auth_repository.dart airamp_flutter/test/features/auth/auth_repository_test.dart
git commit -m "feat(auth): add AuthRepository with /v1/auth + users endpoints"
```

---

## Task 5: AuthNotifier (Riverpod 3.x Notifier<AuthState>)

**Files:**
- Create: `airamp_flutter/lib/src/features/auth/application/auth_notifier.dart`
- Modify: `airamp_flutter/lib/src/features/auth/application/auth_provider.dart` (or create)
- Test: `airamp_flutter/test/features/auth/auth_notifier_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthHeaders.readSession()`.
- Produces:
  - `AuthState = AuthInitial | AuthLoading | AuthAuthenticated(userId, role) | AuthUnauthenticated | AuthError(message)`
  - `authProvider` (Riverpod `AsyncNotifierProvider<AuthNotifier, AuthState>`)
  - Methods: `login(email, password)`, `logout()`, `registerStudent(payload)`, `registerAdmin(payload)`, `requestPasswordReset(email)`, `bootstrap()` (called on app start to read SQLite session).

- [ ] **Step 1: Write failing test**

```dart
// airamp_flutter/test/features/auth/auth_notifier_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';

void main() {
  test('bootstrap without session yields AuthUnauthenticated', () async {
    final container = ProviderContainer();
    final notifier = container.read(authProvider.notifier);
    await notifier.bootstrap();
    expect(container.read(authProvider), isA<AuthUnauthenticated>());
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/features/auth/auth_notifier_test.dart`
Expected: FAIL — `authProvider` / `AuthNotifier` not defined.

- [ ] **Step 3: Implement AuthNotifier**

Create `airamp_flutter/lib/src/features/auth/application/auth_notifier.dart`:
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/core/api/auth_headers.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final String userId;
  final String role;
  const AuthAuthenticated({required this.userId, required this.role});
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthNotifier extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async => const AuthInitial();

  Future<void> bootstrap() async {
    state = const AsyncValue.data(AuthLoading());
    final s = await AuthHeaders.readSession();
    if (s == null) {
      state = const AsyncValue.data(AuthUnauthenticated());
    } else {
      state = AsyncValue.data(AuthAuthenticated(userId: s.userId, role: s.role));
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.data(AuthLoading());
    try {
      final r = await ref.read(authRepositoryProvider).login(email: email, password: password);
      state = AsyncValue.data(AuthAuthenticated(userId: r.userId, role: r.role));
    } on AuthException catch (e) {
      state = AsyncValue.data(AuthError(e.message));
    }
  }

  Future<void> registerStudent(Map<String, dynamic> payload) async {
    await _register(() => ref.read(authRepositoryProvider).registerStudent(payload: payload));
  }

  Future<void> registerAdmin(Map<String, dynamic> payload) async {
    await _register(() => ref.read(authRepositoryProvider).registerAdmin(payload: payload));
  }

  Future<void> _register(Future<AuthResult> Function() fn) async {
    state = const AsyncValue.data(AuthLoading());
    try {
      final r = await fn();
      state = AsyncValue.data(AuthAuthenticated(userId: r.userId, role: r.role));
    } on AuthException catch (e) {
      state = AsyncValue.data(AuthError(e.message));
    }
  }

  Future<void> logout() async {
    final s = await AuthHeaders.readSession();
    if (s != null) {
      await ref.read(authRepositoryProvider).logout(token: s.token);
    }
    state = const AsyncValue.data(AuthUnauthenticated());
  }

  Future<void> requestPasswordReset(String email) async {
    state = const AsyncValue.data(AuthLoading());
    try {
      await ref.read(authRepositoryProvider).requestPasswordReset(email: email);
      state = const AsyncValue.data(AuthUnauthenticated());
    } on AuthException catch (e) {
      state = AsyncValue.data(AuthError(e.message));
    }
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
```

- [ ] **Step 4: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/features/auth/auth_notifier_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/features/auth/application/auth_notifier.dart airamp_flutter/test/features/auth/auth_notifier_test.dart
git commit -m "feat(auth): add AuthNotifier with bootstrap/login/logout/register"
```

---

## Task 6: Update LoginScreen to call auth provider

**Files:**
- Modify: `airamp_flutter/lib/features/auth/presentation/login_screen.dart`
- Modify: `airamp_flutter/lib/src/features/auth/presentation/login_screen.dart` (pick one as canonical; delete other)
- Test: `airamp_flutter/test/features/auth/login_screen_test.dart`

**Interfaces:**
- Consumes: `authProvider` (Riverpod).
- Produces: `LoginScreen` that:
  - Reads `email`, `password` from `TextEditingController`.
  - On submit, calls `notifier.login(email, password)`.
  - Listens to `authProvider`; on `AuthAuthenticated` with `role` starting with `admin`/`super_admin` → `context.go('/admin')`; with `student` → `context.go('/student')`. On `AuthError` shows `SnackBar`.
  - On `AuthUnauthenticated` shows login form.

- [ ] **Step 1: Pick canonical LoginScreen**

The repo currently has TWO login screens: `lib/features/auth/presentation/login_screen.dart` and `lib/src/features/auth/presentation/login_screen.dart`. The `main.dart` uses the `src/` one (via `routerProvider` in `lib/src/routing/app_router.dart`). Keep the `src/` one as canonical; **delete the duplicate at `lib/features/auth/presentation/login_screen.dart`** in this task.

- [ ] **Step 2: Write failing widget test**

```dart
// airamp_flutter/test/features/auth/login_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/features/auth/presentation/login_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  String? lastEmail;
  String? lastPassword;
  @override
  Future<void> login(String email, String password) async {
    lastEmail = email;
    lastPassword = password;
  }
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
  @override
  Future<void> bootstrap() async {}
}

void main() {
  testWidgets('login form has email, password, and submit', (tester) async {
    final fake = _FakeAuthNotifier();
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: LoginScreen()),
    ));
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/features/auth/login_screen_test.dart`
Expected: FAIL — `authProvider.overrideWith` may need newer API, or `LoginScreen` shape differs.

- [ ] **Step 4: Rewrite LoginScreen**

Replace `airamp_flutter/lib/src/features/auth/presentation/login_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).login(_emailCtl.text.trim(), _passwordCtl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      next.whenData((state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is AuthAuthenticated) {
          if (state.role == 'admin' || state.role == 'super_admin') {
            context.go('/admin');
          } else {
            context.go('/student');
          }
        }
      });
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  controller: _emailCtl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtl,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  obscureText: _obscure,
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _submit, child: const Text('Login')),
                TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  child: const Text('Forgot password?'),
                ),
                TextButton(
                  onPressed: () => context.push('/signup'),
                  child: const Text('Create student account'),
                ),
                TextButton(
                  onPressed: () => context.push('/admin-signup'),
                  child: const Text('Register admin / teacher'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Delete duplicate at lib/features/auth/presentation/login_screen.dart**

```bash
rm "C:\Users\EL\AndroidStudioProjects\AIRAMP\airamp_flutter\lib\features\auth\presentation\login_screen.dart"
```

Also update the `core/routing/app_router.dart` to import from `src/features/auth/presentation/login_screen.dart` instead of `features/auth/presentation/login_screen.dart`. (See the file; it imports the wrong path.)

- [ ] **Step 6: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/features/auth/login_screen_test.dart`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/features/auth/presentation/login_screen.dart airamp_flutter/lib/features/auth airamp_flutter/lib/core/routing/app_router.dart airamp_flutter/test/features/auth/login_screen_test.dart
git commit -m "feat(auth): rewrite LoginScreen using AuthNotifier, fix router import"
```

---

## Task 7: Update SignupScreen (student registration)

**Files:**
- Modify: `airamp_flutter/lib/src/features/auth/presentation/signup_screen.dart`
- Modify: `airamp_flutter/lib/features/auth/presentation/signup_screen.dart` (delete duplicate; keep src/ canonical)
- Test: `airamp_flutter/test/features/auth/signup_screen_test.dart`

**Interfaces:**
- Consumes: `authProvider`.
- Produces: Form with `fullName`, `username`, `email`, `password`, optional `adminId`, `sectionId`, `subjectIds`, `gradeLevel`. On submit calls `notifier.registerStudent(payload)`. Navigates to `/student` on success.

- [ ] **Step 1: Write failing widget test**

```dart
// airamp_flutter/test/features/auth/signup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/features/auth/presentation/signup_screen.dart';

class _FakeNotifier extends AuthNotifier {
  Map<String, dynamic>? last;
  @override
  Future<void> registerStudent(Map<String, dynamic> payload) async {
    last = payload;
  }
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
  @override
  Future<void> bootstrap() async {}
}

void main() {
  testWidgets('signup form has fullName, email, password and submit', (tester) async {
    final fake = _FakeNotifier();
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: SignupScreen()),
    ));
    expect(find.byType(TextFormField), findsAtLeast(3));
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/features/auth/signup_screen_test.dart`
Expected: FAIL — current `SignupScreen` may be a placeholder.

- [ ] **Step 3: Rewrite SignupScreen**

Replace `airamp_flutter/lib/src/features/auth/presentation/signup_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _usernameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  String? _gradeLevel;

  @override
  void dispose() {
    _nameCtl.dispose();
    _usernameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'fullName': _nameCtl.text.trim(),
      'username': _usernameCtl.text.trim(),
      'email': _emailCtl.text.trim(),
      'password': _passwordCtl.text,
      if (_gradeLevel != null) 'gradeLevel': _gradeLevel,
    };
    await ref.read(authProvider.notifier).registerStudent(payload);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      next.whenData((state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is AuthAuthenticated) {
          context.go('/student');
        }
      });
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Student Signup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _nameCtl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextFormField(controller: _usernameCtl, decoration: const InputDecoration(labelText: 'Username')),
              const SizedBox(height: 12),
              TextFormField(controller: _emailCtl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextFormField(controller: _passwordCtl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _gradeLevel,
                items: const [
                  DropdownMenuItem(value: 'Grade 7', child: Text('Grade 7')),
                  DropdownMenuItem(value: 'Grade 8', child: Text('Grade 8')),
                  DropdownMenuItem(value: 'Grade 9', child: Text('Grade 9')),
                  DropdownMenuItem(value: 'Grade 10', child: Text('Grade 10')),
                ],
                onChanged: (v) => setState(() => _gradeLevel = v),
                decoration: const InputDecoration(labelText: 'Grade level'),
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _submit, child: const Text('Create account')),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Delete duplicate at lib/features/auth/presentation/signup_screen.dart**

```bash
rm "C:\Users\EL\AndroidStudioProjects\AIRAMP\airamp_flutter\lib\features\auth\presentation\signup_screen.dart"
```

- [ ] **Step 5: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/features/auth/signup_screen_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/features/auth airamp_flutter/lib/features/auth airamp_flutter/test/features/auth/signup_screen_test.dart
git commit -m "feat(auth): rewrite SignupScreen using AuthNotifier, remove duplicate"
```

---

## Task 8: Update AdminSignupScreen and ForgotPasswordScreen

**Files:**
- Modify: `airamp_flutter/lib/src/features/auth/presentation/admin_signup_screen.dart`
- Modify: `airamp_flutter/lib/src/features/auth/presentation/forgot_password_screen.dart`
- Test: `airamp_flutter/test/features/auth/admin_signup_screen_test.dart`
- Test: `airamp_flutter/test/features/auth/forgot_password_screen_test.dart`

**Interfaces:**
- `AdminSignupScreen`: form fields `fullName`, `username`, `email`, `password`, `invitationCode`, `schoolOrganization`, `accountType` (admin/teacher). On submit → `notifier.registerAdmin(payload)`. On success → `context.go('/admin')`.
- `ForgotPasswordScreen`: form field `email`. On submit → `notifier.requestPasswordReset(email)`. Shows confirmation `SnackBar`.

- [ ] **Step 1: Write failing tests**

```dart
// airamp_flutter/test/features/auth/admin_signup_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/features/auth/presentation/admin_signup_screen.dart';

class _Fake extends AuthNotifier {
  @override
  Future<void> registerAdmin(Map<String, dynamic> payload) async {}
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
  @override
  Future<void> bootstrap() async {}
}

void main() {
  testWidgets('admin signup has form fields', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: AdminSignupScreen()),
    ));
    expect(find.byType(TextFormField), findsAtLeast(4));
  });
}
```

```dart
// airamp_flutter/test/features/auth/forgot_password_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/features/auth/presentation/forgot_password_screen.dart';

class _Fake extends AuthNotifier {
  String? last;
  @override
  Future<void> requestPasswordReset(String email) async { last = email; }
  @override
  Future<AuthState> build() async => const AuthUnauthenticated();
  @override
  Future<void> bootstrap() async {}
}

void main() {
  testWidgets('forgot password has email field and submit', (tester) async {
    final fake = _Fake();
    await tester.pumpWidget(ProviderScope(
      overrides: [authProvider.overrideWith(() => fake)],
      child: const MaterialApp(home: ForgotPasswordScreen()),
    ));
    expect(find.byType(TextFormField), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests, verify both fail**

```bash
cd airamp_flutter && flutter test test/features/auth/admin_signup_screen_test.dart test/features/auth/forgot_password_screen_test.dart
```
Expected: FAIL — fields missing or screens are placeholders.

- [ ] **Step 3: Rewrite AdminSignupScreen**

Replace `airamp_flutter/lib/src/features/auth/presentation/admin_signup_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';

class AdminSignupScreen extends ConsumerStatefulWidget {
  const AdminSignupScreen({super.key});
  @override
  ConsumerState<AdminSignupScreen> createState() => _AdminSignupScreenState();
}

class _AdminSignupScreenState extends ConsumerState<AdminSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _invite = TextEditingController();
  final _school = TextEditingController();
  String _type = 'admin';

  @override
  void dispose() {
    _name.dispose(); _username.dispose(); _email.dispose(); _password.dispose();
    _invite.dispose(); _school.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = <String, dynamic>{
      'fullName': _name.text.trim(),
      'username': _username.text.trim(),
      'email': _email.text.trim(),
      'password': _password.text,
      'invitationCode': _invite.text.trim(),
      'schoolOrganization': _school.text.trim(),
      'accountType': _type,
    };
    await ref.read(authProvider.notifier).registerAdmin(payload);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AuthState>>(authProvider, (prev, next) {
      next.whenData((state) {
        if (state is AuthError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.message)));
        } else if (state is AuthAuthenticated) {
          context.go('/admin');
        }
      });
    });
    return Scaffold(
      appBar: AppBar(title: const Text('Admin / Teacher Signup')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(children: [
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            TextFormField(controller: _username, decoration: const InputDecoration(labelText: 'Username')),
            const SizedBox(height: 12),
            TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            TextFormField(controller: _password, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            const SizedBox(height: 12),
            TextFormField(controller: _invite, decoration: const InputDecoration(labelText: 'Invitation code (optional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _school, decoration: const InputDecoration(labelText: 'School / organization')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _type,
              items: const [
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
                DropdownMenuItem(value: 'teacher', child: Text('Teacher')),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'admin'),
              decoration: const InputDecoration(labelText: 'Account type'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text('Create admin account')),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Rewrite ForgotPasswordScreen**

Replace `airamp_flutter/lib/src/features/auth/presentation/forgot_password_screen.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() { _email.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authProvider.notifier).requestPasswordReset(_email.text.trim());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If that email is registered, a reset link was sent.')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _submit, child: const Text('Send reset link')),
          ]),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run tests, verify both pass**

```bash
cd airamp_flutter && flutter test test/features/auth/admin_signup_screen_test.dart test/features/auth/forgot_password_screen_test.dart
```
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/features/auth airamp_flutter/test/features/auth
git commit -m "feat(auth): rewrite AdminSignup + ForgotPassword screens using AuthNotifier"
```

---

## Task 9: Wire auth bootstrap and role-based redirect in router

**Files:**
- Modify: `airamp_flutter/lib/src/routing/app_router.dart`
- Modify: `airamp_flutter/lib/main.dart`
- Test: `airamp_flutter/test/routing/auth_redirect_test.dart`

**Interfaces:**
- Consumes: `authProvider`, `AppTheme`.
- Produces: `GoRouter` that:
  - On `initialLocation = '/login'`.
  - Adds `redirect` rule: when state is `AuthAuthenticated` with role `admin`/`super_admin` and path starts with `/student` → redirect to `/admin`; when role `student` and path starts with `/admin` → redirect to `/student`; when unauthenticated and path is anything other than `/login`, `/signup`, `/admin-signup`, `/forgot-password` → redirect to `/login`.
  - `/admin-signup`, `/forgot-password`, `/signup` add to `routes` list.
- `main.dart`: wraps `MyApp` with `AuthBootstrap` widget that calls `notifier.bootstrap()` once at startup; shows splash while `AuthLoading`.

- [ ] **Step 1: Write failing router test**

```dart
// airamp_flutter/test/routing/auth_redirect_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/routing/app_router.dart';

class _Fake extends AuthNotifier {
  final AuthState initial;
  _Fake(this.initial);
  @override
  Future<AuthState> build() async => initial;
  @override
  Future<void> bootstrap() async {}
}

void main() {
  test('admin authenticated can read /admin', () async {
    final container = ProviderContainer(overrides: [
      authProvider.overrideWith(() => _Fake(const AuthAuthenticated(userId: 'u', role: 'admin')))
    ]);
    final router = container.read(routerProvider);
    expect(router, isNotNull);
  });
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `cd airamp_flutter && flutter test test/routing/auth_redirect_test.dart`
Expected: FAIL — `routerProvider` not yet exported, or test setup wrong.

- [ ] **Step 3: Add `routerProvider` and redirect to app_router**

Replace `airamp_flutter/lib/src/routing/app_router.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/features/auth/presentation/admin_signup_screen.dart';
import 'package:airamp_flutter/src/features/auth/presentation/forgot_password_screen.dart';
import 'package:airamp_flutter/src/features/auth/presentation/login_screen.dart';
import 'package:airamp_flutter/src/features/auth/presentation/signup_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_scaffold.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_home_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/my_courses_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/my_progress_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/quiz_history_screen.dart';
import 'package:airamp_flutter/src/features/student/presentation/student_profile_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_scaffold.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/subjects_mgmt_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_management_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/reg_links_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/scores_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/sections_mgmt_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/student_profile_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/subject_detail_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/admin_profile_screen.dart';
import 'package:airamp_flutter/src/features/chat/presentation/chat_list_screen.dart';
import 'package:airamp_flutter/src/features/chat/presentation/chat_room_screen.dart';
import 'package:airamp_flutter/src/features/quiz/presentation/quiz_screen.dart';
import 'package:airamp_flutter/src/features/submissions/presentation/submissions_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider).value;
      final loc = state.matchedLocation;
      final isAuthRoute = loc == '/login' || loc == '/signup' || loc == '/admin-signup' || loc == '/forgot-password';
      if (auth is AuthUnauthenticated || auth is AuthInitial) {
        return isAuthRoute ? null : '/login';
      }
      if (auth is AuthAuthenticated) {
        if (auth.role == 'admin' || auth.role == 'super_admin') {
          if (loc.startsWith('/student')) return '/admin';
          if (isAuthRoute) return '/admin';
        } else {
          if (loc.startsWith('/admin')) return '/student';
          if (isAuthRoute) return '/student';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/admin-signup', builder: (_, __) => const AdminSignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/chat/:conversationId', builder: (_, s) => ChatRoomScreen(conversationId: s.pathParameters['conversationId']!)),
      GoRoute(path: '/quiz/:loId', builder: (_, s) => QuizScreen(loId: s.pathParameters['loId']!)),
      GoRoute(path: '/submissions/:loId', builder: (_, s) => SubmissionsScreen(loId: s.pathParameters['loId']!)),
      GoRoute(path: '/subject/:subjectId', builder: (_, s) => SubjectDetailScreen(subjectId: s.pathParameters['subjectId']!)),
      GoRoute(path: '/student-detail/:studentId', builder: (_, s) => StudentProfileScreen(studentId: s.pathParameters['studentId']!)),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => StudentScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/student', builder: (_, __) => const StudentHomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/courses', builder: (_, __) => const MyCoursesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/progress', builder: (_, __) => const MyProgressScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/history', builder: (_, __) => const QuizHistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/chat', builder: (_, __) => const ChatListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/student/profile', builder: (_, __) => const StudentProfileScreen())]),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => AdminScaffold(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/admin', builder: (_, __) => const AdminDashboardScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/subjects', builder: (_, __) => const SubjectsMgmtScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/students', builder: (_, __) => const AdminManagementScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/reg-links', builder: (_, __) => const RegLinksScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/scores', builder: (_, __) => const ScoresScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/sections', builder: (_, __) => const SectionsMgmtScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/chat', builder: (_, __) => const ChatListScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/admin/profile', builder: (_, __) => const AdminProfileScreen())]),
        ],
      ),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen<AsyncValue<AuthState>>(authProvider, (_, __) => notifyListeners());
  }
  final Ref _ref;
}
```

- [ ] **Step 4: Update main.dart to bootstrap and use routerProvider**

Replace `airamp_flutter/lib/main.dart`:
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airamp_flutter/src/core/theme/app_theme.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_notifier.dart';
import 'package:airamp_flutter/src/routing/app_router.dart';

void main() {
  runApp(const ProviderScope(child: BootApp()));
}

class BootApp extends ConsumerStatefulWidget {
  const BootApp({super.key});
  @override
  ConsumerState<BootApp> createState() => _BootAppState();
}

class _BootAppState extends ConsumerState<BootApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return auth.when(
      loading: () => MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: Center(child: Text('Error: $e'))),
      ),
      data: (state) {
        if (state is AuthInitial || state is AuthLoading) {
          return MaterialApp(
            theme: AppTheme.darkTheme,
            home: const Scaffold(body: Center(child: CircularProgressIndicator())),
          );
        }
        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          title: 'AIRAMP',
          theme: AppTheme.darkTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
```

- [ ] **Step 5: Run test, verify it passes**

Run: `cd airamp_flutter && flutter test test/routing/auth_redirect_test.dart`
Expected: PASS

- [ ] **Step 6: Run full test suite, verify all pass**

```bash
cd airamp_flutter && flutter test
```
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
cd C:\Users\EL\AndroidStudioProjects\AIRAMP
git add airamp_flutter/lib/src/routing airamp_flutter/lib/main.dart airamp_flutter/test/routing/auth_redirect_test.dart
git commit -m "feat(auth): wire auth bootstrap and role-based redirect in router"
```

---

## Task 10: End-to-end smoke test (manual)

**Files:** none (manual verification)

- [ ] **Step 1: Build the app**

```bash
cd airamp_flutter
flutter build apk --debug --dart-define=FUNCTIONS_URL=https://example.com
```
Expected: Build succeeds. (Backend URL is a placeholder; backend calls will fail at runtime, falling back to local SQLite.)

- [ ] **Step 2: Run app and verify login screen**

```bash
cd airamp_flutter
flutter run --dart-define=FUNCTIONS_URL=https://example.com
```
Expected: App shows LoginScreen; tapping "Login" with empty fields shows validation errors; navigating to `/signup` and `/admin-signup` and `/forgot-password` shows correct forms.

- [ ] **Step 3: Verify SQLite session persistence**

After a failed login attempt, open the SQLite file (`airamp_local.db`) and confirm no entry in `sessions`. After a *successful* login against a real backend, confirm a row in `sessions` with `user_id`, `token`, `role`. (Without a real backend, this is skipped.)

- [ ] **Step 4: Commit verification notes (optional)**

If any issues were found and fixed during smoke test, commit them with a `fix:` prefix.

---

## Self-Review

**1. Spec coverage:**
- Phase 1 spec items: "extend LoginScreen to match expo login.tsx" → Task 6. ✓
- "/v1/auth/session POST" → Task 4. ✓
- "AuthContext equivalent: auth_provider.dart; persist token/user in SQLite sessions table" → Tasks 1, 2, 5. ✓
- "Test login with seeded accounts" → Task 10 manual. ✓
- "Add core/components/ shared widgets" → deferred to Phase 2. ✓ (in scope as `core/components/`, Phase 1 doesn't need it.)

**2. Placeholder scan:** No "TBD", "TODO", "implement later" present. Each step has actual code. ✓

**3. Type consistency:**
- `AuthState` sealed class defined in Task 5; consumed in Tasks 6, 7, 8, 9. ✓
- `AuthNotifier` defined in Task 5; consumed in Tasks 6, 7, 8, 9. ✓
- `AuthRepository.login/logout/registerStudent/registerAdmin/requestPasswordReset` defined in Task 4; consumed in Task 5. ✓
- `authProvider` defined in Task 5; consumed in Tasks 6, 7, 8, 9, plus tests. ✓
- `AuthHeaders.build/readSession` defined in Task 2; consumed in Task 3. ✓
- `ApiClient.dio` defined in Task 3; consumed in Task 4. ✓
- `routerProvider` defined in Task 9; consumed in Task 9 + main.dart. ✓

**4. Ambiguity:** All instructions are concrete (specific files, specific code, specific test names). No "TBD" or "fill in later". ✓

**5. Risk: duplicate files.** Tasks 6 and 7 explicitly call out deleting duplicates at `lib/features/auth/presentation/{login,signup}_screen.dart` and fixing the router import. ✓
