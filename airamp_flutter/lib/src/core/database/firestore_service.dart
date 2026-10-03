import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
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

    // 1. Try Firebase SDK if available
    if (isAvailable) {
      try {
        await usersCollection.doc(id).set(dataToSave, SetOptions(merge: true));
        debugPrint('[FirestoreService] Successfully saved user $id via SDK');
        return;
      } catch (e) {
        debugPrint('[FirestoreService] SDK save failed, falling back to REST: $e');
      }
    }

    // 2. REST API Fallback
    try {
      final dio = _dio;
      final url = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users/$id?key=$apiKey';
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

    // 1. Try SDK if available
    if (isAvailable) {
      try {
        // Direct document ID lookup (e.g. 001-0001, 002-0001)
        final byDoc = await usersCollection.doc(rawTrimmed).get();
        if (byDoc.exists && byDoc.data() != null) {
          final data = byDoc.data()!;
          if (!data.containsKey('id')) data['id'] = byDoc.id;
          return data;
        }

        // Search by id field
        final byId = await usersCollection.where('id', isEqualTo: rawTrimmed).limit(1).get();
        if (byId.docs.isNotEmpty) return byId.docs.first.data();

        // Search by email_lower
        final byEmail = await usersCollection.where('email_lower', isEqualTo: idLower).limit(1).get();
        if (byEmail.docs.isNotEmpty) return byEmail.docs.first.data();

        // Search by username_lower
        final byUserLower = await usersCollection.where('username_lower', isEqualTo: idLower).limit(1).get();
        if (byUserLower.docs.isNotEmpty) return byUserLower.docs.first.data();

        // Search by email
        final byEmailRaw = await usersCollection.where('email', isEqualTo: rawTrimmed).limit(1).get();
        if (byEmailRaw.docs.isNotEmpty) return byEmailRaw.docs.first.data();

        // Search by username
        final byUserRaw = await usersCollection.where('username', isEqualTo: rawTrimmed).limit(1).get();
        if (byUserRaw.docs.isNotEmpty) return byUserRaw.docs.first.data();

        // Search by full_name
        final byFullName = await usersCollection.where('full_name', isEqualTo: rawTrimmed).limit(1).get();
        if (byFullName.docs.isNotEmpty) return byFullName.docs.first.data();
      } catch (e) {
        debugPrint('[FirestoreService] SDK search note: $e');
      }
    }

    // 2. High-reliability REST query fallback
    // Try direct document fetch by ID
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

    Map<String, dynamic>? match = await _queryRest('id', rawTrimmed);
    if (match != null) return match;

    match = await _queryRest('email_lower', idLower);
    if (match != null) return match;

    match = await _queryRest('username_lower', idLower);
    if (match != null) return match;

    match = await _queryRest('email', rawTrimmed);
    if (match != null) return match;

    match = await _queryRest('username', rawTrimmed);
    if (match != null) return match;

    match = await _queryRest('full_name', rawTrimmed);
    return match;
  }

  /// Fetches all users from Cloud Firestore (via SDK or REST fallback)
  Future<List<Map<String, dynamic>>> fetchAllUsers() async {
    List<Map<String, dynamic>> cloudUsers = [];
    if (isAvailable) {
      try {
        final snapshot = await usersCollection.get();
        cloudUsers = snapshot.docs.map((d) {
          final data = d.data();
          data['id'] = d.id;
          return data;
        }).toList();
      } catch (_) {}
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

  /// Syncs all existing local SQLite users to Cloud Firestore so no accounts are lost
  Future<void> syncLocalUsersToCloud() async {
    try {
      final db = await DatabaseHelper().database;
      final localUsers = await db.query('users');
      for (final user in localUsers) {
        await saveUser(user);
      }
      debugPrint('[FirestoreService] Pushed ${localUsers.length} local users to Cloud Firestore');
    } catch (e) {
      debugPrint('[FirestoreService] Error pushing local users to Cloud: $e');
    }
  }

  /// Syncs Cloud Firestore users down to local SQLite cache
  Future<void> syncCloudUsersToLocal() async {
    try {
      List<Map<String, dynamic>> cloudUsers = [];

      if (isAvailable) {
        try {
          final snapshot = await usersCollection.get();
          cloudUsers = snapshot.docs.map((d) {
            final data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        } catch (_) {}
      }

      if (cloudUsers.isEmpty) {
        cloudUsers = await _fetchAllRest();
      }

      if (cloudUsers.isEmpty) return;

      final db = await DatabaseHelper().database;

      for (final data in cloudUsers) {
        try {
          final userId = data['id']?.toString();
          if (userId == null || userId.isEmpty) continue;
          final email = (data['email']?.toString() ?? '').toLowerCase().trim();

          List<Map<String, dynamic>> existing = await db.query('users', where: 'id = ?', whereArgs: [userId]);
          if (existing.isEmpty && email.isNotEmpty) {
            existing = await db.query('users', where: 'LOWER(email) = ?', whereArgs: [email]);
          }

          final dbRow = {
            'id': existing.isNotEmpty ? existing.first['id'] : userId,
            'email': data['email'] ?? '',
            'username': data['username'] ?? '',
            'password': data['password'] ?? '',
            'password_salt': data['password_salt'],
            'role': data['role'] ?? 'student',
            'full_name': data['full_name'] ?? '',
            'section': data['section'],
            'grade': data['grade'],
            'student_type': data['student_type'] ?? 'regular',
            'special_notes': data['special_notes'],
            'school_id': data['school_id'] ?? 'sch_main',
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
        await firestore.collection(collection).doc(cleanDocId).set(data, SetOptions(merge: true));
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
        final snap = await firestore.collection(collection).doc(cleanDocId).get();
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
}

