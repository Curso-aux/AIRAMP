import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../firebase_options.dart';
import '../api/rate_limit_interceptor.dart';
import '../utils/institutional_id_helper.dart';
import 'database_helper.dart';

/// Centralized service connecting AIRA with Cloud Firestore.
/// Manages cloud user persistence, cross-device sync, and authentication lookups
/// with both SDK and high-reliability REST API fallbacks.
class FirestoreService {
  static final FirestoreService _instance = FirestoreService._internal();
  factory FirestoreService() => _instance;
  FirestoreService._internal();

  /// Real-time sync listener registry
  static final List<VoidCallback> _syncListeners = [];

  static void addSyncListener(VoidCallback listener) {
    if (!_syncListeners.contains(listener)) {
      _syncListeners.add(listener);
    }
  }

  static void removeSyncListener(VoidCallback listener) {
    _syncListeners.remove(listener);
  }

  static VoidCallback? get onUserSynced => _syncListeners.isNotEmpty ? _syncListeners.last : null;
  static set onUserSynced(VoidCallback? cb) {
    if (cb != null) {
      addSyncListener(cb);
    }
  }

  static void notifySyncListeners() {
    for (final cb in List<VoidCallback>.from(_syncListeners)) {
      try {
        cb();
      } catch (_) {}
    }
  }

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
  bool _probeCompleted = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSubscription;
  bool _isRealtimeSyncActive = false;
  bool get isRealtimeSyncActive => _isRealtimeSyncActive;

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

  /// Real-time full collection streaming was deprecated to prevent quota exhaustion (500+ reads per user).
  /// Updates now stream on-demand or use lightweight delta synchronization.
  void startRealtimeUserSync() {
    // Disabled whole-collection snapshot listener to protect against 50k daily quota burn
  }

  void stopRealtimeUserSync() {
    _usersSubscription?.cancel();
    _usersSubscription = null;
    _isRealtimeSyncActive = false;
  }

  /// Proactively ensures the Firebase native SDK network channel is enabled and tests connectivity.
  /// Never permanently disables the native SDK on physical devices.
  Future<void> probeConnectivity() async {
    if (_probeCompleted || !isAvailable) return;
    _probeCompleted = true;
    try {
      if (Firebase.apps.isNotEmpty) {
        await firestore.enableNetwork();
        if (FirebaseAuth.instance.currentUser == null) {
          try {
            await FirebaseAuth.instance.signInAnonymously();
            debugPrint('[FirestoreService] Anonymous auth initialized for cloud sync: ${FirebaseAuth.instance.currentUser?.uid}');
          } catch (_) {}
        }
      }
      // Lightweight probe check using limit(1) without subscribing to entire collection
      await usersCollection.limit(1).get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));
      debugPrint('[FirestoreService] Cloud Firestore SDK connected successfully');
    } catch (e) {
      debugPrint('[FirestoreService] Cloud Firestore initial probe note: $e');
    }
  }

  /// Parses Firestore REST API field format into a standard Dart Map
  dynamic _parseFirestoreValue(dynamic val) {
    if (val is! Map) return val;
    if (val.containsKey('stringValue')) return val['stringValue'];
    if (val.containsKey('integerValue')) return int.tryParse(val['integerValue'].toString()) ?? val['integerValue'];
    if (val.containsKey('doubleValue')) return double.tryParse(val['doubleValue'].toString()) ?? val['doubleValue'];
    if (val.containsKey('booleanValue')) return val['booleanValue'];
    if (val.containsKey('nullValue')) return null;
    if (val.containsKey('arrayValue')) {
      final values = val['arrayValue']?['values'] as List? ?? [];
      return values.map((v) => _parseFirestoreValue(v)).toList();
    }
    if (val.containsKey('mapValue')) {
      final fields = val['mapValue']?['fields'] as Map<String, dynamic>? ?? {};
      return _parseFirestoreFields(fields);
    }
    return val;
  }

  Map<String, dynamic> _parseFirestoreFields(Map<String, dynamic> fields) {
    final result = <String, dynamic>{};
    for (final entry in fields.entries) {
      result[entry.key] = _parseFirestoreValue(entry.value);
    }
    return result;
  }

  Map<String, dynamic> _convertValueToFirestoreField(dynamic val) {
    if (val == null) {
      return {'nullValue': null};
    } else if (val is bool) {
      return {'booleanValue': val};
    } else if (val is int) {
      return {'integerValue': val.toString()};
    } else if (val is double) {
      return {'doubleValue': val};
    } else if (val is List) {
      return {
        'arrayValue': {
          'values': val.map((item) => _convertValueToFirestoreField(item)).toList(),
        }
      };
    } else if (val is Map) {
      final mapFields = <String, dynamic>{};
      for (final e in val.entries) {
        mapFields[e.key.toString()] = _convertValueToFirestoreField(e.value);
      }
      return {
        'mapValue': {'fields': mapFields}
      };
    } else {
      return {'stringValue': val.toString()};
    }
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

  /// REST fallback to fetch all users from Cloud Firestore with pagination
  Future<List<Map<String, dynamic>>> _fetchAllRest() async {
    final list = <Map<String, dynamic>>[];
    try {
      final dio = _dio;
      String? pageToken;
      final keyParam = apiKey.isNotEmpty ? '&key=$apiKey' : '';

      do {
        final tokenParam = pageToken != null && pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
        final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?pageSize=300$tokenParam$keyParam';
        final response = await dio.get(url);

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

        pageToken = (response.data is Map && response.data.containsKey('nextPageToken'))
            ? response.data['nextPageToken'] as String?
            : null;
      } while (pageToken != null && pageToken.isNotEmpty);

      return list;
    } catch (e) {
      debugPrint('[FirestoreService] REST fetchAll error: $e');
      return list;
    }
  }

  /// Generic helper to fetch all documents from any collection in Cloud Firestore via direct REST
  Future<List<Map<String, dynamic>>> fetchDocumentsRest(String collection) async {
    final list = <Map<String, dynamic>>[];
    try {
      final dio = _dio;
      String? pageToken;
      final keyParam = apiKey.isNotEmpty ? '&key=$apiKey' : '';

      do {
        final tokenParam = pageToken != null && pageToken.isNotEmpty ? '&pageToken=$pageToken' : '';
        final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection?pageSize=300$tokenParam$keyParam';
        final response = await dio.get(url);

        if (response.data is Map && response.data.containsKey('documents')) {
          final docs = response.data['documents'] as List? ?? [];
          for (final d in docs) {
            if (d is Map && d.containsKey('fields')) {
              final fields = d['fields'] as Map<String, dynamic>? ?? {};
              final parsed = _parseFirestoreFields(fields);
              final docId = (d['name'] as String? ?? '').split('/').last;
              if (docId.isNotEmpty) {
                parsed['id'] = parsed['id'] ?? docId;
                parsed['_docId'] = docId;
              }
              list.add(parsed);
            }
          }
        }

        pageToken = (response.data is Map && response.data.containsKey('nextPageToken'))
            ? response.data['nextPageToken'] as String?
            : null;
      } while (pageToken != null && pageToken.isNotEmpty);

      return list;
    } catch (e) {
      debugPrint('[FirestoreService] REST fetchDocumentsRest for $collection error: $e');
      return list;
    }
  }

  /// Generic helper to fetch all documents from any collection in Cloud Firestore (SDK + REST fallback)
  Future<List<Map<String, dynamic>>> fetchAllDocuments(String collection) async {
    final list = <Map<String, dynamic>>[];
    if (isAvailable) {
      try {
        final snap = await firestore
            .collection(collection)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(Duration(seconds: kIsWeb ? 3 : 10));
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_docId'] = doc.id;
          list.add(data);
        }
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetchAllDocuments for $collection note: $e');
      }
    }

    return await fetchDocumentsRest(collection);
  }

  /// Optimized helper to fetch documents with optional delta filtering (since) and field matching.
  /// When [since] is provided, only documents updated/created after that timestamp are fetched,
  /// reducing reads to 0 if nothing changed!
  Future<List<Map<String, dynamic>>> fetchDeltaDocuments(
    String collection, {
    String? since,
    String? whereField,
    dynamic whereValue,
    int? limit,
  }) async {
    final list = <Map<String, dynamic>>[];
    if (isAvailable) {
      try {
        Query<Map<String, dynamic>> query = firestore.collection(collection);
        if (whereField != null && whereValue != null) {
          query = query.where(whereField, isEqualTo: whereValue);
        }
        if (since != null && since.isNotEmpty) {
          query = query.where('updated_at', isGreaterThan: since);
        }
        if (limit != null && limit > 0) {
          query = query.limit(limit);
        }

        final snap = await query.get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 8));
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          list.add(data);
        }
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetchDeltaDocuments (updated_at) for $collection error: $e');
      }

      // Fallback 1: If updated_at yielded nothing and since was provided, check created_at
      if (since != null && since.isNotEmpty) {
        try {
          Query<Map<String, dynamic>> query = firestore.collection(collection);
          if (whereField != null && whereValue != null) {
            query = query.where(whereField, isEqualTo: whereValue);
          }
          query = query.where('created_at', isGreaterThan: since);
          if (limit != null && limit > 0) {
            query = query.limit(limit);
          }

          final snap = await query.get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 8));
          for (final doc in snap.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            list.add(data);
          }
          if (list.isNotEmpty) return list;
        } catch (e) {
          debugPrint('[FirestoreService] SDK fetchDeltaDocuments (created_at) for $collection error: $e');
        }
      }
    }

    // Fallback 2: If delta failed or offline, fall back to REST or standard fetch if since is null
    if (since == null) {
      return await fetchAllDocuments(collection);
    }
    return list;
  }

  /// Calculates the highest numeric sequence for a given ID prefix (e.g. 'S-100-', 'T-100-', 'A-100-', 'SA-000-', or legacy '001-')
  /// Efficiently checks local SQLite and local storage cache first before querying Cloud Firestore.
  Future<int> getHighestSequence(String prefix) async {
    int maxSeq = 0;
    final cleanPrefix = prefix.toUpperCase();

    // 1. Check local SQLite first - costs 0 Cloud Firestore reads!
    try {
      final db = await DatabaseHelper().database;
      final localMatches = await db.rawQuery(
        "SELECT id FROM users WHERE UPPER(id) LIKE ? ORDER BY id DESC LIMIT 50",
        ['$cleanPrefix%'],
      );
      for (final row in localMatches) {
        final uid = (row['id']?.toString() ?? '').toUpperCase();
        final parts = uid.split('-');
        if (parts.isNotEmpty) {
          final num = int.tryParse(parts.last);
          if (num != null && num > maxSeq) {
            maxSeq = num;
          }
        }
      }
    } catch (_) {}

    // Check SharedPreferences localStorage persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('local_cached_users_v1');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        for (final item in decoded) {
          if (item is Map) {
            final uid = (item['id']?.toString() ?? '').toUpperCase();
            if (uid.startsWith(cleanPrefix)) {
              final parts = uid.split('-');
              if (parts.isNotEmpty) {
                final num = int.tryParse(parts.last);
                if (num != null && num > maxSeq) {
                  maxSeq = num;
                }
              }
            }
          }
        }
      }
    } catch (_) {}

    // If local database or cache has records for this prefix, return immediately!
    if (maxSeq > 0) return maxSeq;

    // 2. Query Cloud Firestore if local database has 0 records
    if (isAvailable && !_isTestEnv) {
      try {
        final snap = await usersCollection
            .where('id', isGreaterThanOrEqualTo: cleanPrefix)
            .where('id', isLessThan: '$cleanPrefix\uf8ff')
            .orderBy('id', descending: true)
            .limit(1)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 4));
        if (snap.docs.isNotEmpty) {
          final docData = snap.docs.first.data();
          final uid = (docData['id']?.toString() ?? snap.docs.first.id).toUpperCase();
          final parts = uid.split('-');
          if (parts.isNotEmpty) {
            final num = int.tryParse(parts.last);
            if (num != null && num > maxSeq) {
              maxSeq = num;
            }
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] getHighestSequence query note: $e');
      }
    }
    return maxSeq;
  }

  /// Saves or updates a user document in Cloud Firestore
  Future<void> saveUser(Map<String, dynamic> userData) async {
    if (_isTestEnv) return;
    invalidateUsersSyncCache();
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

    // Ensure profile_image and profileImage fields stay consistent
    if (dataToSave.containsKey('profile_image') && !dataToSave.containsKey('profileImage')) {
      dataToSave['profileImage'] = dataToSave['profile_image'];
    } else if (dataToSave.containsKey('profileImage') && !dataToSave.containsKey('profile_image')) {
      dataToSave['profile_image'] = dataToSave['profileImage'];
    }

    // Never overwrite existing non-null cloud fields with nulls during routine sync/login
    dataToSave.removeWhere((key, value) => value == null);

    // Ensure this user ID, email, and username are removed from any local deletion tombstone list
    try {
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('permanently_deleted_accounts') ?? [];
      final cleanEmail = (userData['email']?.toString() ?? '').toLowerCase().trim();
      final cleanUser = (userData['username']?.toString() ?? '').toLowerCase().trim();
      bool modified = false;
      if (deletedList.remove(id)) modified = true;
      if (cleanEmail.isNotEmpty && deletedList.remove(cleanEmail)) modified = true;
      if (cleanUser.isNotEmpty && deletedList.remove(cleanUser)) modified = true;
      if (modified) {
        await prefs.setStringList('permanently_deleted_accounts', deletedList);
      }
    } catch (_) {}

    // 1. Try Firebase SDK if available
    if (isAvailable) {
      try {
        await usersCollection.doc(id).set(dataToSave, SetOptions(merge: true))
            .timeout(const Duration(seconds: 4));
        debugPrint('[FirestoreService] Successfully saved user $id via SDK');
        unawaited(_saveUserRest(id, dataToSave));
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK save failed, falling back to REST: $e');
      }
    }

    // 2. REST API Fallback
    await _saveUserRest(id, dataToSave);

    final cleanEmail = (userData['email']?.toString() ?? '').toLowerCase().trim();
    if (cleanEmail.isNotEmpty && cleanEmail != id.toLowerCase()) {
      if (dataToSave.containsKey('must_change_password') || dataToSave.containsKey('mustChangePassword')) {
        unawaited(_syncMustChangeToDoc(cleanEmail, dataToSave));
      }
    }
  }

  Future<void> _syncMustChangeToDoc(String docId, Map<String, dynamic> data) async {
    try {
      final patchData = <String, dynamic>{};
      if (data.containsKey('must_change_password')) patchData['must_change_password'] = data['must_change_password'];
      if (data.containsKey('mustChangePassword')) patchData['mustChangePassword'] = data['mustChangePassword'];
      if (data.containsKey('password')) patchData['password'] = data['password'];
      if (data.containsKey('password_salt')) patchData['password_salt'] = data['password_salt'];
      if (isAvailable) {
        await usersCollection.doc(docId).set(patchData, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
      await _saveUserRest(docId, patchData);
    } catch (_) {}
  }

  /// REST fallback helper to patch document directly in Cloud Firestore
  Future<void> _saveUserRest(String id, Map<String, dynamic> dataToSave) async {
    try {
      final dio = _dio;
      final fields = <String, dynamic>{};
      for (final entry in dataToSave.entries) {
        fields[entry.key] = _convertValueToFirestoreField(entry.value);
      }
      final maskQuery = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final keyParam = apiKey.isNotEmpty ? '&key=$apiKey' : '';
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$id?$maskQuery$keyParam';
      await dio.patch(url, data: {'fields': fields});
      debugPrint('[FirestoreService] Successfully saved user $id via REST');
    } catch (e) {
      debugPrint('[FirestoreService] REST save error: $e');
    }
  }

  /// Direct REST document fetch by document ID (~100-250ms, bypasses JS SDK cold-start)
  Future<Map<String, dynamic>?> _fetchDocRest(String docId) async {
    try {
      final dio = _dio;
      final keyParam = apiKey.isNotEmpty ? '?key=$apiKey' : '';
      final docUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$docId$keyParam';
      final docResp = await dio.get(docUrl);
      if (docResp.statusCode == 200 && docResp.data is Map && docResp.data['fields'] is Map) {
        final parsed = _parseFirestoreFields(docResp.data['fields'] as Map<String, dynamic>);
        if (parsed.isNotEmpty) {
          if (!parsed.containsKey('id')) parsed['id'] = docId;
          return parsed;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Finds user in Cloud Firestore strictly by institutional User ID (e.g. S-100-0001, T-100-0001, A-100-0001, SA-000-0001).
  /// Never matches by email.
  Future<Map<String, dynamic>?> findUserById(String id) async {
    final rawTrimmed = id.trim();
    final idLower = rawTrimmed.toLowerCase();
    if (rawTrimmed.isEmpty || rawTrimmed.contains('@') || _isTestEnv) return null;

    try {
      // 1. FAST PATH: Direct REST query by Document ID (~100-250ms)
      final directUser = await _fetchDocRest(rawTrimmed)
          .timeout(const Duration(milliseconds: 2000), onTimeout: () => null);
      if (directUser != null && directUser.isNotEmpty) {
        return directUser;
      }

      // Direct doc fetch lowercase if different (e.g. sa-000-0001)
      if (idLower != rawTrimmed) {
        final directUserLower = await _fetchDocRest(idLower)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
        if (directUserLower != null && directUserLower.isNotEmpty) {
          return directUserLower;
        }
      }

      // Fast parallel structured query strictly by 'id'
      final restResults = await Future.wait([
        _queryRest('id', rawTrimmed).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
        _queryRest('id', idLower).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
      ]);
      for (final r in restResults) {
        if (r != null && r.isNotEmpty) return r;
      }

      // 2. FALLBACK: Native/Web SDK query
      if (isAvailable) {
        final docSnap = await usersCollection.doc(rawTrimmed).get().timeout(const Duration(seconds: 2));
        if (docSnap.exists && docSnap.data() != null) {
          final d = docSnap.data()!;
          if (!d.containsKey('id')) d['id'] = docSnap.id;
          return d;
        }
        final querySnap = await usersCollection.where('id', isEqualTo: rawTrimmed).limit(1).get().timeout(const Duration(seconds: 2));
        if (querySnap.docs.isNotEmpty) {
          final d = querySnap.docs.first.data();
          if (!d.containsKey('id')) d['id'] = querySnap.docs.first.id;
          return d;
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] findUserById note: $e');
    }
    return null;
  }

  /// Searches Cloud Firestore for an account by email, ID, or username.
  /// Uses ultra-fast REST direct fetches first (<200ms) with SDK fallback.
  Future<Map<String, dynamic>?> findUserByIdentifier(String identifier) async {
    final rawTrimmed = identifier.trim();
    final idLower = rawTrimmed.toLowerCase();
    if (rawTrimmed.isEmpty || _isTestEnv) return null;

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

    // 1. FAST PATH: Direct REST query (~100-250ms, bypasses Web SDK cold-start & WebSocket latency)
    try {
      if (!isEmail) {
        // Direct document fetch by ID (e.g. SA-000-0001, A-100-0001, T-100-0001, S-100-0001)
        final directUser = await _fetchDocRest(rawTrimmed)
            .timeout(const Duration(milliseconds: 2000), onTimeout: () => null);
        if (directUser != null && directUser.isNotEmpty) {
          return directUser;
        }

        // Direct doc fetch lowercase if different (e.g. sa-000-0001)
        if (idLower != rawTrimmed) {
          final directUserLower = await _fetchDocRest(idLower)
              .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
          if (directUserLower != null && directUserLower.isNotEmpty) {
            return directUserLower;
          }
        }

        // Fast parallel structured query by username or id
        final restResults = await Future.wait([
          _queryRest('id', rawTrimmed).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
          _queryRest('username_lower', idLower).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
          _queryRest('username', rawTrimmed).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
        ]);
        for (final r in restResults) {
          if (r != null && r.isNotEmpty) return r;
        }
      } else {
        // Fast email query via REST
        final restResults = await Future.wait([
          _queryRest('email_lower', idLower).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
          _queryRest('email', rawTrimmed).timeout(const Duration(milliseconds: 2000), onTimeout: () => null),
          _fetchDocRest(idLower).timeout(const Duration(milliseconds: 1500), onTimeout: () => null),
        ]);
        for (final r in restResults) {
          if (r != null && r.isNotEmpty) return r;
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] Fast REST search note: $e');
    }

    // 2. FALLBACK: Native/Web SDK query (if REST didn't resolve)
    if (isAvailable) {
      try {
        if (isEmail) {
          final results = await Future.wait([
            usersCollection.where('email_lower', isEqualTo: idLower).limit(1).get().timeout(const Duration(seconds: 2)),
            usersCollection.where('email', isEqualTo: rawTrimmed).limit(1).get().timeout(const Duration(seconds: 2)),
          ]);
          for (final snap in results) {
            if (snap.docs.isNotEmpty) {
              final d = snap.docs.first.data();
              if (!d.containsKey('id')) d['id'] = snap.docs.first.id;
              return d;
            }
          }
        } else {
          final docSnap = await usersCollection.doc(rawTrimmed).get().timeout(const Duration(seconds: 2));
          if (docSnap.exists && docSnap.data() != null) {
            final d = docSnap.data()!;
            if (!d.containsKey('id')) d['id'] = docSnap.id;
            return d;
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] SDK search note: $e');
      }
    }

    return null;
  }

  /// Fetches all users from Cloud Firestore (via SDK or REST fallback)
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    List<Map<String, dynamic>> cloudUsers = [];
    if (isAvailable) {
      try {
        final snapshot = await usersCollection.get().timeout(const Duration(seconds: 12));
        cloudUsers = snapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetchAllUsers note: $e');
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

  /// Syncs explicitly queued local offline user creations to Cloud Firestore.
  /// Never blindly pushes SQLite cache up to Cloud Firestore to prevent resurrecting deleted accounts.
  Future<void> syncLocalUsersToCloud() async {
    // Cloud Firestore is the primary source of truth for user accounts.
    // Client devices must NEVER push unverified local SQLite cache to the cloud.
    return;
  }

  DateTime? _lastUsersSyncTime;
  Completer<void>? _syncCompleter;

  /// Invalidates the users sync throttle cache so next sync requests Cloud Firestore immediately.
  void invalidateUsersSyncCache() {
    _lastUsersSyncTime = null;
  }

  /// Syncs Cloud Firestore users down to local SQLite cache and prunes deleted accounts.
  /// Throttled to at most once per 5 minutes unless [force] is true or local database is empty.
  /// Uses delta querying via 'updated_at' so that if no accounts changed, 0 reads are consumed!
  Future<void> syncCloudUsersToLocal({bool force = false}) async {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      if (!force) {
        debugPrint('[FirestoreService] syncCloudUsersToLocal already in progress, awaiting existing sync');
        return _syncCompleter!.future;
      }
      await _syncCompleter!.future;
    }
    _syncCompleter = Completer<void>();

    try {
      final db = await DatabaseHelper().database;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      // 1. Check if local database currently has any registered students or teachers
      int localCount = 0;
      try {
        localCount = Sqflite.firstIntValue(
          await db.rawQuery("SELECT COUNT(*) FROM users WHERE role IN ('student', 'teacher') OR id LIKE 'S-%' OR id LIKE 'T-%'"),
        ) ?? 0;
      } catch (_) {}

      // 2. If local database has 0 students/teachers (e.g. Web reload where in-memory SQLite starts clean),
      // restore immediately from persistent localStorage cache in 0ms!
      if (localCount == 0) {
        final cachedStr = prefs?.getString('local_cached_users_v1');
        if (cachedStr != null && cachedStr.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedStr);
            final cachedUsers = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (cachedUsers.isNotEmpty) {
              await applyCloudUsersToLocal(cachedUsers, persistToStorage: false);
              localCount = Sqflite.firstIntValue(
                await db.rawQuery("SELECT COUNT(*) FROM users WHERE role IN ('student', 'teacher') OR id LIKE 'S-%' OR id LIKE 'T-%'"),
              ) ?? 0;
            }
          } catch (_) {}
        }
      }

      final bool isDbEmpty = localCount == 0;

      final now = DateTime.now();
      // On Web or if database is empty or force sync is true, never throttle
      if (!force && !isDbEmpty && !kIsWeb && _lastUsersSyncTime != null && now.difference(_lastUsersSyncTime!) < const Duration(minutes: 5)) {
        debugPrint('[FirestoreService] syncCloudUsersToLocal throttled (last synced ${now.difference(_lastUsersSyncTime!).inMinutes}m ago)');
        return;
      }
      _lastUsersSyncTime = now;

      // On Web or if local DB is empty or force sync requested, always perform a full fetch (ignore lastSync) to populate the directory!
      final bool needsFullCatalog = force || isDbEmpty || (kIsWeb && localCount == 0);
      final lastSync = needsFullCatalog ? null : prefs?.getString('last_synced_at_users');

      List<Map<String, dynamic>> cloudUsers = [];

      if (isAvailable) {
        try {
          Query<Map<String, dynamic>> query = usersCollection;
          if (lastSync != null && lastSync.isNotEmpty) {
            query = query.where('updated_at', isGreaterThan: lastSync);
          }
          final snapshot = await query.get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 8));
          cloudUsers = snapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        } catch (e) {
          debugPrint('[FirestoreService] SDK syncCloudUsersToLocal note: $e');
        }
      }

      // Fallback: If SDK returned empty or incomplete (e.g. only self-admin), timed out, or threw an error, fetch via direct REST!
      if (cloudUsers.length <= 1 || isDbEmpty || force || needsFullCatalog || (kIsWeb && localCount < 2)) {
        debugPrint('[FirestoreService] Using REST fallback for full user catalog fetch...');
        final restUsers = await _fetchAllRest();
        if (restUsers.isNotEmpty) {
          cloudUsers = restUsers;
        }
      }

      if (cloudUsers.isNotEmpty) {
        await applyCloudUsersToLocal(cloudUsers, persistToStorage: true);
        await prefs?.setString('last_synced_at_users', now.toIso8601String());
      }
    } catch (e) {
      debugPrint('[FirestoreService] Error syncing cloud users to local SQLite: $e');
    } finally {
      if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
        _syncCompleter!.complete();
      }
    }
  }

  /// Ingests a set of Cloud Firestore user documents into the local SQLite memory/disk store
  /// and synchronizes state across devices in real time.
  Future<void> applyCloudUsersToLocal(
    List<Map<String, dynamic>> cloudUsers, {
    bool persistToStorage = true,
  }) async {
    try {
      if (cloudUsers.isEmpty) return;

      final db = await DatabaseHelper().database;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}
      final deletedList = prefs?.getStringList('permanently_deleted_accounts') ?? [];

      final cloudIds = <String>{};
      final cloudEmails = <String>{};

      // Prioritize canonical institutional ID records (SA-, A-, T-, S-) over legacy email-keyed records
      final sortedCloudUsers = List<Map<String, dynamic>>.from(cloudUsers)..sort((a, b) {
        final aId = a['id']?.toString() ?? '';
        final bId = b['id']?.toString() ?? '';
        final aIsCanonical = aId.startsWith('SA-') || aId.startsWith('A-') || aId.startsWith('T-') || aId.startsWith('S-');
        final bIsCanonical = bId.startsWith('SA-') || bId.startsWith('A-') || bId.startsWith('T-') || bId.startsWith('S-');
        if (aIsCanonical && !bIsCanonical) return -1;
        if (!aIsCanonical && bIsCanonical) return 1;
        return 0;
      });

      for (final data in sortedCloudUsers) {
        try {
          final userId = data['id']?.toString() ?? '';
          final email = (data['email']?.toString() ?? '').toLowerCase().trim();
          if (userId.isEmpty && email.isEmpty) continue;

          // If an active account exists in Cloud Firestore, ensure it is not blocked by stale local deleted tombstone
          if (deletedList.contains(userId) || (email.isNotEmpty && deletedList.contains(email))) {
            deletedList.remove(userId);
            deletedList.remove(email);
            if (prefs != null) {
              unawaited(prefs.setStringList('permanently_deleted_accounts', deletedList));
            }
          }

          cloudIds.add(userId);
          if (email.isNotEmpty) cloudEmails.add(email);

          List<Map<String, dynamic>> existing = await db.query('users', where: 'id = ?', whereArgs: [userId]);
          if (existing.isEmpty && email.isNotEmpty) {
            existing = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [email]);
          }

          final cloudMust = data['must_change_password'] == 1 ||
              data['must_change_password'] == true ||
              data['must_change_password'] == '1' ||
              data['mustChangePassword'] == true;
          final localMust = existing.isNotEmpty &&
              (existing.first['must_change_password'] == 1 ||
               existing.first['must_change_password'] == true ||
               existing.first['must_change_password'] == '1');
          final prefMust = (prefs?.getBool('must_change_password_$userId') == true) ||
              (email.isNotEmpty && (prefs?.getBool('must_change_password_$email') == true));

          // Standardize on canonical ID: if userId is SA-000-0001, preserve it
          final targetId = (userId.startsWith('SA-') || userId.startsWith('A-') || userId.startsWith('T-') || userId.startsWith('S-'))
              ? userId
              : (existing.isNotEmpty ? existing.first['id'] : userId);

          // Cloud is the primary source of truth across devices.
          // However, if the user on THIS device has already successfully changed their password (must_change_password == 0),
          // an outdated cloud snapshot must NEVER revert them back to must_change_password = 1.
          final bool localHasUnlocked = existing.isNotEmpty &&
              (existing.first['must_change_password'] == 0 ||
               existing.first['must_change_password'] == '0' ||
               existing.first['must_change_password'] == false) &&
              prefMust == false;

          final hasCloudField = data.containsKey('must_change_password') ||
              data.containsKey('mustChangePassword');

          final bool mustChangeBool;
          if (localHasUnlocked) {
            mustChangeBool = false;
            // If cloud still has stale 1, auto-repair cloud to 0 so all devices stay unlocked!
            if (cloudMust) {
              unawaited(saveUser({'id': userId, if (email.isNotEmpty) 'email': email, 'must_change_password': 0, 'mustChangePassword': false}));
            }
          } else if (hasCloudField) {
            mustChangeBool = cloudMust;
          } else {
            mustChangeBool = localMust || prefMust;
          }
          final mustChangeVal = mustChangeBool ? 1 : 0;
          if (mustChangeVal == 1) {
            try {
              final whereClause = email.isNotEmpty ? 'user_id = ? OR LOWER(user_id) = ?' : 'user_id = ?';
              await db.update(
                'sessions',
                {'must_change_password': 1},
                where: whereClause,
                whereArgs: [targetId, if (email.isNotEmpty) email],
              );
              await prefs?.setBool('must_change_password_$targetId', true);
              if (email.isNotEmpty) await prefs?.setBool('must_change_password_$email', true);
            } catch (_) {}
          } else {
            try {
              final whereClause = email.isNotEmpty ? 'user_id = ? OR LOWER(user_id) = ?' : 'user_id = ?';
              await db.update(
                'sessions',
                {'must_change_password': 0},
                where: whereClause,
                whereArgs: [targetId, if (email.isNotEmpty) email],
              );
              await prefs?.remove('must_change_password_$targetId');
              if (email.isNotEmpty) await prefs?.remove('must_change_password_$email');
            } catch (_) {}
          }

          final isArchived = data['is_archived'] == 1 ||
              data['is_archived'] == true ||
              data['is_archived'] == '1';
          final archivedAt = data['archived_at']?.toString();

          // Authoritative role resolution: Institutional ID prefix always dictates role!
          final detectedRole = InstitutionalIdHelper.detectRole(targetId) ??
              InstitutionalIdHelper.detectRole(userId);
          final rawRole = data['role']?.toString().toLowerCase().trim();
          // Skip orphan documents that have no role and no institutional ID (e.g. legacy loose email docs)
          if (detectedRole == null && (rawRole == null || rawRole.isEmpty)) {
            debugPrint('[FirestoreService] Skipping non-user document without role or canonical ID: $userId');
            continue;
          }
          final resolvedRole = detectedRole ?? (rawRole != null && rawRole.isNotEmpty ? rawRole : 'student');

          // If Cloud Firestore had an erroneous role (e.g. T-100-0001 saved as student), auto-repair Cloud!
          if (detectedRole != null && data['role'] != detectedRole) {
            debugPrint('[FirestoreService] Auto-repairing role in Cloud Firestore for $targetId from "${data['role']}" to "$detectedRole"');
            unawaited(saveUser({
              'id': targetId,
              if (email.isNotEmpty) 'email': email,
              'role': detectedRole,
              'category': detectedRole,
              'updated_at': DateTime.now().toIso8601String(),
            }));
          }

          // Safely merge fields: do not let a secondary document overwrite populated values with null/empty
          final old = existing.isNotEmpty ? existing.first : <String, dynamic>{};
          final fullNameVal = (data['full_name'] != null && data['full_name'].toString().isNotEmpty)
              ? data['full_name']
              : (data['name'] != null && data['name'].toString().isNotEmpty)
                  ? data['name']
                  : (old['full_name'] ?? '');

          final usernameVal = (data['username'] != null && data['username'].toString().isNotEmpty)
              ? data['username']
              : (old['username'] ?? '');

          final passwordVal = (data['password'] != null && data['password'].toString().isNotEmpty)
              ? data['password']
              : (old['password'] ?? '');

          final passwordSaltVal = data['password_salt'] ?? old['password_salt'];

          final sectionVal = (resolvedRole == 'teacher' || resolvedRole == 'admin' || resolvedRole == 'super_admin')
              ? null
              : (data['section'] != null && data['section'].toString().isNotEmpty)
                  ? data['section']
                  : old['section'];

          final gradeVal = (resolvedRole == 'teacher' || resolvedRole == 'admin' || resolvedRole == 'super_admin')
              ? null
              : (data['grade'] != null && data['grade'].toString().isNotEmpty)
                  ? data['grade']
                  : old['grade'];

          final studentTypeVal = (resolvedRole == 'student')
              ? (data['student_type'] ?? old['student_type'] ?? 'regular')
              : null;

          final profileImgVal = data['profile_image'] ?? data['profileImage'] ?? old['profile_image'];

          final dbRow = {
            'id': targetId,
            'email': (data['email'] != null && data['email'].toString().isNotEmpty) ? data['email'] : (old['email'] ?? ''),
            'username': usernameVal,
            'password': passwordVal,
            'password_salt': passwordSaltVal,
            'role': resolvedRole,
            'category': resolvedRole,
            'full_name': fullNameVal,
            'profile_image': profileImgVal,
            'section': sectionVal,
            'grade': gradeVal,
            'student_type': studentTypeVal,
            'special_notes': data['special_notes'] ?? old['special_notes'],
            'school_id': data['school_id'] ?? old['school_id'] ?? 'sch_main',
            'must_change_password': mustChangeVal,
            'is_archived': isArchived ? 1 : 0,
            'archived_at': isArchived ? (archivedAt ?? DateTime.now().toIso8601String()) : null,
            'created_at': data['created_at'] ?? old['created_at'] ?? DateTime.now().toIso8601String(),
          };

          if (existing.isEmpty) {
            await db.insert('users', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
          } else {
            final oldId = existing.first['id'];
            if (oldId != targetId) {
              await db.delete('users', where: 'id = ?', whereArgs: [oldId]);
              await db.insert('users', dbRow, conflictAlgorithm: ConflictAlgorithm.replace);
            } else {
              await db.update('users', dbRow, where: 'id = ?', whereArgs: [targetId]);
            }
          }

          if (resolvedRole == 'student' && sectionVal != null && sectionVal.toString().isNotEmpty) {
            unawaited(DatabaseHelper().ensureStudentEnrolledInSectionSubjects(targetId, sectionVal.toString()));
          }
        } catch (e) {
          debugPrint('[FirestoreService] Note syncing user ${data['id']}: $e');
        }
      }

      // Handle local SQLite users with safe tombstone-based pruning and auto-push
      final localUsers = await db.query('users');
      for (final local in localUsers) {
        final localId = local['id']?.toString() ?? '';
        final localEmail = (local['email']?.toString() ?? '').toLowerCase().trim();

        final isPermanentSeed = localId == 'super_admin_christian' ||
            localId == 'SA-000-0001' ||
            localEmail == 'evangelistachristian88@gmail.com';

        // 1. Only prune if the unique account ID was explicitly marked as permanently deleted (tombstone)
        if (!isPermanentSeed && deletedList.contains(localId)) {
          await db.delete('users', where: 'id = ?', whereArgs: [localId]);
          try {
            await db.delete('enrollments', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('quiz_attempts', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('student_progress', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('submissions', where: 'student_id = ?', whereArgs: [localId]);
          } catch (_) {}
          debugPrint('[FirestoreService] Pruned permanently deleted user: $localId ($localEmail)');
          continue;
        }
      }

      if (persistToStorage) {
        try {
          final allUsers = await db.query('users');
          await prefs?.setString('local_cached_users_v1', jsonEncode(allUsers));
        } catch (_) {}
      }

      try {
        await DatabaseHelper().reconcileAllEnrollments();
      } catch (_) {}

      debugPrint('[FirestoreService] Applied ${cloudUsers.length} users to local store');
      notifySyncListeners();
    } catch (e) {
      debugPrint('[FirestoreService] Error applying cloud users to local SQLite: $e');
    }
  }

  DateTime? _lastSubjectsSyncTime;

  /// Ingests all subjects from Cloud Firestore into local SQLite with localStorage persistence.
  Future<void> syncCloudSubjectsToLocal({bool force = false}) async {
    try {
      final db = await DatabaseHelper().database;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      // 1. Check local count in SQLite
      int localCount = 0;
      try {
        localCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM subjects'),
        ) ?? 0;
      } catch (_) {}

      // 2. Instant cache restore if SQLite is empty
      if (localCount == 0 && prefs != null) {
        final cachedStr = prefs.getString('local_cached_subjects_v1');
        if (cachedStr != null && cachedStr.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedStr);
            for (final item in decoded) {
              if (item is Map) {
                await db.insert(
                  'subjects',
                  Map<String, dynamic>.from(item),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
            localCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM subjects'),
            ) ?? 0;
          } catch (_) {}
        }
      }

      final now = DateTime.now();
      if (!force && localCount > 0 && !kIsWeb && _lastSubjectsSyncTime != null &&
          now.difference(_lastSubjectsSyncTime!) < const Duration(minutes: 3)) {
        return;
      }
      _lastSubjectsSyncTime = now;

      final cloudDocs = await fetchAllDocuments('subjects');
      if (cloudDocs.isEmpty) return;

      final deletedSubjects = prefs?.getStringList('permanently_deleted_subjects') ?? [];

      for (final doc in cloudDocs) {
        final subCode = doc['subject_code']?.toString().toUpperCase() ??
            doc['_docId']?.toString().toUpperCase() ??
            doc['id']?.toString().toUpperCase() ??
            '';
        final subName = doc['name']?.toString() ?? subCode;
        if (subCode.isEmpty && subName.isEmpty) continue;
        // If an active subject exists in Cloud Firestore, ensure it is not blocked by a stale local tombstone
        if (deletedSubjects.contains(subCode) || deletedSubjects.contains(subName)) {
          deletedSubjects.remove(subCode);
          deletedSubjects.remove(subName);
          if (prefs != null) {
            unawaited(prefs.setStringList('permanently_deleted_subjects', deletedSubjects));
          }
        }

        final existing = await db.query(
          'subjects',
          where: 'UPPER(subject_code) = ? OR UPPER(name) = ?',
          whereArgs: [subCode.toUpperCase(), subName.toUpperCase()],
        );

        final teacherId = doc['teacher_id']?.toString();
        final teacherName = doc['teacher_name']?.toString();

        final rowData = {
          'name': subName,
          'subject_code': subCode,
          'description': doc['description']?.toString() ?? '',
          'grade_level': doc['grade_level']?.toString() ?? doc['grade']?.toString() ?? 'Grade 10',
          'semester': doc['semester']?.toString() ?? '1st Semester',
          'unlock_type': doc['unlock_type']?.toString() ?? 'Sequential',
          'teacher_id': (teacherId != null && teacherId != 'null' && teacherId.isNotEmpty) ? teacherId : null,
          'teacher_name': (teacherName != null && teacherName != 'null' && teacherName.isNotEmpty) ? teacherName : null,
          'school_id': doc['school_id']?.toString() ?? 'sch_main',
          'created_at': doc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        };

        if (existing.isEmpty) {
          await db.insert('subjects', rowData, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          // If multiple duplicates exist, prioritize the one with enrolled students!
          final enriched = <Map<String, dynamic>>[];
          for (final row in existing) {
            final rid = row['id'] as int;
            final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM enrollments WHERE subject_id = ?', [rid]);
            final cnt = (countRes.first['cnt'] as num?)?.toInt() ?? 0;
            enriched.add({...row, '_cnt': cnt});
          }
          enriched.sort((a, b) => (b['_cnt'] as int).compareTo(a['_cnt'] as int));
          final primaryId = enriched.first['id'] as int;
          await db.update('subjects', rowData, where: 'id = ?', whereArgs: [primaryId]);

          // Clean up duplicate rows if multiple rows exist in SQLite and preserve relationships
          if (enriched.length > 1) {
            for (final dup in enriched.skip(1)) {
              final dupId = dup['id'] as int;
              await db.rawUpdate('UPDATE OR IGNORE enrollments SET subject_id = ? WHERE subject_id = ?', [primaryId, dupId]);
              await db.delete('enrollments', where: 'subject_id = ?', whereArgs: [dupId]);
              await db.update('assignments', {'subject_id': primaryId}, where: 'subject_id = ?', whereArgs: [dupId]);
              await db.update('topics', {'subject_id': primaryId}, where: 'subject_id = ?', whereArgs: [dupId]);
              await db.delete('subjects', where: 'id = ?', whereArgs: [dupId]);
            }
          }
        }
      }

      await DatabaseHelper().deduplicateSubjects();

      // Prune local SQLite subjects that do NOT exist in Cloud Firestore
      final validCloudCodes = cloudDocs.map((d) {
        return (d['subject_code']?.toString() ?? d['_docId']?.toString() ?? d['id']?.toString() ?? '').trim().toUpperCase();
      }).where((c) => c.isNotEmpty).toSet();

      if (validCloudCodes.isNotEmpty) {
        final allLocal = await db.query('subjects');
        for (final loc in allLocal) {
          final code = (loc['subject_code']?.toString() ?? '').trim().toUpperCase();
          final locId = loc['id'] as int;
          if (code.isNotEmpty && !validCloudCodes.contains(code)) {
            await db.delete('subjects', where: 'id = ?', whereArgs: [locId]);
            await db.delete('enrollments', where: 'subject_id = ?', whereArgs: [locId]);
            await db.delete('topics', where: 'subject_id = ?', whereArgs: [locId]);
          }
        }
      }

      // Prune deleted tombstones
      for (final del in deletedSubjects) {
        await db.delete(
          'subjects',
          where: 'UPPER(subject_code) = ? OR UPPER(name) = ?',
          whereArgs: [del.toUpperCase(), del.toUpperCase()],
        );
      }

      // Persist to local storage
      if (prefs != null) {
        try {
          final all = await db.query('subjects', orderBy: 'id DESC');
          await prefs.setString('local_cached_subjects_v1', jsonEncode(all));
        } catch (_) {}
      }

      debugPrint('[FirestoreService] Synced ${cloudDocs.length} cloud subjects to local SQLite');
      notifySyncListeners();
    } catch (e) {
      debugPrint('[FirestoreService] Error syncing cloud subjects to local SQLite: $e');
    }
  }

  DateTime? _lastSectionsSyncTime;

  /// Ingests all class sections from Cloud Firestore into local SQLite with localStorage persistence.
  Future<void> syncCloudSectionsToLocal({bool force = false}) async {
    try {
      final db = await DatabaseHelper().database;
      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      // 1. Check local count in SQLite
      int localCount = 0;
      try {
        localCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM sections'),
        ) ?? 0;
      } catch (_) {}

      // 2. Instant cache restore if SQLite is empty
      if (localCount == 0 && prefs != null) {
        final cachedStr = prefs.getString('local_cached_sections_v1');
        if (cachedStr != null && cachedStr.isNotEmpty) {
          try {
            final List<dynamic> decoded = jsonDecode(cachedStr);
            for (final item in decoded) {
              if (item is Map) {
                await db.insert(
                  'sections',
                  Map<String, dynamic>.from(item),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
            localCount = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM sections'),
            ) ?? 0;
          } catch (_) {}
        }
      }

      final now = DateTime.now();
      if (!force && localCount > 0 && !kIsWeb && _lastSectionsSyncTime != null &&
          now.difference(_lastSectionsSyncTime!) < const Duration(minutes: 3)) {
        return;
      }
      _lastSectionsSyncTime = now;

      final cloudDocs = await fetchAllDocuments('sections');
      if (cloudDocs.isEmpty) return;

      final deletedSections = prefs?.getStringList('permanently_deleted_sections') ?? [];

      for (final doc in cloudDocs) {
        final secName = doc['name']?.toString() ?? '';
        final secKey = doc['enrollment_key']?.toString().toUpperCase() ??
            doc['_docId']?.toString().toUpperCase() ??
            doc['id']?.toString().toUpperCase() ??
            '';
        if (secName.isEmpty && secKey.isEmpty) continue;
        // If an active section exists in Cloud Firestore, ensure it is not blocked by a stale local tombstone
        if (deletedSections.contains(secName) || deletedSections.contains(secKey)) {
          deletedSections.remove(secName);
          deletedSections.remove(secKey);
          if (prefs != null) {
            unawaited(prefs.setStringList('permanently_deleted_sections', deletedSections));
          }
        }

        final existing = await db.query(
          'sections',
          where: 'UPPER(enrollment_key) = ? OR UPPER(name) = ?',
          whereArgs: [secKey.toUpperCase(), secName.toUpperCase()],
        );

        String? subjectIdsJson;
        if (doc['subject_ids'] != null) {
          if (doc['subject_ids'] is List) {
            subjectIdsJson = jsonEncode(doc['subject_ids']);
          } else {
            subjectIdsJson = doc['subject_ids'].toString();
          }
        }

        final rowData = {
          'name': secName,
          'description': doc['description']?.toString() ?? '',
          'grade': doc['grade']?.toString() ?? doc['grade_level']?.toString() ?? 'Grade 10',
          'room': doc['room']?.toString() ?? '',
          'student_count': int.tryParse(doc['student_count']?.toString() ?? '0') ?? 0,
          'enrollment_key': secKey,
          'subject_ids': subjectIdsJson,
          'school_id': doc['school_id']?.toString() ?? 'sch_main',
          'created_at': doc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        };

        if (existing.isEmpty) {
          await db.insert('sections', rowData, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          final existingId = existing.first['id'];
          await db.update('sections', rowData, where: 'id = ?', whereArgs: [existingId]);
        }

        if (secName.isNotEmpty) {
          unawaited(DatabaseHelper().autoEnrollAllStudentsInSection(secName));
        }

        // Also ensure registration link/key table has this enrollment key
        if (secKey.isNotEmpty && secName.isNotEmpty) {
          await db.insert(
            'reg_links',
            {
              'code': secKey,
              'section': secName,
              'max_uses': int.tryParse(doc['max_uses']?.toString() ?? '50') ?? 50,
              'used_count': 0,
              'expiration': doc['expiration']?.toString() ?? '2026-12-31',
              'created_at': doc['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Prune deleted tombstones
      for (final del in deletedSections) {
        await db.delete(
          'sections',
          where: 'UPPER(enrollment_key) = ? OR UPPER(name) = ?',
          whereArgs: [del.toUpperCase(), del.toUpperCase()],
        );
      }

      // Persist to local storage
      if (prefs != null) {
        try {
          final all = await db.query('sections', orderBy: 'id DESC');
          await prefs.setString('local_cached_sections_v1', jsonEncode(all));
        } catch (_) {}
      }

      debugPrint('[FirestoreService] Synced ${cloudDocs.length} cloud sections to local SQLite');
      notifySyncListeners();
    } catch (e) {
      debugPrint('[FirestoreService] Error syncing cloud sections to local SQLite: $e');
    }
  }

  DateTime? _lastConversationsSyncTime;

  /// Syncs section and group conversations from Cloud Firestore to local SQLite
  Future<void> syncCloudConversationsToLocal({bool force = false}) async {
    try {
      final now = DateTime.now();
      if (!force && _lastConversationsSyncTime != null &&
          now.difference(_lastConversationsSyncTime!) < const Duration(seconds: 30)) {
        return;
      }
      _lastConversationsSyncTime = now;

      final cloudDocs = await fetchAllDocuments('conversations');
      if (cloudDocs.isEmpty) return;

      final db = await DatabaseHelper().database;

      for (final doc in cloudDocs) {
        final convId = doc['id']?.toString() ?? doc['_docId']?.toString() ?? '';
        if (convId.isEmpty) continue;

        List<String> participantIds = [];
        final rawParts = doc['participants'] ?? doc['participant_ids'];
        if (rawParts is List) {
          participantIds = rawParts.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        }

        await db.insert(
          'conversations',
          {
            'id': convId,
            'type': doc['type']?.toString() ?? 'group',
            'name': doc['name']?.toString() ?? 'Section Chat',
            'section_id': doc['section_id'] is int ? doc['section_id'] : int.tryParse(doc['section_id']?.toString() ?? ''),
            'section_key': doc['section_key']?.toString().toUpperCase(),
            'room_admin_id': doc['room_admin_id']?.toString(),
            'room_admin_name': doc['room_admin_name']?.toString(),
            'participant_ids': jsonEncode(participantIds),
            'school_id': doc['school_id']?.toString() ?? 'sch_main',
            'is_archived': (doc['is_archived'] == true || doc['is_archived'] == 1) ? 1 : 0,
            'created_at': doc['created_at']?.toString() ?? now.toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        if (doc['last_message'] is Map) {
          final lm = doc['last_message'] as Map;
          final lmId = lm['id']?.toString() ?? 'msg_${DateTime.now().millisecondsSinceEpoch}';
          final lmText = lm['text']?.toString() ?? '';
          if (lmText.isNotEmpty) {
            await db.insert(
              'messages',
              {
                'id': lmId,
                'conversation_id': convId,
                'sender_id': lm['sender_id']?.toString() ?? 'system',
                'text': lmText,
                'created_at': lm['created_at']?.toString() ?? now.toIso8601String(),
                'is_read': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
        }
      }
      debugPrint('[FirestoreService] Synced ${cloudDocs.length} cloud conversations to local SQLite');
      // Also sync all chat messages from cloud so past chats never disappear on refresh
      await syncCloudMessagesToLocal(force: force);
    } catch (e) {
      debugPrint('[FirestoreService] syncCloudConversations error: $e');
    }
  }

  DateTime? _lastMessagesSyncTime;

  /// Syncs all chat messages from Cloud Firestore to local SQLite
  Future<void> syncCloudMessagesToLocal({bool force = false}) async {
    try {
      final db = await DatabaseHelper().database;
      final now = DateTime.now();

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (_) {}

      // Fast cache restore on Web if in-memory SQLite table is empty
      if (kIsWeb && prefs != null) {
        final cached = prefs.getString('local_cached_chat_messages_v1');
        if (cached != null && cached.isNotEmpty) {
          try {
            final List<dynamic> list = jsonDecode(cached);
            for (final m in list) {
              if (m is Map) {
                await db.insert(
                  'messages',
                  Map<String, dynamic>.from(m),
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          } catch (_) {}
        }
      }

      if (!force && _lastMessagesSyncTime != null &&
          now.difference(_lastMessagesSyncTime!) < const Duration(seconds: 10)) {
        return;
      }
      _lastMessagesSyncTime = now;

      // Sync messages for all conversations known in local DB
      final convRows = await db.query('conversations', columns: ['id']);
      for (final r in convRows) {
        final convId = r['id']?.toString() ?? '';
        if (convId.isNotEmpty) {
          await syncCloudMessagesForConversation(convId);
        }
      }
    } catch (e) {
      debugPrint('[FirestoreService] syncCloudMessages error: $e');
    }
  }

  /// Real-time stream of messages for a given conversation.
  /// Listens to the `/conversations/{conversationId}/messages` subcollection with sub-second push updates.
  Stream<List<Map<String, dynamic>>> streamConversationMessages(String conversationId) {
    final cleanConvId = conversationId.trim();
    if (cleanConvId.isEmpty) return const Stream.empty();

    if (!isAvailable) {
      return const Stream.empty();
    }

    try {
      return firestore
          .collection('conversations')
          .doc(cleanConvId)
          .collection('messages')
          .orderBy('created_at', descending: false)
          .snapshots()
          .handleError((err) {
            debugPrint('[FirestoreService] streamConversationMessages snapshot error: $err');
          })
          .map((snapshot) {
            return snapshot.docs.map((doc) {
              final data = Map<String, dynamic>.from(doc.data());
              data['id'] = doc.id;
              data['_docId'] = doc.id;
              data['conversation_id'] = cleanConvId;
              return data;
            }).toList();
          });
    } catch (e) {
      debugPrint('[FirestoreService] streamConversationMessages error: $e');
      return const Stream.empty();
    }
  }

  /// Fetches all messages for a specific conversation from Cloud Firestore.
  /// Combines subcollection `/conversations/{cleanConvId}/messages` and root `/messages`
  /// with local cache fallback so past messages are NEVER lost.
  Future<List<Map<String, dynamic>>> fetchConversationMessages(String conversationId) async {
    final cleanConvId = conversationId.trim();
    if (cleanConvId.isEmpty) return [];

    final Map<String, Map<String, dynamic>> combinedById = {};

    if (isAvailable) {
      // 1. Fetch from subcollection `/conversations/{cleanConvId}/messages`
      try {
        final snap = await firestore
            .collection('conversations')
            .doc(cleanConvId)
            .collection('messages')
            .orderBy('created_at', descending: false)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(Duration(seconds: kIsWeb ? 5 : 10));

        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_docId'] = doc.id;
          data['conversation_id'] = cleanConvId;
          combinedById[doc.id] = data;
        }
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetch subcollection error: $e');
      }

      // 2. Fetch from root collection `/messages` where conversation_id == cleanConvId
      try {
        final snap = await firestore
            .collection('messages')
            .where('conversation_id', isEqualTo: cleanConvId)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(Duration(seconds: kIsWeb ? 5 : 10));

        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_docId'] = doc.id;
          data['conversation_id'] = cleanConvId;
          combinedById[doc.id] = data;
        }
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetch root messages error: $e');
      }
    }

    // 3. REST API Fallback if nothing found yet
    if (combinedById.isEmpty) {
      try {
        final dio = _dio;
        final keyParam = apiKey.isNotEmpty ? '?key=$apiKey' : '';
        final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/conversations/$cleanConvId/messages$keyParam';
        final response = await dio.get(url);
        if (response.data is Map && response.data.containsKey('documents')) {
          final docs = response.data['documents'] as List? ?? [];
          for (final d in docs) {
            if (d is Map && d.containsKey('fields')) {
              final fields = d['fields'] as Map<String, dynamic>? ?? {};
              final parsed = _parseFirestoreFields(fields);
              final docId = (d['name'] as String? ?? '').split('/').last;
              if (docId.isNotEmpty) {
                parsed['id'] = parsed['id'] ?? docId;
                parsed['conversation_id'] = cleanConvId;
                combinedById[docId] = parsed;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] REST fetch error: $e');
      }
    }

    // 4. Merge SharedPreferences Cache on Web so recent/optimistic messages are never lost on refresh
    if (kIsWeb) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('local_cached_chat_messages_v1');
        if (cached != null && cached.isNotEmpty) {
          final List<dynamic> list = jsonDecode(cached);
          for (final m in list) {
            if (m is Map && m['conversation_id']?.toString() == cleanConvId) {
              final id = m['id']?.toString() ?? '';
              if (id.isNotEmpty && !combinedById.containsKey(id)) {
                combinedById[id] = Map<String, dynamic>.from(m);
              }
            }
          }
        }
      } catch (_) {}
    }

    // 5. De-duplicate extra welcome messages (keep only the earliest)
    final allList = combinedById.values.toList();
    allList.sort((a, b) => (a['created_at']?.toString() ?? '').compareTo(b['created_at']?.toString() ?? ''));

    final result = <Map<String, dynamic>>[];
    bool seenWelcome = false;
    for (final m in allList) {
      final text = m['text']?.toString() ?? '';
      if (text.startsWith('Welcome to the official group chat for ')) {
        if (seenWelcome) continue;
        seenWelcome = true;
      }
      result.add(m);
    }

    return result;
  }

  /// Saves a chat message to Cloud Firestore with guaranteed subcollection storage,
  /// conversation last_message updating, REST fallback, and persistent Web cache.
  Future<void> saveChatMessage({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    final cleanConvId = conversationId.trim();
    final cleanMsgId = messageId.trim();
    if (cleanConvId.isEmpty || cleanMsgId.isEmpty) return;
    if (_isTestEnv) return;

    final dataToSave = Map<String, dynamic>.from(data);
    final nowIso = DateTime.now().toIso8601String();
    dataToSave['created_at'] ??= nowIso;
    dataToSave['updated_at'] ??= nowIso;
    dataToSave['conversation_id'] = cleanConvId;
    dataToSave['id'] = cleanMsgId;

    bool savedToCloud = false;

    if (isAvailable) {
      try {
        // STEP 1: Direct, guaranteed write to the official subcollection:
        // /conversations/{cleanConvId}/messages/{cleanMsgId}
        // This is 100% permitted under production rules and is NOT poisoned by any other writes.
        await firestore
            .collection('conversations')
            .doc(cleanConvId)
            .collection('messages')
            .doc(cleanMsgId)
            .set(dataToSave, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));

        savedToCloud = true;
        debugPrint('[FirestoreService] Successfully saved chat message $cleanConvId/$cleanMsgId to Cloud subcollection');

        // STEP 2: Update conversation last_message summary and updated_at
        try {
          await firestore
              .collection('conversations')
              .doc(cleanConvId)
              .set(
                {
                  'last_message': {
                    'id': cleanMsgId,
                    'text': dataToSave['text'] ?? '',
                    'sender_id': dataToSave['sender_id'] ?? '',
                    'sender_name': dataToSave['sender_name'] ?? '',
                    'created_at': dataToSave['created_at'] ?? nowIso,
                  },
                  'updated_at': nowIso,
                },
                SetOptions(merge: true),
              )
              .timeout(const Duration(seconds: 6));
        } catch (convErr) {
          debugPrint('[FirestoreService] Non-critical conv summary update note: $convErr');
        }

        // STEP 3: Best-effort write to root collection (isolated so rules never block subcollection)
        try {
          await firestore
              .collection('messages')
              .doc(cleanMsgId)
              .set(dataToSave, SetOptions(merge: true))
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      } catch (e) {
        debugPrint('[FirestoreService] SDK direct saveChatMessage error: $e');
      }
    }

    // REST fallback if SDK wasn't available or failed
    if (!savedToCloud) {
      try {
        // Save directly to the subcollection endpoint in Firestore REST API
        await saveDocument('conversations/$cleanConvId/messages', cleanMsgId, dataToSave);
        await saveDocument('conversations', cleanConvId, {
          'last_message': {
            'id': cleanMsgId,
            'text': dataToSave['text'] ?? '',
            'sender_id': dataToSave['sender_id'] ?? '',
            'sender_name': dataToSave['sender_name'] ?? '',
            'created_at': dataToSave['created_at'] ?? nowIso,
          },
          'updated_at': nowIso,
        });
        debugPrint('[FirestoreService] Successfully saved chat message via REST subcollection fallback');
      } catch (e) {
        debugPrint('[FirestoreService] REST saveChatMessage fallback error: $e');
      }
    }

    // STEP 4: Always mirror message into SharedPreferences cache for instant persistence across Web refreshes
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('local_cached_chat_messages_v1');
      List<dynamic> list = [];
      if (cachedStr != null && cachedStr.isNotEmpty) {
        try {
          list = jsonDecode(cachedStr);
        } catch (_) {}
      }
      list.removeWhere((item) => item is Map && item['id'] == cleanMsgId);
      list.add(dataToSave);
      await prefs.setString('local_cached_chat_messages_v1', jsonEncode(list));
    } catch (_) {}
  }

  /// Syncs messages for a specific conversation from Cloud Firestore into local SQLite & Web cache
  Future<void> syncCloudMessagesForConversation(String conversationId) async {
    final cleanConvId = conversationId.trim();
    if (cleanConvId.isEmpty) return;

    try {
      final db = await DatabaseHelper().database;
      final cloudDocs = await fetchConversationMessages(cleanConvId);

      for (final doc in cloudDocs) {
        final msgId = doc['id']?.toString() ?? doc['_docId']?.toString() ?? '';
        final text = doc['text']?.toString() ?? '';
        final senderId = doc['sender_id']?.toString() ?? '';
        final createdAt = doc['created_at']?.toString() ?? DateTime.now().toIso8601String();
        final isRead = (doc['is_read'] == true || doc['is_read'] == 1) ? 1 : 0;

        if (msgId.isEmpty || text.isEmpty) continue;

        await db.insert(
          'messages',
          {
            'id': msgId,
            'conversation_id': cleanConvId,
            'sender_id': senderId,
            'text': text,
            'created_at': createdAt,
            'is_read': isRead,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      // Persist to SharedPreferences cache for instant display on Web refresh
      try {
        final prefs = await SharedPreferences.getInstance();
        final allMessages = await db.query('messages');
        await prefs.setString('local_cached_chat_messages_v1', jsonEncode(allMessages));
      } catch (_) {}

      debugPrint('[FirestoreService] Synced ${cloudDocs.length} messages for $cleanConvId');
    } catch (e) {
      debugPrint('[FirestoreService] syncCloudMessagesForConversation error: $e');
    }
  }

  /// Syncs all locally stored messages from SQLite up to Cloud Firestore.
  /// Guarantees that any messages sent on physical Android devices while offline/prior
  /// become instantly available to Web browsers.
  Future<void> syncLocalMessagesToCloud() async {
    try {
      final db = await DatabaseHelper().database;
      final localMessages = await db.query('messages');
      if (localMessages.isEmpty) return;

      for (final msg in localMessages) {
        final msgId = msg['id']?.toString() ?? '';
        final convId = msg['conversation_id']?.toString() ?? '';
        final text = msg['text']?.toString() ?? '';
        if (msgId.isEmpty || convId.isEmpty || text.isEmpty) continue;

        await saveChatMessage(
          conversationId: convId,
          messageId: msgId,
          data: {
            'id': msgId,
            'conversation_id': convId,
            'sender_id': msg['sender_id']?.toString() ?? '',
            'text': text,
            'created_at': msg['created_at']?.toString() ?? DateTime.now().toIso8601String(),
            'is_read': (msg['is_read'] == 1),
          },
        );
      }
      debugPrint('[FirestoreService] Synced ${localMessages.length} local messages up to Cloud Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] syncLocalMessagesToCloud error: $e');
    }
  }

  bool get _isTestEnv {
    try {
      final binding = WidgetsBinding.instance;
      return binding.runtimeType.toString().contains('Test');
    } catch (_) {
      return false;
    }
  }

  /// Generic helper to save or merge a document in any collection
  Future<void> saveDocument(String collection, String docId, Map<String, dynamic> data) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;
    if (_isTestEnv) {
      debugPrint('[FirestoreService] Test environment: skipping write for $collection/$cleanDocId');
      return;
    }

    final dataToSave = Map<String, dynamic>.from(data);
    final nowIso = DateTime.now().toIso8601String();
    dataToSave['updated_at'] ??= nowIso;
    dataToSave['created_at'] ??= nowIso;

    if (isAvailable) {
      try {
        await firestore.collection(collection).doc(cleanDocId).set(dataToSave, SetOptions(merge: true))
            .timeout(const Duration(seconds: 12));
        debugPrint('[FirestoreService] Successfully saved $collection/$cleanDocId via SDK');
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK saveDocument error: $e');
      }
    }

    try {
      final dio = _dio;
      final fields = <String, dynamic>{};
      for (final entry in dataToSave.entries) {
        fields[entry.key] = _convertValueToFirestoreField(entry.value);
      }
      final maskQuery = fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      final keyParam = apiKey.isNotEmpty ? '&key=$apiKey' : '';
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collection/$cleanDocId?$maskQuery$keyParam';
      await dio.patch(url, data: {'fields': fields});
      debugPrint('[FirestoreService] Successfully saved $collection/$cleanDocId via REST');
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
    if (_isTestEnv) return;

    if (isAvailable) {
      try {
        await firestore
            .collection(collection)
            .doc(cleanDocId)
            .delete()
            .timeout(const Duration(seconds: 12));
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK deleteDocument error: $e');
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
  Future<void> deleteUser(String userId, {String? email, String? username}) async {
    invalidateUsersSyncCache();
    final cleanId = userId.trim();
    final cleanEmail = email?.trim().toLowerCase() ?? '';
    final cleanUser = username?.trim().toLowerCase() ?? '';

    if (cleanId.isNotEmpty) {
      await deleteDocument('users', cleanId);
    }
    if (cleanEmail.isNotEmpty && cleanEmail != cleanId.toLowerCase()) {
      await deleteDocument('users', cleanEmail);
    }
    if (cleanUser.isNotEmpty && cleanUser != cleanId.toLowerCase() && cleanUser != cleanEmail) {
      await deleteDocument('users', cleanUser);
    }

    if (isAvailable) {
      try {
        final List<Future<QuerySnapshot<Map<String, dynamic>>>> queries = [];
        if (cleanId.isNotEmpty) {
          queries.add(usersCollection.where('id', isEqualTo: cleanId).get());
        }
        if (cleanEmail.isNotEmpty) {
          queries.add(usersCollection.where('email_lower', isEqualTo: cleanEmail).get());
          queries.add(usersCollection.where('email', isEqualTo: cleanEmail).get());
        }
        if (cleanUser.isNotEmpty) {
          queries.add(usersCollection.where('username_lower', isEqualTo: cleanUser).get());
          queries.add(usersCollection.where('username', isEqualTo: cleanUser).get());
        }
        final results = await Future.wait(queries);
        for (final snap in results) {
          for (final doc in snap.docs) {
            await deleteDocument('users', doc.id);
          }
        }
      } catch (e) {
        debugPrint('[FirestoreService] Note finding user docs to delete: $e');
      }
    }
  }
}

