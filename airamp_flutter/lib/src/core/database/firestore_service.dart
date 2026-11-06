import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  /// Activates real-time live synchronization of Cloud Firestore users.
  /// Any creation, modification, archive, or deletion of users on ANY device
  /// is instantly streamed down, cached locally, and notified to the UI.
  void startRealtimeUserSync() {
    if (_isRealtimeSyncActive || !isAvailable) return;
    _isRealtimeSyncActive = true;

    try {
      _usersSubscription = usersCollection.snapshots().listen(
        (snapshot) async {
          debugPrint('[FirestoreService] Real-time users update received: ${snapshot.docs.length} docs');
          final cloudUsers = snapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
          await applyCloudUsersToLocal(cloudUsers);
        },
        onError: (e) {
          debugPrint('[FirestoreService] Real-time users stream note: $e');
        },
      );
      debugPrint('[FirestoreService] Real-time live user sync activated');
    } catch (e) {
      debugPrint('[FirestoreService] Could not start real-time user sync: $e');
    }
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
      await usersCollection.limit(1).get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 8));
      debugPrint('[FirestoreService] Cloud Firestore SDK connected successfully');
      startRealtimeUserSync();
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

  /// Generic helper to fetch all documents from any collection in Cloud Firestore (SDK + REST fallback)
  Future<List<Map<String, dynamic>>> fetchAllDocuments(String collection) async {
    final list = <Map<String, dynamic>>[];
    if (isAvailable) {
      try {
        final snap = await firestore
            .collection(collection)
            .get(const GetOptions(source: Source.serverAndCache))
            .timeout(const Duration(seconds: 12));
        for (final doc in snap.docs) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          list.add(data);
        }
        if (list.isNotEmpty) return list;
      } catch (e) {
        debugPrint('[FirestoreService] SDK fetchAllDocuments for $collection error: $e');
      }
    }

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
      debugPrint('[FirestoreService] REST fetchAllDocuments for $collection error: $e');
      return list;
    }
  }

  /// Calculates the highest numeric sequence for a given ID prefix (e.g. 'S-100-', 'T-100-', 'A-100-', 'SA-000-', or legacy '001-')
  Future<int> getHighestSequence(String prefix) async {
    int maxSeq = 0;
    final cleanPrefix = prefix.toUpperCase();
    try {
      final allUsers = await fetchAllUsers();
      for (final u in allUsers) {
        final uid = (u['id']?.toString() ?? '').toUpperCase();
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
    } catch (e) {
      debugPrint('[FirestoreService] getHighestSequence note: $e');
    }
    return maxSeq;
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

  /// Searches Cloud Firestore for an account by email, ID, or username.
  /// Uses ultra-fast REST direct fetches first (<200ms) with SDK fallback.
  Future<Map<String, dynamic>?> findUserByIdentifier(String identifier) async {
    final rawTrimmed = identifier.trim();
    final idLower = rawTrimmed.toLowerCase();
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

  /// Syncs Cloud Firestore users down to local SQLite cache and prunes deleted accounts
  Future<void> syncCloudUsersToLocal() async {
    try {
      List<Map<String, dynamic>> cloudUsers = [];

      if (isAvailable) {
        try {
          final snapshot = await usersCollection.get().timeout(const Duration(seconds: 8));
          cloudUsers = snapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        } catch (e) {
          debugPrint('[FirestoreService] SDK syncCloudUsersToLocal note: $e');
        }
      }

      if (cloudUsers.isEmpty) {
        cloudUsers = await _fetchAllRest();
      }

      if (cloudUsers.isEmpty) return;

      await applyCloudUsersToLocal(cloudUsers);
    } catch (e) {
      debugPrint('[FirestoreService] Error syncing cloud users to local SQLite: $e');
    }
  }

  /// Ingests a set of Cloud Firestore user documents into the local SQLite memory/disk store
  /// and synchronizes state across devices in real time.
  Future<void> applyCloudUsersToLocal(List<Map<String, dynamic>> cloudUsers) async {
    try {
      if (cloudUsers.isEmpty) return;

      final db = await DatabaseHelper().database;
      final prefs = await SharedPreferences.getInstance();
      final deletedList = prefs.getStringList('permanently_deleted_accounts') ?? [];

      final cloudIds = <String>{};
      final cloudEmails = <String>{};

      for (final data in cloudUsers) {
        try {
          final userId = data['id']?.toString() ?? '';
          final email = (data['email']?.toString() ?? '').toLowerCase().trim();
          if (userId.isEmpty && email.isEmpty) continue;

          // If an active account exists in Cloud Firestore, ensure it is not blocked by stale local deleted tombstone
          if (deletedList.contains(userId) || (email.isNotEmpty && deletedList.contains(email))) {
            deletedList.remove(userId);
            deletedList.remove(email);
            unawaited(prefs.setStringList('permanently_deleted_accounts', deletedList));
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
          final prefMust = prefs.getBool('must_change_password_$userId') == true ||
              (email.isNotEmpty && prefs.getBool('must_change_password_$email') == true);

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
              await db.update(
                'sessions',
                {'must_change_password': 1},
                where: 'user_id = ?' + (email.isNotEmpty ? ' OR LOWER(user_id) = ?' : ''),
                whereArgs: [targetId, if (email.isNotEmpty) email],
              );
              await prefs.setBool('must_change_password_$targetId', true);
              if (email.isNotEmpty) await prefs.setBool('must_change_password_$email', true);
            } catch (_) {}
          } else {
            try {
              await db.update(
                'sessions',
                {'must_change_password': 0},
                where: 'user_id = ?' + (email.isNotEmpty ? ' OR LOWER(user_id) = ?' : ''),
                whereArgs: [targetId, if (email.isNotEmpty) email],
              );
              await prefs.remove('must_change_password_$targetId');
              if (email.isNotEmpty) await prefs.remove('must_change_password_$email');
            } catch (_) {}
          }

          final isArchived = data['is_archived'] == 1 ||
              data['is_archived'] == true ||
              data['is_archived'] == '1';
          final archivedAt = data['archived_at']?.toString();

          final dbRow = {
            'id': targetId,
            'email': data['email'] ?? '',
            'username': data['username'] ?? '',
            'password': data['password'] ?? '',
            'password_salt': data['password_salt'],
            'role': data['role'] ?? 'student',
            'full_name': data['full_name'] ?? data['name'] ?? '',
            'profile_image': data['profile_image'] ?? data['profileImage'] ?? (existing.isNotEmpty ? existing.first['profile_image'] : null),
            'section': data['section'],
            'grade': data['grade'],
            'student_type': data['student_type'] ?? 'regular',
            'special_notes': data['special_notes'],
            'school_id': data['school_id'] ?? 'sch_main',
            'must_change_password': mustChangeVal,
            'is_archived': isArchived ? 1 : 0,
            'archived_at': isArchived ? (archivedAt ?? DateTime.now().toIso8601String()) : null,
            'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
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

        // Cloud Firestore is authoritative across all platforms. If a user exists locally in SQLite/memory
        // but is absent from Cloud Firestore, it was deleted in the cloud or previously.
        // Prune it immediately from local cache so it NEVER resurrects into Cloud Firestore!
        if (!isPermanentSeed &&
            !cloudIds.contains(localId) &&
            !cloudEmails.contains(localEmail)) {
          await db.delete('users', where: 'id = ?', whereArgs: [localId]);
          try {
            await db.delete('enrollments', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('quiz_attempts', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('student_progress', where: 'student_id = ?', whereArgs: [localId]);
            await db.delete('submissions', where: 'student_id = ?', whereArgs: [localId]);
          } catch (_) {}
          debugPrint('[FirestoreService] Pruned cloud-deleted user from local cache: $localId ($localEmail)');
          continue;
        }
      }

      debugPrint('[FirestoreService] Applied ${cloudUsers.length} Cloud Firestore users to local store');
      notifySyncListeners();
    } catch (e) {
      debugPrint('[FirestoreService] Error applying cloud users to local SQLite: $e');
    }
  }

  /// Generic helper to save or merge a document in any collection
  Future<void> saveDocument(String collection, String docId, Map<String, dynamic> data) async {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    if (isAvailable) {
      try {
        await firestore.collection(collection).doc(cleanDocId).set(data, SetOptions(merge: true))
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
      for (final entry in data.entries) {
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

