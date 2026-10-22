import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../firebase_options.dart';
import '../api/rate_limit_interceptor.dart';
import 'database_helper.dart';

/// Centralized service connecting AIRA with Cloud Firestore.
/// Manages cloud user persistence, cross-device sync, and authentication lookups
/// with both SDK and high-reliability REST API fallbacks.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  )..interceptors.add(RateLimitInterceptor());

  static const String _envApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _envProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static String get apiKey {
    if (_envApiKey.isNotEmpty) return _envApiKey;
    try {
      if (Firebase.apps.isNotEmpty) {
        return Firebase.app().options.apiKey;
      }
    } catch (_) {}
    try {
      return DefaultFirebaseOptions.currentPlatform.apiKey;
    } catch (_) {}
    return '';
  }

  static String get projectId {
    if (_envProjectId.isNotEmpty) return _envProjectId;
    try {
      if (Firebase.apps.isNotEmpty) {
        return Firebase.app().options.projectId;
      }
    } catch (_) {}
    try {
      return DefaultFirebaseOptions.currentPlatform.projectId;
    } catch (_) {}
    return 'aira-app-database';
  }

  FirebaseFirestore? _firestore;
  bool _useRestPrimary = false;
  bool _isNetworkDisabled = false;
  bool _probeCompleted = false;

  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get firestore {
    _firestore ??= FirebaseFirestore.instance;
    return _firestore!;
  }

  CollectionReference<Map<String, dynamic>> get usersCollection {
    return firestore.collection('users');
  }

  /// Disables native SDK gRPC network channel when gRPC DNS resolution fails on emulators/devices.
  /// This terminates the native background WriteStream and permanently switches to high-reliability HTTPS REST API.
  Future<void> _disableSdkNetwork([dynamic reason]) async {
    if (_isNetworkDisabled) return;
    _isNetworkDisabled = true;
    _useRestPrimary = true;
    if (reason != null) {
      debugPrint('[FirestoreService] Switching to HTTPS REST API (gRPC unavailable: $reason)');
    }
    try {
      if (Firebase.apps.isNotEmpty) {
        await firestore.disableNetwork();
      }
    } catch (_) {}
  }

  /// Proactively probes gRPC stream connectivity once. If it times out or fails (e.g. emulator DNS issue),
  /// it disables the SDK network channel immediately to prevent recurring logcat warnings.
  Future<void> probeConnectivity() async {
    if (_probeCompleted || !isAvailable) return;
    _probeCompleted = true;
    try {
      await usersCollection.limit(1).get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 2));
    } catch (e) {
      await _disableSdkNetwork(e);
    }
  }

  /// Parses Firestore REST API field format into a standard Dart Map
  Map<String, dynamic> _parseFirestoreFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      final val = entry.value;
      if (val is Map) {
        if (val.containsKey('stringValue')) {
          result[entry.key] = val['stringValue'];
        } else if (val.containsKey('integerValue')) {
          result[entry.key] = int.tryParse(val['integerValue'].toString()) ?? val['integerValue'];
        } else if (val.containsKey('doubleValue')) {
          result[entry.key] = double.tryParse(val['doubleValue'].toString()) ?? val['doubleValue'];
        } else if (val.containsKey('booleanValue')) {
          result[entry.key] = val['booleanValue'];
        } else if (val.containsKey('nullValue')) {
          result[entry.key] = null;
        }
      }
    }
    return result;
  }

  /// REST fallback query to find user by field value
  Future<Map<String, dynamic>?> _queryRest(String field, String value) async {
    try {
      final dio = _dio;
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey';
      final response = await dio.post(
        url,
        data: {
          'structuredQuery': {
            'from': [
              {'collectionId': 'users'}
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': field},
                'op': 'EQUAL',
                'value': {'stringValue': value},
              },
            },
            'limit': 1,
          },
        },
      );

      if (response.data is List && (response.data as List).isNotEmpty) {
        for (final item in response.data) {
          if (item is Map && item.containsKey('document')) {
            final doc = item['document'] as Map<String, dynamic>;
            final fields = doc['fields'] as Map<String, dynamic>? ?? {};
            final parsed = _parseFirestoreFields(fields);
            if (parsed.isNotEmpty) {
              if (!parsed.containsKey('id') && doc.containsKey('name')) {
                parsed['id'] = (doc['name'] as String).split('/').last;
              }
              return parsed;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] REST query error for $field=$value: $e');
    }
    return null;
  }

  /// REST fallback to fetch all users from Cloud Firestore
  Future<List<Map<String, dynamic>>> _fetchAllRest() async {
    try {
      final dio = _dio;
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?key=$apiKey&pageSize=100';
      final response = await dio.get(url);
      final list = <Map<String, dynamic>>[];
      if (response.data is Map && response.data.containsKey('documents')) {
        final docs = response.data['documents'] as List? ?? [];
        for (final d in docs) {
          if (d is Map && d.containsKey('fields')) {
            final fields = d['fields'] as Map<String, dynamic>? ?? {};
            final parsed = _parseFirestoreFields(fields);
            if (!parsed.containsKey('id') && d.containsKey('name')) {
              parsed['id'] = (d['name'] as String).split('/').last;
            }
            list.add(parsed);
          }
        }
      }
      return list;
    } catch (e) {
      debugPrint('[FirestoreService] REST fetchAll error: $e');
      return [];
    }
  }

  /// Saves or updates a user document in Cloud Firestore
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final id = userData['id']?.toString();
    if (id == null || id.isEmpty) return;

    final dataToSave = Map<String, dynamic>.from(userData);
    if (dataToSave.containsKey('email') && dataToSave['email'] is String) {
      dataToSave['email_lower'] = (dataToSave['email'] as String).toLowerCase().trim();
    }
    if (dataToSave.containsKey('username') && dataToSave['username'] is String) {
      dataToSave['username_lower'] = (dataToSave['username'] as String).toLowerCase().trim();
    }
    dataToSave['updated_at'] = DateTime.now().toIso8601String();

    // 1. Try Firebase SDK if available and not switched to REST primary
    if (isAvailable && !_useRestPrimary) {
      try {
        await usersCollection.doc(id).set(dataToSave, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
        debugPrint('[FirestoreService] Successfully saved user $id via SDK');
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK save failed, falling back to REST: $e');
        await _disableSdkNetwork(e);
      }
    }

    // 2. REST API Fallback
    try {
      final dio = _dio;
      final fields = <String, dynamic>{};
      for (final entry in dataToSave.entries) {
        final val = entry.value;
        if (val == null) {
          fields[entry.key] = {'nullValue': null};
        } else if (val is bool) {
          fields[entry.key] = {'booleanValue': val};
        } else if (val is int) {
          fields[entry.key] = {'integerValue': val.toString()};
        } else if (val is double) {
          fields[entry.key] = {'doubleValue': val};
        } else {
          fields[entry.key] = {'stringValue': val.toString()};
        }
      }
      final maskQuery = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$id?key=$apiKey&$maskQuery';
      await dio.patch(url, data: {'fields': fields});
      debugPrint('[FirestoreService] Successfully saved user $id via REST');
    } catch (e) {
      debugPrint('[FirestoreService] REST save error: $e');
    }
  }

  /// Searches Cloud Firestore for a user matching ID (e.g. 001-0001), email, username, or full name
  Future<Map<String, dynamic>?> findUserByIdentifier(String identifier) async {
    final idLower = identifier.toLowerCase().trim();
    final rawTrimmed = identifier.trim();
    if (rawTrimmed.isEmpty) return null;

    try {
      return await _findUserInternal(idLower, rawTrimmed)
          .timeout(const Duration(seconds: 4), onTimeout: () => null);
    } catch (e) {
      debugPrint('[FirestoreService] findUserByIdentifier note: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _findUserInternal(String idLower, String rawTrimmed) async {
    final isEmail = rawTrimmed.contains('@');

    // 1. Try SDK if available and not switched to REST primary
    if (isAvailable && !_useRestPrimary) {
      try {
        if (isEmail) {
          // Parallel search targeted to email fields
          final results = await Future.wait([
            usersCollection.where('email_lower', isEqualTo: idLower).limit(1).get().timeout(const Duration(seconds: 3)),
            usersCollection.where('email', isEqualTo: rawTrimmed).limit(1).get().timeout(const Duration(seconds: 3)),
            usersCollection.doc(idLower).get().timeout(const Duration(seconds: 3)),
          ]);
          for (final snap in results) {
            if (snap is QuerySnapshot<Map<String, dynamic>> && snap.docs.isNotEmpty) {
              final d = snap.docs.first.data();
              if (!d.containsKey('id')) d['id'] = snap.docs.first.id;
              return d;
            } else if (snap is DocumentSnapshot<Map<String, dynamic>> && snap.exists && snap.data() != null) {
              final d = snap.data()!;
              if (!d.containsKey('id')) d['id'] = snap.id;
              return d;
            }
          }
        } else {
          // Parallel search targeted to user ID and username
          final results = await Future.wait([
            usersCollection.doc(rawTrimmed).get().timeout(const Duration(seconds: 3)),
            usersCollection.where('id', isEqualTo: rawTrimmed).limit(1).get().timeout(const Duration(seconds: 3)),
            usersCollection.where('username_lower', isEqualTo: idLower).limit(1).get().timeout(const Duration(seconds: 3)),
            usersCollection.where('username', isEqualTo: rawTrimmed).limit(1).get().timeout(const Duration(seconds: 3)),
          ]);
          for (final snap in results) {
            if (snap is DocumentSnapshot<Map<String, dynamic>> && snap.exists && snap.data() != null) {
              final d = snap.data()!;
              if (!d.containsKey('id')) d['id'] = snap.id;
              return d;
            } else if (snap is QuerySnapshot<Map<String, dynamic>> && snap.docs.isNotEmpty) {
              final d = snap.docs.first.data();
              if (!d.containsKey('id')) d['id'] = snap.docs.first.id;
              return d;
            }
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] SDK search note: $e');
        await _disableSdkNetwork(e);
      }
    }

    // 2. High-reliability REST query fallback
    try {
      if (isEmail) {
        final results = await Future.wait([
          _queryRest('email_lower', idLower),
          _queryRest('email', rawTrimmed),
        ]);
        for (final r in results) {
          if (r != null && r.isNotEmpty) return r;
        }
      } else {
        // Direct document fetch by ID
        try {
          final dio = _dio;
          final docUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$rawTrimmed?key=$apiKey';
          final docResp = await dio.get(docUrl);
          if (docResp.statusCode == 200 && docResp.data is Map && docResp.data['fields'] is Map) {
            final parsed = _parseFirestoreFields(docResp.data['fields'] as Map<String, dynamic>);
            if (parsed.isNotEmpty) {
              if (!parsed.containsKey('id')) parsed['id'] = rawTrimmed;
              return parsed;
            }
          }
        } catch (_) {}

        final results = await Future.wait([
          _queryRest('id', rawTrimmed),
          _queryRest('username_lower', idLower),
          _queryRest('username', rawTrimmed),
        ]);
        for (final r in results) {
          if (r != null && r.isNotEmpty) return r;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Fetches all users from Cloud Firestore (via SDK or REST fallback)
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    List<Map<String, dynamic>> cloudUsers = [];
    if (isAvailable && !_useRestPrimary) {
      try {
        final snapshot = await usersCollection.get().timeout(const Duration(seconds: 3));
        cloudUsers = snapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (e) {
        await _disableSdkNetwork(e);
      }
    }
    if (cloudUsers.isEmpty) {
      cloudUsers = await _fetchAllRest();
    }
    return cloudUsers;
  }

  /// Checks if an email is already registered in Cloud Firestore
  Future<bool> isEmailRegistered(String email) async {
    final emailLower = email.toLowerCase().trim();
    final user = await findUserByIdentifier(emailLower);
    return user != null;
  }

  /// Syncs all existing local SQLite users to Cloud Firestore so no authentic accounts are lost
  Future<void> syncLocalUsersToCloud() async {
    try {
      final db = await DatabaseHelper().database;
      final localUsers = await db.query('users');
      int pushedCount = 0;
      for (final user in localUsers) {
        final email = (user['email'] as String? ?? '').toLowerCase().trim();
        final id = (user['id'] as String? ?? '').toLowerCase().trim();
        final isTestDummy = email.contains('newstudent_') ||
            email.contains('dup_student_') ||
            email.contains('newteacher_') ||
            email.contains('test_') ||
            email.contains('security_test_') ||
            email.contains('legacy_user_') ||
            email.contains('@school.edu') ||
            email == 'maria@test.com' ||
            id.startsWith('student_test_') ||
            id.startsWith('teacher_test_');
        if (isTestDummy) continue;

        await saveUser(user);
        pushedCount++;
      }
      debugPrint('[FirestoreService] Pushed $pushedCount authentic local users to Cloud Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] Error pushing local users to Cloud: $e');
    }
  }

  /// Syncs Cloud Firestore users down to local SQLite cache and prunes deleted accounts
  Future<void> syncCloudUsersToLocal() async {
    try {
      List<Map<String, dynamic>> cloudUsers = [];

      if (isAvailable && !_useRestPrimary) {
        try {
          final snapshot = await usersCollection.get().timeout(const Duration(seconds: 3));
          cloudUsers = snapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        } catch (e) {
          await _disableSdkNetwork(e);
        }
      }

      if (cloudUsers.isEmpty) {
        cloudUsers = await _fetchAllRest();
      }

      if (cloudUsers.isEmpty) return;

      final db = await DatabaseHelper().database;

      final cloudIds = <String>{};
      final cloudEmails = <String>{};

      for (final data in cloudUsers) {
        try {
          final userId = data['id']?.toString();
          if (userId == null || userId.isEmpty) continue;
          final email = (data['email']?.toString() ?? '').toLowerCase().trim();
          cloudIds.add(userId);
          if (email.isNotEmpty) cloudEmails.add(email);

          List<Map<String, dynamic>> existing = await db.query('users', where: 'id = ?', whereArgs: [userId]);
          if (existing.isEmpty && email.isNotEmpty) {
            existing = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [email]);
          }

          final cloudMust = data['must_change_password'] == 1 ||
              data['must_change_password'] == true ||
              data['must_change_password'] == '1';
          final localMust = existing.isNotEmpty &&
              (existing.first['must_change_password'] == 1 ||
               existing.first['must_change_password'] == true ||
               existing.first['must_change_password'] == '1');
          bool prefMust = false;
          try {
            final prefs = await SharedPreferences.getInstance();
            prefMust = prefs.getBool('must_change_password_$userId') == true;
          } catch (_) {}
          final mustChangeVal = (cloudMust || localMust || prefMust) ? 1 : 0;
          if (mustChangeVal == 1) {
            try {
              await db.update('sessions', {'must_change_password': 1},
                  where: 'user_id = ?', whereArgs: [userId]);
            } catch (_) {}
          }

          final dbRow = {
            'id': existing.isNotEmpty ? existing.first['id'] : userId,
            'email': data['email'] ?? '',
            'username': data['username'] ?? '',
            'password': data['password'] ?? '',
            'password_salt': data['password_salt'],
            'role': data['role'] ?? 'student',
            'full_name': data['full_name'] ?? data['name'] ?? '',
            'section': data['section'],
            'grade': data['grade'],
            'student_type': data['student_type'] ?? 'regular',
            'special_notes': data['special_notes'],
            'school_id': data['school_id'] ?? 'sch_main',
            'must_change_password': mustChangeVal,
            'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
          };

          if (existing.isEmpty) {
            await db.insert('users', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            final targetId = existing.first['id'];
            await db.update('users', dbRow, where: 'id = ?', whereArgs: [targetId]);
          }
        } catch (e) {
          debugPrint('[FirestoreService] Note syncing user ${data['id']}: $e');
        }
      }

      // Prune local SQLite users that no longer exist in Cloud Firestore
      final localUsers = await db.query('users');
      for (final local in localUsers) {
        final localId = local['id']?.toString() ?? '';
        final localEmail = (local['email']?.toString() ?? '').toLowerCase().trim();

        // Keep system super_admin seeds if needed, otherwise verify presence in cloud
        final isPermanentSeed = localId == 'admin_1' || localId == 'superadmin_1';
        if (!isPermanentSeed && !cloudIds.contains(localId) && !cloudEmails.contains(localEmail)) {
          await db.delete('users', where: 'id = ?', whereArgs: [localId]);
          try {
            await db.delete('enrollments', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('quiz_attempts', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('student_progress', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('submissions', where: 'student_id = ?', whereArgs: [localId]);
          } catch (_) {}
          debugPrint('[FirestoreService] Pruned obsolete local user: $localId ($localEmail)');
        }
      }

      debugPrint('[FirestoreService] Synced ${cloudUsers.length} Cloud Firestore users to local SQLite cache');
    } catch (e) {
      debugPrint('[FirestoreService] Error syncing cloud users to local SQLite: $e');
    }
  }

  /// Generic helper to save or merge a document in any collection
  Future<void> saveDocument(String collection, String docId, Map<String, dynamic> data) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    if (isAvailable) {
      try {
        await firestore.collection(collection).doc(cleanDocId).set(data, SetOptions(merge: true))
            .timeout(const Duration(seconds: 3));
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK saveDocument error: $e');
      }
    }

    try {
      final dio = _dio;
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$cleanDocId?key=$apiKey';
      final fields = <String, dynamic>{};
      for (final entry in data.entries) {
        final val = entry.value;
        if (val == null) {
          fields[entry.key] = {'nullValue': null};
        } else if (val is bool) {
          fields[entry.key] = {'booleanValue': val};
        } else if (val is int) {
          fields[entry.key] = {'integerValue': val.toString()};
        } else if (val is double) {
          fields[entry.key] = {'doubleValue': val};
        } else {
          fields[entry.key] = {'stringValue': val.toString()};
        }
      }
      await dio.patch(url, data: {'fields': fields});
    } catch (e) {
      debugPrint('[FirestoreService] REST saveDocument error: $e');
    }
  }

  /// Generic helper to fetch a document from any collection
  Future<Map<String, dynamic>?> getDocument(String collection, String docId) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return null;

    if (isAvailable) {
      try {
        final snap = await firestore.collection(collection).doc(cleanDocId).get()
            .timeout(const Duration(seconds: 3));
        if (snap.exists && snap.data() != null) {
          final res = snap.data()!;
          res['id'] = snap.id;
          return res;
        }
      } catch (e) {
        debugPrint('[FirestoreService] SDK getDocument error: $e');
      }
    }

    try {
      final dio = _dio;
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$cleanDocId?key=$apiKey';
      final resp = await dio.get(url);
      if (resp.statusCode == 200 && resp.data is Map && resp.data['fields'] is Map) {
        final parsed = _parseFirestoreFields(resp.data['fields'] as Map<String, dynamic>);
        if (parsed.isNotEmpty) {
          parsed['id'] = cleanDocId;
          return parsed;
        }
      }
    } catch (_) {}

    return null;
  }

  /// Generic helper to delete a document from any collection in Cloud Firestore
  Future<void> deleteDocument(String collection, String docId) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    if (isAvailable && !_useRestPrimary) {
      try {
        await firestore
            .collection(collection)
            .doc(cleanDocId)
            .delete()
            .timeout(const Duration(seconds: 3));
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK deleteDocument error: $e');
        await _disableSdkNetwork(e);
      }
    }

    try {
      final dio = _dio;
      final keyParam = apiKey.isNotEmpty ? '?key=$apiKey' : '';
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$cleanDocId$keyParam';
      await dio.delete(url);
      debugPrint('[FirestoreService] Successfully deleted document $collection/$cleanDocId via REST');
    } catch (e) {
      debugPrint('[FirestoreService] REST deleteDocument error: $e');
    }
  }

  /// Deletes a user document from Cloud Firestore, ensuring both direct ID and email matches are purged
  Future<void> deleteUser(String userId, {String? email}) async {
    final cleanId = userId.trim();
    if (cleanId.isNotEmpty) {
      await deleteDocument('users', cleanId);
    }
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    if (cleanEmail.isNotEmpty && cleanEmail != cleanId.toLowerCase()) {
      await deleteDocument('users', cleanEmail);
    }
  }
}

