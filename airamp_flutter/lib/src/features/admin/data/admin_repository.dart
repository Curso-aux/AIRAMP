import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';

import '../../../core/utils/section_key_helper.dart';
import '../../../core/utils/csv_helper.dart';

import '../../../core/services/email_service.dart';
import '../../../core/database/firestore_service.dart';

// --- Announcements ---
final announcementsProvider =
    NotifierProvider<AnnouncementsNotifier, List<Map<String, dynamic>>>(() {
      return AnnouncementsNotifier();
    });

class AnnouncementsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadAnnouncements();
    return [];
  }

  Future<void> _loadAnnouncements() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'announcements',
      orderBy: 'id DESC',
    );
    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> addAnnouncement(Map<String, dynamic> announcement) async {
    final db = await DatabaseHelper().database;
    await db.insert('announcements', announcement);
    await _loadAnnouncements();
  }

  Future<void> updateAnnouncement(
    int id,
    Map<String, dynamic> announcement,
  ) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'announcements',
      announcement,
      where: 'id = ?',
      whereArgs: [id],
    );
    await _loadAnnouncements();
  }

  Future<void> deleteAnnouncement(int id) async {
    final db = await DatabaseHelper().database;
    await db.delete('announcements', where: 'id = ?', whereArgs: [id]);
    await _loadAnnouncements();
  }
}

// --- Inquiries & Helpdesk ---
final inquiriesProvider =
    NotifierProvider<InquiriesNotifier, List<Map<String, dynamic>>>(() {
      return InquiriesNotifier();
    });

final pendingInquiriesCountProvider = FutureProvider<int>((ref) async {
  ref.watch(inquiriesProvider);
  return await DatabaseHelper().getPendingInquiriesCount();
});

class InquiriesNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadInquiries();
    return [];
  }

  Future<void> loadInquiries({String? status}) async {
    final list = await DatabaseHelper().getInquiries(status: status);
    if (!ref.mounted) return;
    state = list;
  }

  Future<void> reply({
    required String inquiryId,
    required String replyText,
    required String adminName,
    required String adminId,
  }) async {
    final list = await DatabaseHelper().getInquiries();
    final inq = list.firstWhere((i) => i['id'] == inquiryId, orElse: () => {});
    if (inq.isEmpty) return;

    // 1. Update status in database
    await DatabaseHelper().replyToInquiry(
      inquiryId: inquiryId,
      reply: replyText,
      repliedBy: adminName,
    );

    // 2. Deliver in-app notification to student/teacher system
    final userId = inq['user_id'] as String? ?? '';
    if (userId.isNotEmpty) {
      await DatabaseHelper().createNotification(
        userId: userId,
        type: 'admin_inquiry_reply',
        title: 'School Administration Replied to Your Inquiry',
        message: 'Question: "${inq['question']}"\n\nAdmin Reply: $replyText',
        actorId: adminId,
        actorName: adminName,
      );
    }

    // 3. Deliver email via EmailService SMTP
    final userEmail = inq['user_email'] as String? ?? '';
    if (userEmail.isNotEmpty) {
      await EmailService().sendInquiryReply(
        toEmail: userEmail,
        fullName: inq['user_name'] as String? ?? 'User',
        userId: userId,
        role: inq['user_role'] as String? ?? 'student',
        inquiryQuestion: inq['question'] as String? ?? '',
        adminReply: replyText,
        adminName: adminName,
      );
    }

    await loadInquiries();
  }
}

// --- Subjects ---
final subjectsProvider =
    NotifierProvider<SubjectsNotifier, List<Map<String, dynamic>>>(() {
      return SubjectsNotifier();
    });

class SubjectsNotifier extends Notifier<List<Map<String, dynamic>>> {
  SubjectsNotifier({Dio? dio});
  VoidCallback? _syncListener;

  @override
  List<Map<String, dynamic>> build() {
    _syncListener = () async {
      if (ref.mounted) {
        final db = await DatabaseHelper().database;
        await DatabaseHelper().deduplicateSubjects();
        final fresh = await db.rawQuery('''
          SELECT s.*,
                 (SELECT COUNT(DISTINCT e.student_id) 
                  FROM enrollments e 
                  WHERE e.subject_id = s.id 
                    AND (e.status IS NULL OR e.status = 'active')) as enrolled_count
          FROM subjects s
          ORDER BY s.id DESC
        ''');
        final Map<String, Map<String, dynamic>> deduped = {};
        for (final s in fresh) {
          final code =
              (s['subject_code']?.toString() ?? s['name']?.toString() ?? '')
                  .trim()
                  .toUpperCase();
          if (code.isEmpty) continue;
          if (!deduped.containsKey(code)) {
            deduped[code] = s;
          } else {
            final curCount =
                (deduped[code]!['enrolled_count'] as num?)?.toInt() ?? 0;
            final newCount = (s['enrolled_count'] as num?)?.toInt() ?? 0;
            if (newCount > curCount) {
              deduped[code] = s;
            }
          }
        }
        if (ref.mounted) state = deduped.values.toList();
      }
    };
    FirestoreService.addSyncListener(_syncListener!);
    ref.onDispose(() {
      if (_syncListener != null) {
        FirestoreService.removeSyncListener(_syncListener!);
      }
    });

    _loadSubjects();
    return [];
  }

  Future<void> _loadSubjects() async {
    final db = await DatabaseHelper().database;
    final existingLocal = await db.query('subjects');

    // 1. Instant cache restore + sync from cloud (with REST fallback)
    await FirestoreService().syncCloudSubjectsToLocal(
      force: kIsWeb || existingLocal.isEmpty,
    );
    if (kIsWeb) {
      try {
        await FirestoreService().syncCloudSectionsToLocal(force: true);
        await FirestoreService().syncCloudUsersToLocal(force: true);
        await DatabaseHelper().reconcileAllEnrollments();
      } catch (_) {}
    }
    await DatabaseHelper().deduplicateSubjects();

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final deletedSubjects =
        prefs?.getStringList('permanently_deleted_subjects') ?? [];

    // 2. Filter out any deleted tombstones and save active subjects to local cache
    for (final del in deletedSubjects) {
      await db.delete(
        'subjects',
        where: 'UPPER(subject_code) = ? OR UPPER(name) = ?',
        whereArgs: [del.toUpperCase(), del.toUpperCase()],
      );
    }
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*,
             (SELECT COUNT(DISTINCT e.student_id) 
              FROM enrollments e 
              WHERE e.subject_id = s.id 
                AND (e.status IS NULL OR e.status = 'active')) as enrolled_count
      FROM subjects s
      ORDER BY s.id DESC
    ''');
    final Map<String, Map<String, dynamic>> deduped = {};
    for (final s in maps) {
      final code =
          (s['subject_code']?.toString() ?? s['name']?.toString() ?? '')
              .trim()
              .toUpperCase();
      if (code.isEmpty) continue;
      if (!deduped.containsKey(code)) {
        deduped[code] = s;
      } else {
        final curCount =
            (deduped[code]!['enrolled_count'] as num?)?.toInt() ?? 0;
        final newCount = (s['enrolled_count'] as num?)?.toInt() ?? 0;
        if (newCount > curCount) {
          deduped[code] = s;
        }
      }
    }
    final finalSubjects = deduped.values.toList();
    if (prefs != null) {
      try {
        await prefs.setString(
          'local_cached_subjects_v1',
          jsonEncode(finalSubjects),
        );
      } catch (_) {}
    }

    if (!ref.mounted) return;
    state = finalSubjects;
  }

  Future<int> addSubject(Map<String, dynamic> subject) async {
    final db = await DatabaseHelper().database;
    final mutableSubject = Map<String, dynamic>.from(subject);
    mutableSubject['created_at'] ??= DateTime.now().toIso8601String();

    final id = await db.insert('subjects', mutableSubject);
    mutableSubject['id'] = id;
    await DatabaseHelper().autoEnrollAllStudentsInSubject(id);

    final subCode =
        mutableSubject['subject_code']?.toString().trim().toUpperCase() ?? '';
    final subName = mutableSubject['name']?.toString().trim() ?? '';
    final docId = subCode.isNotEmpty ? subCode : 'SUBJ_$id';

    final currentMaps = await db.query('subjects', orderBy: 'id DESC');

    // Remove from tombstone if re-created
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList('permanently_deleted_subjects') ?? [];
      if (deleted.contains(subCode) ||
          deleted.contains(subName) ||
          deleted.contains(docId)) {
        deleted.remove(subCode);
        deleted.remove(subName);
        deleted.remove(docId);
        await prefs.setStringList('permanently_deleted_subjects', deleted);
      }
      await prefs.setBool('cloud_subjects_initialized', true);

      // Save immediately to persistent local cache!
      await prefs.setString(
        'local_cached_subjects_v1',
        jsonEncode(currentMaps),
      );
      await prefs.remove('last_cloud_fetch_subjects');
    } catch (_) {}

    // Save to Cloud Firestore
    try {
      final cloudData = {
        'id': docId,
        'name': subName,
        'subject_code': subCode,
        'description': mutableSubject['description']?.toString() ?? '',
        'grade_level': mutableSubject['grade_level']?.toString() ?? 'Grade 10',
        'semester': mutableSubject['semester']?.toString() ?? '1st Semester',
        'unlock_type': mutableSubject['unlock_type']?.toString() ?? 'Flexible',
        'teacher_id': mutableSubject['teacher_id']?.toString(),
        'teacher_name': mutableSubject['teacher_name']?.toString(),
        'created_at': mutableSubject['created_at'],
      };
      await FirestoreService().saveDocument('subjects', docId, cloudData);
    } catch (_) {}

    if (ref.mounted) {
      state = currentMaps;
    }
    return id;
  }

  Future<void> updateSubject(int id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper().database;
    await db.update('subjects', data, where: 'id = ?', whereArgs: [id]);

    final updated = (await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    if (updated != null) {
      final prefs = await SharedPreferences.getInstance();
      final currentMaps = await db.query('subjects', orderBy: 'id DESC');
      try {
        await prefs.setString(
          'local_cached_subjects_v1',
          jsonEncode(currentMaps),
        );
      } catch (_) {}

      final subCode =
          updated['subject_code']?.toString().trim().toUpperCase() ?? '';
      final docId = subCode.isNotEmpty ? subCode : 'SUBJ_$id';
      try {
        final cloudData = {
          'id': docId,
          'name': updated['name']?.toString() ?? '',
          'subject_code': subCode,
          'description': updated['description']?.toString() ?? '',
          'grade_level': updated['grade_level']?.toString() ?? 'Grade 10',
          'semester': updated['semester']?.toString() ?? '1st Semester',
          'unlock_type': updated['unlock_type']?.toString() ?? 'Flexible',
          'teacher_id': updated['teacher_id']?.toString(),
          'teacher_name': updated['teacher_name']?.toString(),
          'created_at':
              updated['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
        };
        await FirestoreService().saveDocument('subjects', docId, cloudData);
      } catch (_) {}
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*,
             (SELECT COUNT(DISTINCT e.student_id) 
              FROM enrollments e 
              WHERE e.subject_id = s.id 
                AND (e.status IS NULL OR e.status = 'active')) as enrolled_count
      FROM subjects s
      ORDER BY s.id DESC
    ''');
    if (ref.mounted) {
      state = maps;
      ref.invalidate(adminTeachersProvider);
      ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    }
  }

  Future<void> updateUnlockType(int id, String unlockType) async {
    final db = await DatabaseHelper().database;
    await db.update(
      'subjects',
      {'unlock_type': unlockType},
      where: 'id = ?',
      whereArgs: [id],
    );

    final updated = (await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    if (updated != null) {
      final prefs = await SharedPreferences.getInstance();
      final currentMaps = await db.query('subjects', orderBy: 'id DESC');
      try {
        await prefs.setString(
          'local_cached_subjects_v1',
          jsonEncode(currentMaps),
        );
      } catch (_) {}

      final subCode =
          updated['subject_code']?.toString().trim().toUpperCase() ?? '';
      final docId = subCode.isNotEmpty ? subCode : 'SUBJ_$id';
      try {
        await FirestoreService().saveDocument('subjects', docId, {
          'unlock_type': unlockType,
        });
      } catch (_) {}
    }

    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT s.*,
             (SELECT COUNT(DISTINCT e.student_id) 
              FROM enrollments e 
              WHERE e.subject_id = s.id 
                AND (e.status IS NULL OR e.status = 'active')) as enrolled_count
      FROM subjects s
      ORDER BY s.id DESC
    ''');
    if (ref.mounted) {
      state = maps;
      ref.invalidate(adminTeachersProvider);
      ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    }
  }

  Future<void> deleteSubject(int id) async {
    final db = await DatabaseHelper().database;
    final existing = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    );

    String? subCode;
    String? subName;
    if (existing.isNotEmpty) {
      subCode = existing.first['subject_code']?.toString().trim().toUpperCase();
      subName = existing.first['name']?.toString().trim();
    }

    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
    await db.delete('topics', where: 'subject_id = ?', whereArgs: [id]);
    await db.delete('enrollments', where: 'subject_id = ?', whereArgs: [id]);
    await db.delete('quizzes', where: 'subject_id = ?', whereArgs: [id]);

    final docId = (subCode != null && subCode.isNotEmpty)
        ? subCode
        : 'SUBJ_$id';

    // Delete from Cloud Firestore
    try {
      await FirestoreService().deleteDocument('subjects', docId);
      if (subCode != null && subCode.isNotEmpty && subCode != docId) {
        await FirestoreService().deleteDocument('subjects', subCode);
      }
      if (subName != null && subName.isNotEmpty) {
        await FirestoreService().deleteDocument('subjects', subName);
      }
    } catch (_) {}

    // Save tombstone in SharedPreferences so it NEVER resurrects!
    List<Map<String, dynamic>> currentMaps = await db.query(
      'subjects',
      orderBy: 'id DESC',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      final deleted = prefs.getStringList('permanently_deleted_subjects') ?? [];
      if (subCode != null && subCode.isNotEmpty && !deleted.contains(subCode)) {
        deleted.add(subCode);
      }
      if (subName != null && subName.isNotEmpty && !deleted.contains(subName)) {
        deleted.add(subName);
      }
      if (!deleted.contains(docId)) {
        deleted.add(docId);
      }
      await prefs.setStringList('permanently_deleted_subjects', deleted);
      await prefs.setBool('cloud_subjects_initialized', true);

      await prefs.setString(
        'local_cached_subjects_v1',
        jsonEncode(currentMaps),
      );
      await prefs.remove('last_cloud_fetch_subjects');
    } catch (_) {}

    if (ref.mounted) state = currentMaps;
  }

  Future<void> reload() async {
    await FirestoreService().syncCloudSubjectsToLocal(force: true);
    await _loadSubjects();
  }

  Future<Map<String, dynamic>?> getSubjectById(int id) async {
    final db = await DatabaseHelper().database;
    final results = await db.query(
      'subjects',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (results.isNotEmpty) return results.first;

    // Check local persistent cache in SharedPreferences as fallback
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString('local_cached_subjects_v1');
      if (cachedStr != null && cachedStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(cachedStr);
        for (final item in decoded) {
          if (item is Map) {
            final m = Map<String, dynamic>.from(item);
            if (m['id'] == id || m['id']?.toString() == id.toString()) {
              await db.insert(
                'subjects',
                m,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              return m;
            }
          }
        }
      }
    } catch (_) {}

    return null;
  }
}

// --- Sections ---
final sectionsProvider =
    NotifierProvider<SectionsNotifier, List<Map<String, dynamic>>>(() {
      return SectionsNotifier();
    });

class SectionsNotifier extends Notifier<List<Map<String, dynamic>>> {
  VoidCallback? _syncListener;

  @override
  List<Map<String, dynamic>> build() {
    _syncListener = () async {
      if (ref.mounted) {
        final db = await DatabaseHelper().database;
        final fresh = await db.query('sections', orderBy: 'id DESC');
        if (ref.mounted) state = fresh;
      }
    };
    FirestoreService.addSyncListener(_syncListener!);
    ref.onDispose(() {
      if (_syncListener != null) {
        FirestoreService.removeSyncListener(_syncListener!);
      }
    });

    _loadSections();
    return [];
  }

  Future<void> _loadSections() async {
    final db = await DatabaseHelper().database;
    final existingLocal = await db.query('sections');

    // 1. Instant cache restore + sync from cloud (with REST fallback)
    await FirestoreService().syncCloudSectionsToLocal(
      force: kIsWeb || existingLocal.isEmpty,
    );

    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final deletedSections =
        prefs?.getStringList('permanently_deleted_sections') ?? [];

    // 2. Filter out any deleted tombstones and save active sections to local cache
    for (final del in deletedSections) {
      await db.delete(
        'sections',
        where: 'UPPER(enrollment_key) = ? OR UPPER(name) = ?',
        whereArgs: [del.toUpperCase(), del.toUpperCase()],
      );
      await db.delete(
        'reg_links',
        where: 'UPPER(code) = ? OR UPPER(section) = ?',
        whereArgs: [del.toUpperCase(), del.toUpperCase()],
      );
    }

    // 3. Ensure all sections have their automated group chats provisioned
    try {
      await DatabaseHelper().ensureAllSectionChatsExist();
    } catch (_) {}

    final List<Map<String, dynamic>> maps = await db.query(
      'sections',
      orderBy: 'id DESC',
    );
    if (prefs != null) {
      try {
        await prefs.setString('local_cached_sections_v1', jsonEncode(maps));
      } catch (_) {}
    }

    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> reload() async {
    await FirestoreService().syncCloudSectionsToLocal(force: true);
    await _loadSections();
  }

  Future<void> addSection(Map<String, dynamic> section) async {
    final db = await DatabaseHelper().database;
    final mutableSection = Map<String, dynamic>.from(section);

    final rawKey =
        mutableSection['enrollment_key']?.toString().trim().toUpperCase() ?? '';
    final sectionName = mutableSection['name']?.toString() ?? 'Section';
    final gradeLevel = mutableSection['grade']?.toString() ?? 'Grade 10';
    final resolvedKey = rawKey.isNotEmpty
        ? rawKey
        : SectionKeyHelper.generateKey(
            sectionName: sectionName,
            gradeLevel: gradeLevel,
          );

    mutableSection['enrollment_key'] = resolvedKey;
    mutableSection['created_at'] ??= DateTime.now().toIso8601String();

    List<String> subjectCodes = [];
    if (mutableSection['subject_ids'] != null) {
      if (mutableSection['subject_ids'] is List) {
        subjectCodes = (mutableSection['subject_ids'] as List)
            .map((e) => e.toString().trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
        mutableSection['subject_ids'] = jsonEncode(subjectCodes);
      } else if (mutableSection['subject_ids'] is String &&
          (mutableSection['subject_ids'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(mutableSection['subject_ids'] as String);
          if (decoded is List) {
            subjectCodes = decoded
                .map((e) => e.toString().trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toList();
            mutableSection['subject_ids'] = jsonEncode(subjectCodes);
          }
        } catch (_) {
          subjectCodes = (mutableSection['subject_ids'] as String)
              .split(',')
              .map((e) => e.trim().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList();
          mutableSection['subject_ids'] = jsonEncode(subjectCodes);
        }
      }
    }

    final id = await db.insert('sections', mutableSection);
    mutableSection['id'] = id;

    await DatabaseHelper().generateEnrollmentKey(
      code: resolvedKey,
      section: sectionName,
      maxUses: 50,
    );

    // Auto-enroll any students in this section into its assigned subjects
    await DatabaseHelper().autoEnrollAllStudentsInSection(sectionName);

    // Resolve designated teacher for room administrator
    String designatedTeacherId = mutableSection['teacher_id']?.toString() ?? '';
    String designatedTeacherName =
        mutableSection['teacher_name']?.toString() ?? '';

    if (designatedTeacherId.isEmpty) {
      if (subjectCodes.isNotEmpty) {
        final subRow = await db.query(
          'subjects',
          where: 'UPPER(subject_code) = ?',
          whereArgs: [subjectCodes.first.toUpperCase()],
        );
        if (subRow.isNotEmpty) {
          designatedTeacherId = subRow.first['teacher_id']?.toString() ?? '';
          designatedTeacherName =
              subRow.first['teacher_name']?.toString() ?? '';
        }
      }
    }

    if (designatedTeacherId.isEmpty) {
      final teacherRows = await db.query(
        'users',
        where: "role = 'teacher' OR role = 'admin'",
      );
      if (teacherRows.isNotEmpty) {
        designatedTeacherId = teacherRows.first['id']?.toString() ?? '';
        designatedTeacherName =
            teacherRows.first['full_name']?.toString() ??
            teacherRows.first['name']?.toString() ??
            'Teacher';
      }
    }

    // Automatically initialize section group chat channel with designated teacher as Room Admin
    if (designatedTeacherId.isNotEmpty) {
      try {
        await DatabaseHelper().createSectionGroupChat(
          sectionId: id,
          sectionName: sectionName,
          sectionKey: resolvedKey,
          teacherId: designatedTeacherId,
          teacherName: designatedTeacherName,
          grade: gradeLevel,
          room: mutableSection['room']?.toString(),
          isInitialCreation: true,
        );
      } catch (e) {
        debugPrint('[SectionsNotifier] Error auto-creating group chat: $e');
      }
    }

    final currentMaps = await db.query('sections', orderBy: 'id DESC');

    // Remove from tombstone if re-created
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_cloud_fetch_keys');
      final deleted = prefs.getStringList('permanently_deleted_sections') ?? [];
      if (deleted.contains(resolvedKey) || deleted.contains(sectionName)) {
        deleted.remove(resolvedKey);
        deleted.remove(sectionName);
        await prefs.setStringList('permanently_deleted_sections', deleted);
      }
      await prefs.setBool('cloud_sections_initialized', true);

      // Save immediately to persistent local cache!
      await prefs.setString(
        'local_cached_sections_v1',
        jsonEncode(currentMaps),
      );
      await prefs.remove('last_cloud_fetch_sections');
      await prefs.remove('last_cloud_fetch_keys');
    } catch (_) {}

    // Save to Cloud Firestore
    try {
      final cloudSection = {
        'id': resolvedKey,
        'name': sectionName,
        'description': mutableSection['description']?.toString() ?? '',
        'grade': gradeLevel,
        'room': mutableSection['room']?.toString() ?? '',
        'student_count': mutableSection['student_count'] ?? 0,
        'enrollment_key': resolvedKey,
        'subject_ids': subjectCodes,
        'created_at': mutableSection['created_at'],
      };
      await FirestoreService().saveDocument(
        'sections',
        resolvedKey,
        cloudSection,
      );
      await FirestoreService().saveDocument('enrollment_keys', resolvedKey, {
        'code': resolvedKey,
        'section': sectionName,
        'max_uses': 50,
        'used_count': 0,
        'expiration': '2026-12-31',
        'created_at': mutableSection['created_at'],
      });
    } catch (_) {}

    if (ref.mounted) {
      state = currentMaps;
    }
    ref.invalidate(availableSectionsProvider);
    ref.read(adminKeysProvider.notifier).loadKeys();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
  }

  Future<void> updateSection(int id, Map<String, dynamic> section) async {
    final db = await DatabaseHelper().database;
    final mutableSection = Map<String, dynamic>.from(section);

    List<String>? subjectCodes;
    if (mutableSection['subject_ids'] != null) {
      if (mutableSection['subject_ids'] is List) {
        subjectCodes = (mutableSection['subject_ids'] as List)
            .map((e) => e.toString().trim().toUpperCase())
            .where((e) => e.isNotEmpty)
            .toList();
        mutableSection['subject_ids'] = jsonEncode(subjectCodes);
      } else if (mutableSection['subject_ids'] is String &&
          (mutableSection['subject_ids'] as String).isNotEmpty) {
        try {
          final decoded = jsonDecode(mutableSection['subject_ids'] as String);
          if (decoded is List) {
            subjectCodes = decoded
                .map((e) => e.toString().trim().toUpperCase())
                .where((e) => e.isNotEmpty)
                .toList();
            mutableSection['subject_ids'] = jsonEncode(subjectCodes);
          }
        } catch (_) {
          subjectCodes = (mutableSection['subject_ids'] as String)
              .split(',')
              .map((e) => e.trim().toUpperCase())
              .where((e) => e.isNotEmpty)
              .toList();
          mutableSection['subject_ids'] = jsonEncode(subjectCodes);
        }
      }
    }

    await db.update(
      'sections',
      mutableSection,
      where: 'id = ?',
      whereArgs: [id],
    );

    final updatedSec = (await db.query(
      'sections',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    final resolvedKey =
        updatedSec?['enrollment_key']?.toString().trim().toUpperCase() ??
        section['enrollment_key']?.toString().trim().toUpperCase();
    final secName =
        updatedSec?['name']?.toString() ?? section['name']?.toString();

    // Auto-enroll students in section into assigned subjects
    if (secName != null && secName.isNotEmpty) {
      await DatabaseHelper().autoEnrollAllStudentsInSection(secName);
    }

    List<Map<String, dynamic>> currentMaps = await db.query(
      'sections',
      orderBy: 'id DESC',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'local_cached_sections_v1',
        jsonEncode(currentMaps),
      );
      await prefs.remove('last_cloud_fetch_sections');
      await prefs.remove('last_cloud_fetch_keys');
    } catch (_) {}

    if (resolvedKey != null && resolvedKey.isNotEmpty) {
      if (secName != null && secName.isNotEmpty) {
        await DatabaseHelper().generateEnrollmentKey(
          code: resolvedKey,
          section: secName,
          maxUses: 50,
        );
      }
      try {
        List<String> finalSubjectCodes = subjectCodes ?? [];
        if (subjectCodes == null && updatedSec?['subject_ids'] != null) {
          final sStr = updatedSec!['subject_ids'].toString();
          try {
            final dec = jsonDecode(sStr);
            if (dec is List) {
              finalSubjectCodes = dec.map((e) => e.toString()).toList();
            }
          } catch (_) {
            finalSubjectCodes = sStr
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }

        final cloudSection = {
          'id': resolvedKey,
          'name': secName ?? '',
          'description':
              updatedSec?['description']?.toString() ??
              section['description']?.toString() ??
              '',
          'grade':
              updatedSec?['grade']?.toString() ??
              section['grade']?.toString() ??
              'Grade 10',
          'room':
              updatedSec?['room']?.toString() ??
              section['room']?.toString() ??
              '',
          'student_count': updatedSec?['student_count'] ?? 0,
          'enrollment_key': resolvedKey,
          'subject_ids': finalSubjectCodes,
          'created_at':
              updatedSec?['created_at']?.toString() ??
              DateTime.now().toIso8601String(),
        };
        await FirestoreService().saveDocument(
          'sections',
          resolvedKey,
          cloudSection,
        );
        if (secName != null && secName.isNotEmpty) {
          await FirestoreService()
              .saveDocument('enrollment_keys', resolvedKey, {
                'code': resolvedKey,
                'section': secName,
                'max_uses': 50,
                'used_count': updatedSec?['student_count'] ?? 0,
                'expiration': '2026-12-31',
                'created_at': DateTime.now().toIso8601String(),
              });
        }
      } catch (_) {}
    }

    if (ref.mounted) state = currentMaps;
    ref.invalidate(availableSectionsProvider);
    ref.read(adminKeysProvider.notifier).loadKeys();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
  }

  /// Assign subjects to a specific section and auto-enroll enrolled students
  Future<void> assignSubjectsToSection(
    int id,
    List<String> subjectCodes,
  ) async {
    final db = await DatabaseHelper().database;
    final jsonStr = jsonEncode(subjectCodes);
    await db.update(
      'sections',
      {'subject_ids': jsonStr},
      where: 'id = ?',
      whereArgs: [id],
    );

    final updatedSec = (await db.query(
      'sections',
      where: 'id = ?',
      whereArgs: [id],
    )).firstOrNull;
    final resolvedKey = updatedSec?['enrollment_key']
        ?.toString()
        .trim()
        .toUpperCase();
    final secName = updatedSec?['name']?.toString();

    if (resolvedKey != null && resolvedKey.isNotEmpty) {
      try {
        await FirestoreService().saveDocument('sections', resolvedKey, {
          'subject_ids': subjectCodes,
        });
      } catch (_) {}
    }

    if (secName != null && secName.isNotEmpty) {
      await DatabaseHelper().autoEnrollAllStudentsInSection(secName);
    }

    await _loadSections();
    ref.invalidate(availableSectionsProvider);
  }

  Future<void> deleteSection(int id) async {
    final db = await DatabaseHelper().database;
    final existing = await db.query(
      'sections',
      where: 'id = ?',
      whereArgs: [id],
    );

    String? secKey;
    String? secName;
    if (existing.isNotEmpty) {
      secKey = existing.first['enrollment_key']
          ?.toString()
          .trim()
          .toUpperCase();
      secName = existing.first['name']?.toString().trim();
    }

    await db.delete('sections', where: 'id = ?', whereArgs: [id]);

    if (secKey != null && secKey.isNotEmpty) {
      await db.delete('reg_links', where: 'code = ?', whereArgs: [secKey]);
    }
    if (secName != null && secName.isNotEmpty) {
      await db.delete('reg_links', where: 'section = ?', whereArgs: [secName]);
    }

    try {
      if (secKey != null && secKey.isNotEmpty) {
        await FirestoreService().deleteDocument('sections', secKey);
        await FirestoreService().deleteDocument('enrollment_keys', secKey);
        await FirestoreService().deleteDocument('reg_links', secKey);
      }
      if (secName != null && secName.isNotEmpty) {
        await FirestoreService().deleteDocument('sections', secName);
      }
    } catch (_) {}

    List<Map<String, dynamic>> currentMaps = await db.query(
      'sections',
      orderBy: 'id DESC',
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_cloud_fetch_keys');
      final deleted = prefs.getStringList('permanently_deleted_sections') ?? [];
      if (secKey != null && secKey.isNotEmpty && !deleted.contains(secKey)) {
        deleted.add(secKey);
      }
      if (secName != null && secName.isNotEmpty && !deleted.contains(secName)) {
        deleted.add(secName);
      }
      await prefs.setStringList('permanently_deleted_sections', deleted);
      await prefs.setBool('cloud_sections_initialized', true);

      await prefs.setString(
        'local_cached_sections_v1',
        jsonEncode(currentMaps),
      );
      await prefs.remove('last_cloud_fetch_sections');
      await prefs.remove('last_cloud_fetch_keys');
    } catch (_) {}

    if (ref.mounted) state = currentMaps;
    ref.invalidate(availableSectionsProvider);
    ref.read(adminKeysProvider.notifier).loadKeys();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
  }
}

// --- Teachers List (for subject assignment) ---
final teachersListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final teachers = ref.watch(adminTeachersProvider);
  if (teachers.isNotEmpty) return teachers;
  return await DatabaseHelper().getTeachersList();
});

// --- Count Providers (for dashboard stats) ---
final subjectsCountProvider = Provider<int>((ref) {
  final subjects = ref.watch(subjectsProvider);
  return subjects.length;
});

final sectionsCountProvider = Provider<int>((ref) {
  final sections = ref.watch(sectionsProvider);
  return sections.length;
});

// --- Registration Links ---
final regLinksProvider =
    NotifierProvider<RegLinksNotifier, List<Map<String, dynamic>>>(() {
      return RegLinksNotifier();
    });

class RegLinksNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    _loadLinks();
    return [];
  }

  Future<void> _loadLinks() async {
    final db = await DatabaseHelper().database;
    final List<Map<String, dynamic>> maps = await db.query(
      'reg_links',
      orderBy: 'created_at DESC',
    );
    if (!ref.mounted) return;
    state = maps;
  }

  Future<void> addLink(Map<String, dynamic> link) async {
    final db = await DatabaseHelper().database;
    await db.insert('reg_links', link);
    await _loadLinks();
  }

  Future<void> deleteLink(String code) async {
    final db = await DatabaseHelper().database;
    await db.delete('reg_links', where: 'code = ?', whereArgs: [code]);
    await _loadLinks();
  }
}

// --- Subject Detail Hierarchy ---
final subjectDetailProvider =
    NotifierProvider<SubjectDetailNotifier, List<Map<String, dynamic>>>(() {
      return SubjectDetailNotifier();
    });

class SubjectDetailNotifier extends Notifier<List<Map<String, dynamic>>> {
  int? _subjectId;

  @override
  List<Map<String, dynamic>> build() {
    return [];
  }

  Future<void> loadHierarchy(int subjectId, {bool syncCloud = true}) async {
    _subjectId = subjectId;
    final db = await DatabaseHelper().database;

    final rawTopics = await db.query(
      'topics',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'id ASC',
    );

    // Auto-clean & deduplicate topic rows in local SQLite if any duplicates exist
    final seenTitles = <String, int>{};
    final topics = <Map<String, dynamic>>[];
    for (var topic in rawTopics) {
      final cleanTitle = (topic['title']?.toString() ?? '')
          .trim()
          .toLowerCase();
      final topicId = topic['id'] as int;
      if (cleanTitle.isNotEmpty && seenTitles.containsKey(cleanTitle)) {
        final primaryTopicId = seenTitles[cleanTitle]!;
        await db.update(
          'learning_outcomes',
          {'topic_id': primaryTopicId},
          where: 'topic_id = ?',
          whereArgs: [topicId],
        );
        await db.delete('topics', where: 'id = ?', whereArgs: [topicId]);
        continue;
      }
      if (cleanTitle.isNotEmpty) {
        seenTitles[cleanTitle] = topicId;
      }
      topics.add(topic);
    }

    List<Map<String, dynamic>> fullTopics = [];
    for (var topic in topics) {
      final topicId = topic['id'] as int;
      final rawLos = await db.query(
        'learning_outcomes',
        where: 'topic_id = ?',
        whereArgs: [topicId],
        orderBy: 'id ASC',
      );

      // Auto-clean duplicate learning outcomes
      final seenLoTitles = <String, int>{};
      final los = <Map<String, dynamic>>[];
      for (var lo in rawLos) {
        final cleanLoTitle = (lo['title']?.toString() ?? '')
            .trim()
            .toLowerCase();
        final loId = lo['id'] as int;
        if (cleanLoTitle.isNotEmpty && seenLoTitles.containsKey(cleanLoTitle)) {
          final primaryLoId = seenLoTitles[cleanLoTitle]!;
          await db.update(
            'contents',
            {'lo_id': primaryLoId},
            where: 'lo_id = ?',
            whereArgs: [loId],
          );
          await db.update(
            'questions',
            {'lo_id': primaryLoId},
            where: 'lo_id = ?',
            whereArgs: [loId],
          );
          await db.delete(
            'learning_outcomes',
            where: 'id = ?',
            whereArgs: [loId],
          );
          continue;
        }
        if (cleanLoTitle.isNotEmpty) {
          seenLoTitles[cleanLoTitle] = loId;
        }
        los.add(lo);
      }

      List<Map<String, dynamic>> fullLos = [];
      for (var lo in los) {
        final loId = lo['id'] as int;
        final contents = await db.query(
          'contents',
          where: 'lo_id = ?',
          whereArgs: [loId],
          orderBy: 'id ASC',
        );
        final questions = await db.query(
          'questions',
          where: 'lo_id = ?',
          whereArgs: [loId],
          orderBy: 'id ASC',
        );
        fullLos.add({...lo, 'contents': contents, 'questions': questions});
      }

      fullTopics.add({...topic, 'learning_outcomes': fullLos});
    }

    state = fullTopics;

    // Cache-and-Network (Option B): Fetch latest from Cloud Firestore in background and update
    if (syncCloud) {
      unawaited(() async {
        try {
          await DatabaseHelper().syncCloudCurriculumToLocal(force: true);
          if (_subjectId == subjectId) {
            await loadHierarchy(subjectId, syncCloud: false);
          }
        } catch (_) {}
      }());
    }
  }

  // Topics
  Future<void> addTopic(Map<String, dynamic> topic) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    final title = topic['title']?.toString().trim() ?? '';
    if (title.isEmpty) return;

    // Guard against duplicate topic creation
    final existing = await db.query(
      'topics',
      where: 'subject_id = ? AND LOWER(TRIM(title)) = ?',
      whereArgs: [_subjectId, title.toLowerCase()],
    );
    if (existing.isNotEmpty) {
      final existingId = existing.first['id'] as int;
      await db.update(
        'topics',
        {'title': title, 'description': topic['description']},
        where: 'id = ?',
        whereArgs: [existingId],
      );
      await loadHierarchy(_subjectId!, syncCloud: false);
      unawaited(
        DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
      );
      return;
    }

    topic['subject_id'] = _subjectId;
    topic['title'] = title;
    topic['created_at'] = DateTime.now().toIso8601String();
    await db.insert('topics', topic);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  Future<void> updateTopic(int topicId, Map<String, dynamic> data) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update('topics', data, where: 'id = ?', whereArgs: [topicId]);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  Future<void> deleteTopic(int topicId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('topics', where: 'id = ?', whereArgs: [topicId]);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  // Learning Outcomes
  Future<void> addLearningOutcome(int topicId, Map<String, dynamic> lo) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    lo['topic_id'] = topicId;
    lo['created_at'] = DateTime.now().toIso8601String();
    await db.insert('learning_outcomes', lo);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  Future<void> updateLearningOutcome(
    int loId,
    Map<String, dynamic> data,
  ) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update(
      'learning_outcomes',
      data,
      where: 'id = ?',
      whereArgs: [loId],
    );
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  Future<void> deleteLearningOutcome(int loId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('learning_outcomes', where: 'id = ?', whereArgs: [loId]);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  // Contents
  Future<void> addContent(
    int loId,
    Map<String, dynamic> content, {
    int? subjectId,
  }) async {
    final db = await DatabaseHelper().database;
    content['lo_id'] = loId;
    content['created_at'] = DateTime.now().toIso8601String();
    await db.insert('contents', content);

    int? targetSubId = subjectId ?? _subjectId;
    if (targetSubId == null) {
      try {
        final loRows = await db.query(
          'learning_outcomes',
          where: 'id = ?',
          whereArgs: [loId],
        );
        if (loRows.isNotEmpty) {
          final tId = loRows.first['topic_id'] as int?;
          if (tId != null) {
            final tRows = await db.query(
              'topics',
              where: 'id = ?',
              whereArgs: [tId],
            );
            if (tRows.isNotEmpty) {
              targetSubId = tRows.first['subject_id'] as int?;
            }
          }
        }
      } catch (_) {}
    }

    if (targetSubId != null) {
      _subjectId = targetSubId;
      await loadHierarchy(targetSubId, syncCloud: false);
      await DatabaseHelper().pushLocalCurriculumToCloud(subjectId: targetSubId);
    }
  }

  Future<void> updateContent(
    int contentId,
    Map<String, dynamic> data, {
    int? subjectId,
  }) async {
    final db = await DatabaseHelper().database;
    await db.update('contents', data, where: 'id = ?', whereArgs: [contentId]);

    int? targetSubId = subjectId ?? _subjectId;
    if (targetSubId == null) {
      try {
        final cRows = await db.query(
          'contents',
          where: 'id = ?',
          whereArgs: [contentId],
        );
        if (cRows.isNotEmpty) {
          final loId = cRows.first['lo_id'] as int?;
          if (loId != null) {
            final loRows = await db.query(
              'learning_outcomes',
              where: 'id = ?',
              whereArgs: [loId],
            );
            if (loRows.isNotEmpty) {
              final tId = loRows.first['topic_id'] as int?;
              if (tId != null) {
                final tRows = await db.query(
                  'topics',
                  where: 'id = ?',
                  whereArgs: [tId],
                );
                if (tRows.isNotEmpty)
                  targetSubId = tRows.first['subject_id'] as int?;
              }
            }
          }
        }
      } catch (_) {}
    }

    if (targetSubId != null) {
      _subjectId = targetSubId;
      await loadHierarchy(targetSubId, syncCloud: false);
      await DatabaseHelper().pushLocalCurriculumToCloud(subjectId: targetSubId);
    }
  }

  Future<void> deleteContent(int contentId, {int? subjectId}) async {
    final db = await DatabaseHelper().database;
    int? targetSubId = subjectId ?? _subjectId;
    if (targetSubId == null) {
      try {
        final cRows = await db.query(
          'contents',
          where: 'id = ?',
          whereArgs: [contentId],
        );
        if (cRows.isNotEmpty) {
          final loId = cRows.first['lo_id'] as int?;
          if (loId != null) {
            final loRows = await db.query(
              'learning_outcomes',
              where: 'id = ?',
              whereArgs: [loId],
            );
            if (loRows.isNotEmpty) {
              final tId = loRows.first['topic_id'] as int?;
              if (tId != null) {
                final tRows = await db.query(
                  'topics',
                  where: 'id = ?',
                  whereArgs: [tId],
                );
                if (tRows.isNotEmpty)
                  targetSubId = tRows.first['subject_id'] as int?;
              }
            }
          }
        }
      } catch (_) {}
    }

    await db.delete('contents', where: 'id = ?', whereArgs: [contentId]);
    if (targetSubId != null) {
      _subjectId = targetSubId;
      await loadHierarchy(targetSubId, syncCloud: false);
      await DatabaseHelper().pushLocalCurriculumToCloud(subjectId: targetSubId);
    }
  }

  // Questions
  Future<void> addQuestion(int loId, Map<String, dynamic> question) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    question['lo_id'] = loId;
    question['created_at'] = DateTime.now().toIso8601String();
    await db.insert('questions', question);
    await loadHierarchy(_subjectId!, syncCloud: false);
    unawaited(
      DatabaseHelper().pushLocalCurriculumToCloud(subjectId: _subjectId),
    );
  }

  Future<void> updateQuestion(
    int questionId,
    Map<String, dynamic> question,
  ) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.update(
      'questions',
      question,
      where: 'id = ?',
      whereArgs: [questionId],
    );
    await loadHierarchy(_subjectId!);
  }

  Future<void> deleteQuestion(int questionId) async {
    if (_subjectId == null) return;
    final db = await DatabaseHelper().database;
    await db.delete('questions', where: 'id = ?', whereArgs: [questionId]);
    await loadHierarchy(_subjectId!);
  }
}

// --- Admin Web Analytics Model & Filter ---
class AnalyticsFilter {
  final int? subjectId;
  final String? subjectName;
  final String? section;
  final String timeframe; // 'all', 'today', '7days', '30days', 'this_month'
  final String
  category; // 'all', 'regular', 'irregular', 'transferee', 'sped', 'unassigned'

  final String academicYear;
  final String departmentGradeLevel;

  const AnalyticsFilter({
    this.subjectId,
    this.subjectName,
    this.section,
    this.timeframe = 'all',
    this.category = 'all',
    this.academicYear = 'AY 2025-2026',
    this.departmentGradeLevel = 'All Levels',
  });

  bool get hasActiveFilters =>
      subjectId != null ||
      (section != null && section != 'All Sections' && section!.isNotEmpty) ||
      timeframe != 'all' ||
      category != 'all' ||
      academicYear != 'AY 2025-2026' ||
      departmentGradeLevel != 'All Levels';

  int get activeFilterCount {
    int count = 0;
    if (subjectId != null) count++;
    if (section != null && section != 'All Sections' && section!.isNotEmpty) {
      count++;
    }
    if (timeframe != 'all') count++;
    if (category != 'all') count++;
    if (academicYear != 'AY 2025-2026') count++;
    if (departmentGradeLevel != 'All Levels') count++;
    return count;
  }

  AnalyticsFilter copyWith({
    int? subjectId,
    bool clearSubject = false,
    String? subjectName,
    String? section,
    bool clearSection = false,
    String? timeframe,
    String? category,
    String? academicYear,
    String? departmentGradeLevel,
  }) {
    return AnalyticsFilter(
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      subjectName: clearSubject ? null : (subjectName ?? this.subjectName),
      section: clearSection ? null : (section ?? this.section),
      timeframe: timeframe ?? this.timeframe,
      category: category ?? this.category,
      academicYear: academicYear ?? this.academicYear,
      departmentGradeLevel: departmentGradeLevel ?? this.departmentGradeLevel,
    );
  }
}

final analyticsFilterProvider =
    NotifierProvider<AnalyticsFilterNotifier, AnalyticsFilter>(() {
      return AnalyticsFilterNotifier();
    });

class AnalyticsFilterNotifier extends Notifier<AnalyticsFilter> {
  @override
  AnalyticsFilter build() => const AnalyticsFilter();

  void setFilter(AnalyticsFilter filter) {
    state = filter;
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics(filter: filter);
  }

  void updateSubject(int? id, String? name) {
    final next = state.copyWith(
      subjectId: id,
      subjectName: name,
      clearSubject: id == null,
    );
    setFilter(next);
  }

  void updateSection(String? sec) {
    final next = state.copyWith(
      section: sec,
      clearSection: sec == null || sec == 'All Sections',
    );
    setFilter(next);
  }

  void updateTimeframe(String tf) {
    final next = state.copyWith(timeframe: tf);
    setFilter(next);
  }

  void updateCategory(String cat) {
    final next = state.copyWith(category: cat);
    setFilter(next);
  }

  void updateAcademicYear(String year) {
    final next = state.copyWith(academicYear: year);
    setFilter(next);
  }

  void updateDepartmentGradeLevel(String dept) {
    final next = state.copyWith(departmentGradeLevel: dept);
    setFilter(next);
  }

  void reset() {
    const defaultFilter = AnalyticsFilter();
    state = defaultFilter;
    ref
        .read(adminAnalyticsProvider.notifier)
        .loadAnalytics(filter: defaultFilter);
  }
}

// --- Admin Web Analytics Provider ---
final adminAnalyticsProvider =
    NotifierProvider<AdminAnalyticsNotifier, Map<String, dynamic>>(() {
      return AdminAnalyticsNotifier();
    });

class AdminAnalyticsNotifier extends Notifier<Map<String, dynamic>> {
  AnalyticsFilter _currentFilter = const AnalyticsFilter();
  VoidCallback? _syncListener;

  @override
  Map<String, dynamic> build() {
    ref.onDispose(() {
      if (_syncListener != null) {
        FirestoreService.removeSyncListener(_syncListener!);
      }
    });

    _syncListener = () {
      if (ref.mounted) {
        loadAnalytics(syncCloud: false);
      }
    };
    FirestoreService.addSyncListener(_syncListener!);

    loadAnalytics();

    // Auto-pull users if local summary is empty or only has the self admin
    Future.microtask(() async {
      try {
        final summary = await DatabaseHelper().getAdminAnalyticsSummary();
        final usersCount = summary['totalUsers'] as int? ?? 0;
        final studentsCount = summary['totalStudents'] as int? ?? 0;
        final teachersCount = summary['totalTeachers'] as int? ?? 0;
        if (usersCount <= 1 ||
            (studentsCount == 0 && teachersCount == 0) ||
            kIsWeb) {
          await FirestoreService().syncCloudUsersToLocal(force: true);
          await FirestoreService().syncCloudSubjectsToLocal(force: true);
          await FirestoreService().syncCloudSectionsToLocal(force: true);
          if (ref.mounted) {
            await loadAnalytics(syncCloud: false);
          }
        }
      } catch (_) {}
    });

    return {
      'totalUsers': 0,
      'totalStudents': 0,
      'totalTeachers': 0,
      'totalAdmins': 0,
      'totalEnrollments': 0,
      'totalSubjects': 0,
      'totalTopics': 0,
      'totalLos': 0,
      'totalAttempts': 0,
      'passedAttempts': 0,
      'passRate': 0,
      'avgScore': 0,
      'subjectEnrollments': <Map<String, dynamic>>[],
      'sectionDistribution': <Map<String, dynamic>>[],
      'recentAnnouncements': <Map<String, dynamic>>[],
      'recentAttempts': <Map<String, dynamic>>[],
      'hasData': true,
    };
  }

  Future<void> loadAnalytics({
    AnalyticsFilter? filter,
    bool syncCloud = false,
  }) async {
    if (filter != null) {
      _currentFilter = filter;
    }
    if (syncCloud) {
      try {
        await FirestoreService().syncCloudUsersToLocal(force: true);
        await FirestoreService().syncCloudSubjectsToLocal(force: true);
        await FirestoreService().syncCloudSectionsToLocal(force: true);
        ref.read(subjectsProvider.notifier).reload();
        ref.read(sectionsProvider.notifier).reload();
      } catch (_) {}
    }
    final summary = await DatabaseHelper().getAdminAnalyticsSummary(
      subjectId: _currentFilter.subjectId,
      section: _currentFilter.section,
      timeframe: _currentFilter.timeframe,
      studentCategory: _currentFilter.category,
      academicYear: _currentFilter.academicYear,
      departmentGradeLevel: _currentFilter.departmentGradeLevel,
    );
    if (!ref.mounted) return;
    state = summary;
  }
}

// --- Admin Students Provider ---
final adminStudentsProvider =
    NotifierProvider<AdminStudentsNotifier, List<Map<String, dynamic>>>(() {
      return AdminStudentsNotifier();
    });

class AdminStudentsNotifier extends Notifier<List<Map<String, dynamic>>> {
  String _selectedSection = 'All';
  String _selectedGrade = 'All';
  String _searchQuery = '';
  VoidCallback? _syncListener;

  @override
  List<Map<String, dynamic>> build() {
    ref.onDispose(() {
      if (_syncListener != null) {
        FirestoreService.removeSyncListener(_syncListener!);
      }
    });

    _syncListener = () async {
      if (ref.mounted) {
        final fresh = await DatabaseHelper().getAdminStudentsList(
          section: _selectedSection,
          grade: _selectedGrade,
          query: _searchQuery,
        );
        if (ref.mounted) state = fresh;
      }
    };
    FirestoreService.addSyncListener(_syncListener!);

    loadStudents();
    return [];
  }

  Future<void> loadStudents({
    String? section,
    String? grade,
    String? query,
    bool syncCloud = true,
  }) async {
    if (section != null) _selectedSection = section;
    if (grade != null) _selectedGrade = grade;
    if (query != null) _searchQuery = query;

    final results = await DatabaseHelper().getAdminStudentsList(
      section: _selectedSection,
      grade: _selectedGrade,
      query: _searchQuery,
    );
    if (!ref.mounted) return;
    state = results;

    // Non-blocking background cloud freshness pull (only on initial/unfiltered load when syncCloud is requested)
    if (syncCloud && (query == null || query.isEmpty)) {
      final shouldForce = results.isEmpty;
      FirestoreService()
          .syncCloudUsersToLocal(force: shouldForce)
          .then((_) async {
            if (!ref.mounted) return;
            final fresh = await DatabaseHelper().getAdminStudentsList(
              section: _selectedSection,
              grade: _selectedGrade,
              query: _searchQuery,
            );
            if (ref.mounted) state = fresh;
          })
          .catchError((_) {});
    }
  }

  Future<String> addStudent({
    String? id,
    required String fullName,
    required String email,
    required String password,
    String? username,
    String? grade,
    String? section,
    String studentType = 'regular',
    String? specialNotes,
    List<int>? enrollSubjectIds,
  }) async {
    final sid = await DatabaseHelper().createStudent(
      id: id,
      fullName: fullName,
      email: email,
      password: password,
      username: username,
      grade: grade,
      section: section,
      studentType: studentType,
      specialNotes: specialNotes,
      enrollSubjectIds: enrollSubjectIds,
    );
    await loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
    return sid;
  }

  Future<void> reassignSection(
    String studentId,
    String newSection, {
    String? newGrade,
  }) async {
    await DatabaseHelper().updateStudentSection(
      studentId,
      newSection,
      grade: newGrade,
    );
    await loadStudents();
    ref.read(sectionsProvider.notifier).reload();
    ref.invalidate(adminTeachersProvider);
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> updateStudentClassification(
    String studentId,
    String studentType, {
    String? notes,
  }) async {
    await DatabaseHelper().updateStudentClassification(
      studentId,
      studentType,
      notes: notes,
    );
    await loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> updateStudentEnrollments(
    String studentId,
    List<int> subjectIds,
  ) async {
    await DatabaseHelper().setStudentEnrollments(studentId, subjectIds);
    await loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> archiveStudent(String studentId) async {
    await DatabaseHelper().archiveStudent(studentId);
    await loadStudents();
    ref.read(adminArchivedStudentsProvider.notifier).loadArchived();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<void> bulkArchiveStudents(
    List<String> studentIds, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().bulkArchiveStudents(
      studentIds,
      onProgress: onProgress,
    );
    await loadStudents();
    ref.read(adminArchivedStudentsProvider.notifier).loadArchived();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<void> deleteStudent(String studentId) async {
    await DatabaseHelper().deleteStudent(studentId);
    await loadStudents();
    ref.read(adminArchivedStudentsProvider.notifier).loadArchived();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<Map<String, dynamic>> bulkImportUsers(
    List<Map<String, dynamic>> rows,
  ) async {
    final result = await DatabaseHelper().bulkImportUsers(rows);
    await loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
    return result;
  }

  String exportStudentsCsv({List<Map<String, dynamic>>? studentsToExport}) {
    final list = studentsToExport ?? state;
    final headers = [
      'Full Name',
      'Email',
      'Role',
      'Grade',
      'Section',
      'Student Type',
      'Special Notes',
      'Enrolled Courses',
      'Completed Outcomes',
      'Average Score',
    ];

    final rows = list.map((s) {
      return [
        s['full_name'] ?? '',
        s['email'] ?? '',
        s['role'] ?? 'student',
        s['grade'] ?? '',
        s['section'] ?? '',
        s['student_type'] ?? 'regular',
        s['special_notes'] ?? '',
        s['enrolled_courses']?.toString() ?? '0',
        s['completed_los']?.toString() ?? '0',
        '${s['avg_score'] ?? 0}%',
      ];
    }).toList();

    return CsvHelper.generate(headers: headers, rows: rows);
  }
}

// --- Admin Enrollment Keys Provider ---
final adminKeysProvider =
    NotifierProvider<AdminKeysNotifier, List<Map<String, dynamic>>>(() {
      return AdminKeysNotifier();
    });

class AdminKeysNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadKeys();
    return [];
  }

  Future<void> loadKeys() async {
    final db = await DatabaseHelper().database;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    final deletedSections =
        prefs?.getStringList('permanently_deleted_sections') ?? [];

    final lastFetch = prefs?.getInt('last_cloud_fetch_keys') ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isStale = (nowMs - lastFetch) > 5 * 60 * 1000;

    if (isStale) {
      try {
        final cloudKeys = await FirestoreService().fetchAllDocuments(
          'enrollment_keys',
        );
        if (cloudKeys.isNotEmpty) {
          try {
            await prefs?.setInt('last_cloud_fetch_keys', nowMs);
          } catch (_) {}
          for (final k in cloudKeys) {
            final code =
                k['code']?.toString().toUpperCase() ??
                k['id']?.toString().toUpperCase() ??
                '';
            final sec = k['section']?.toString() ?? '';
            if (deletedSections.contains(code) ||
                deletedSections.contains(sec)) {
              continue;
            }
            if (code.isNotEmpty) {
              await db.insert('reg_links', {
                'code': code,
                'section': sec,
                'max_uses':
                    int.tryParse(k['max_uses']?.toString() ?? '50') ?? 50,
                'used_count':
                    int.tryParse(k['used_count']?.toString() ?? '0') ?? 0,
                'expiration': k['expiration']?.toString() ?? '2026-12-31',
                'created_at':
                    k['created_at']?.toString() ??
                    DateTime.now().toIso8601String(),
              }, conflictAlgorithm: ConflictAlgorithm.replace);
            }
          }
        }
      } catch (e) {
        debugPrint('[AdminKeysNotifier] Cloud loadKeys note: $e');
      }
    }

    final keys = await DatabaseHelper().getEnrollmentKeysList();
    if (!ref.mounted) return;
    state = keys;

    // Asynchronously ensure Firestore has accurate used_count
    for (final k in keys) {
      final code = k['code']?.toString();
      final used = k['used_count'] as int? ?? 0;
      if (code != null && code.isNotEmpty && used > 0) {
        FirestoreService()
            .saveDocument('enrollment_keys', code, {'used_count': used})
            .catchError((_) {});
      }
    }
  }

  Future<void> createKey({
    required String code,
    required String section,
    int maxUses = 50,
    String? expiration,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    await DatabaseHelper().generateEnrollmentKey(
      code: cleanCode,
      section: section,
      maxUses: maxUses,
      expiration: expiration,
    );

    // Save directly to Cloud Firestore!
    await FirestoreService().saveDocument('enrollment_keys', cleanCode, {
      'code': cleanCode,
      'section': section,
      'max_uses': maxUses,
      'used_count': 0,
      'expiration': expiration ?? '2026-12-31',
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_cloud_fetch_keys');
      final deleted = prefs.getStringList('permanently_deleted_sections') ?? [];
      if (deleted.contains(cleanCode)) {
        deleted.remove(cleanCode);
        await prefs.setStringList('permanently_deleted_sections', deleted);
      }
    } catch (_) {}

    await loadKeys();
  }

  Future<void> deleteKey(String code) async {
    final cleanCode = code.trim().toUpperCase();
    await DatabaseHelper().deleteEnrollmentKey(cleanCode);
    await FirestoreService().deleteDocument('enrollment_keys', cleanCode);
    await FirestoreService().deleteDocument('reg_links', cleanCode);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_cloud_fetch_keys');
      final deleted = prefs.getStringList('permanently_deleted_sections') ?? [];
      if (!deleted.contains(cleanCode)) {
        deleted.add(cleanCode);
        await prefs.setStringList('permanently_deleted_sections', deleted);
      }
    } catch (_) {}

    await loadKeys();
  }
}

// --- Available Sections Provider ---
final availableSectionsProvider = FutureProvider<List<String>>((ref) async {
  ref.watch(sectionsProvider);
  var list = await DatabaseHelper().getAvailableSectionsList();
  if (list.isEmpty) {
    await FirestoreService().syncCloudSectionsToLocal(force: true);
    list = await DatabaseHelper().getAvailableSectionsList();
  }
  return list;
});

// --- Admin Archived Students Provider ---
final adminArchivedStudentsProvider =
    NotifierProvider<AdminArchivedStudentsNotifier, List<Map<String, dynamic>>>(
      () {
        return AdminArchivedStudentsNotifier();
      },
    );

class AdminArchivedStudentsNotifier
    extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadArchived();
    return [];
  }

  Future<void> loadArchived() async {
    final results = await DatabaseHelper().getArchivedStudentsList();
    if (!ref.mounted) return;
    state = results;
  }

  Future<void> restoreStudent(String studentId) async {
    await DatabaseHelper().restoreStudent(studentId);
    await loadArchived();
    ref.read(adminStudentsProvider.notifier).loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<void> bulkRestoreStudents(List<String> studentIds) async {
    await DatabaseHelper().bulkRestoreStudents(studentIds);
    await loadArchived();
    ref.read(adminStudentsProvider.notifier).loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<void> permanentDeleteStudent(
    String studentId, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().deleteStudent(studentId, onProgress: onProgress);
    await loadArchived();
    ref.read(adminStudentsProvider.notifier).loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }

  Future<void> bulkPermanentDeleteStudents(
    List<String> studentIds, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().bulkPermanentDeleteStudents(
      studentIds,
      onProgress: onProgress,
    );
    await loadArchived();
    ref.read(adminStudentsProvider.notifier).loadStudents();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    ref.read(sectionsProvider.notifier).reload();
  }
}

// --- Admin Faculty / Teachers Provider ---
final adminTeachersProvider =
    NotifierProvider<AdminTeachersNotifier, List<Map<String, dynamic>>>(() {
      return AdminTeachersNotifier();
    });

class AdminTeachersNotifier extends Notifier<List<Map<String, dynamic>>> {
  VoidCallback? _syncListener;

  @override
  List<Map<String, dynamic>> build() {
    ref.onDispose(() {
      if (_syncListener != null) {
        FirestoreService.removeSyncListener(_syncListener!);
      }
    });

    _syncListener = () async {
      if (ref.mounted) {
        final fresh = await DatabaseHelper().getTeachersList();
        if (ref.mounted) state = fresh;
        ref.invalidate(teachersListProvider);
      }
    };
    FirestoreService.addSyncListener(_syncListener!);

    loadTeachers();
    return [];
  }

  Future<void> loadTeachers({bool syncCloud = true}) async {
    final teachers = await DatabaseHelper().getTeachersList();
    if (!ref.mounted) return;
    state = teachers;

    final shouldForce = teachers.isEmpty;
    // Non-blocking background cloud freshness pull
    if (syncCloud) {
      FirestoreService()
          .syncCloudUsersToLocal(force: shouldForce)
          .then((_) async {
            if (!ref.mounted) return;
            final fresh = await DatabaseHelper().getTeachersList();
            if (ref.mounted) state = fresh;
            ref.invalidate(teachersListProvider);
          })
          .catchError((_) {});
    }
  }

  Future<String> addTeacher({
    String? id,
    required String fullName,
    required String email,
    required String password,
    String? username,
    List<int>? assignSubjectIds,
  }) async {
    final tid = await DatabaseHelper().createTeacher(
      id: id,
      fullName: fullName,
      email: email,
      password: password,
      username: username,
      assignSubjectIds: assignSubjectIds,
    );
    await loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
    return tid;
  }

  Future<void> updateTeacher(
    String teacherId,
    Map<String, dynamic> data, {
    List<int>? assignSubjectIds,
  }) async {
    await DatabaseHelper().updateTeacher(
      teacherId,
      data,
      assignSubjectIds: assignSubjectIds,
    );
    await loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
    ref.read(sectionsProvider.notifier).reload();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> deleteTeacher(String teacherId) async {
    await DatabaseHelper().deleteTeacher(teacherId);
    await loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<void> archiveTeacher(String teacherId) async {
    await DatabaseHelper().archiveTeacher(teacherId);
    await loadTeachers();
    ref.read(adminArchivedTeachersProvider.notifier).loadArchivedTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<void> bulkArchiveTeachers(
    List<String> teacherIds, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().bulkArchiveTeachers(
      teacherIds,
      onProgress: onProgress,
    );
    await loadTeachers();
    ref.read(adminArchivedTeachersProvider.notifier).loadArchivedTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<Map<String, dynamic>> bulkImportTeachers(
    List<Map<String, dynamic>> teachersToImport, {
    String? defaultPassword,
  }) async {
    final result = await DatabaseHelper().bulkImportTeachers(
      teachersToImport,
      defaultPassword: defaultPassword,
    );
    await loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
    return result;
  }
}

// --- Admin Archived Faculty / Teachers Provider ---
final adminArchivedTeachersProvider =
    NotifierProvider<AdminArchivedTeachersNotifier, List<Map<String, dynamic>>>(
      () {
        return AdminArchivedTeachersNotifier();
      },
    );

class AdminArchivedTeachersNotifier
    extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadArchivedTeachers();
    return [];
  }

  Future<void> loadArchivedTeachers() async {
    final archived = await DatabaseHelper().getArchivedTeachersList();
    if (!ref.mounted) return;
    state = archived;
  }

  Future<void> restoreTeacher(String teacherId) async {
    await DatabaseHelper().restoreTeacher(teacherId);
    await loadArchivedTeachers();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<void> bulkRestoreTeachers(List<String> teacherIds) async {
    await DatabaseHelper().bulkRestoreTeachers(teacherIds);
    await loadArchivedTeachers();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<void> permanentDeleteTeacher(
    String teacherId, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().deleteTeacher(teacherId, onProgress: onProgress);
    await loadArchivedTeachers();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }

  Future<void> bulkPermanentDeleteTeachers(
    List<String> teacherIds, {
    void Function(double progress, String statusMessage)? onProgress,
  }) async {
    await DatabaseHelper().bulkPermanentDeleteTeachers(
      teacherIds,
      onProgress: onProgress,
    );
    await loadArchivedTeachers();
    ref.read(adminTeachersProvider.notifier).loadTeachers();
    ref.read(subjectsProvider.notifier).reload();
  }
}

// --- School Administrators Provider (Super Admin Console) ---
final schoolAdminsProvider =
    NotifierProvider<SchoolAdminsNotifier, List<Map<String, dynamic>>>(() {
      return SchoolAdminsNotifier();
    });

class SchoolAdminsNotifier extends Notifier<List<Map<String, dynamic>>> {
  String? _selectedSchoolId;
  String _searchQuery = '';

  @override
  List<Map<String, dynamic>> build() {
    loadAdmins();
    return [];
  }

  Future<void> loadAdmins({String? schoolId, String? query}) async {
    if (schoolId != null) _selectedSchoolId = schoolId;
    if (query != null) _searchQuery = query;

    final admins = await DatabaseHelper().getAdminsList(
      schoolId: _selectedSchoolId,
      query: _searchQuery,
    );
    if (!ref.mounted) return;
    state = admins;

    // Non-blocking background cloud freshness pull (only on initial/unfiltered load)
    if (query == null || query.isEmpty) {
      FirestoreService()
          .syncCloudUsersToLocal()
          .then((_) async {
            if (!ref.mounted) return;
            final fresh = await DatabaseHelper().getAdminsList(
              schoolId: _selectedSchoolId,
              query: _searchQuery,
            );
            if (ref.mounted) state = fresh;
          })
          .catchError((_) {});
    }
  }

  Future<String> addAdmin({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String role = 'admin',
    String? schoolId = 'sch_main',
  }) async {
    final aid = await DatabaseHelper().createAdmin(
      fullName: fullName,
      email: email,
      password: password,
      username: username,
      role: role,
      schoolId: schoolId,
    );
    await loadAdmins();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
    return aid;
  }

  Future<void> updateAdmin(String adminId, Map<String, dynamic> data) async {
    await DatabaseHelper().updateAdmin(adminId, data);
    await loadAdmins();
  }

  Future<void> archiveAdmin(String adminId) async {
    await DatabaseHelper().archiveAdmin(adminId);
    await loadAdmins();
    ref.read(archivedSchoolAdminsProvider.notifier).loadArchivedAdmins();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> deleteAdmin(String adminId) async {
    await DatabaseHelper().deleteAdmin(adminId);
    await loadAdmins();
    ref.read(archivedSchoolAdminsProvider.notifier).loadArchivedAdmins();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<EmailResult> resendCredentials(
    String adminId, {
    String? newPassword,
  }) async {
    final result = await DatabaseHelper().resetAndSendAdminCredentials(
      adminId: adminId,
      newPassword: newPassword,
    );
    await loadAdmins();
    return result;
  }
}

// --- Archived / Deactivated School Administrators Provider ---
final archivedSchoolAdminsProvider =
    NotifierProvider<ArchivedSchoolAdminsNotifier, List<Map<String, dynamic>>>(
      () {
        return ArchivedSchoolAdminsNotifier();
      },
    );

class ArchivedSchoolAdminsNotifier
    extends Notifier<List<Map<String, dynamic>>> {
  String? _selectedSchoolId;
  String _searchQuery = '';

  @override
  List<Map<String, dynamic>> build() {
    loadArchivedAdmins();
    return [];
  }

  Future<void> loadArchivedAdmins({String? schoolId, String? query}) async {
    if (schoolId != null) _selectedSchoolId = schoolId;
    if (query != null) _searchQuery = query;

    final admins = await DatabaseHelper().getArchivedAdminsList(
      schoolId: _selectedSchoolId,
      query: _searchQuery,
    );
    if (!ref.mounted) return;
    state = admins;

    // Non-blocking background cloud freshness pull (only on initial/unfiltered load)
    if (query == null || query.isEmpty) {
      FirestoreService()
          .syncCloudUsersToLocal()
          .then((_) async {
            if (!ref.mounted) return;
            final fresh = await DatabaseHelper().getArchivedAdminsList(
              schoolId: _selectedSchoolId,
              query: _searchQuery,
            );
            if (ref.mounted) state = fresh;
          })
          .catchError((_) {});
    }
  }

  Future<void> restoreAdmin(String adminId) async {
    await DatabaseHelper().restoreAdmin(adminId);
    await loadArchivedAdmins();
    ref.read(schoolAdminsProvider.notifier).loadAdmins();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }

  Future<void> permanentDeleteAdmin(String adminId) async {
    await DatabaseHelper().deleteAdmin(adminId);
    await loadArchivedAdmins();
    ref.read(adminAnalyticsProvider.notifier).loadAnalytics();
  }
}

// --- Schools Management (Item 8: Super Admin manages schools) ---
class SchoolsNotifier extends Notifier<List<Map<String, dynamic>>> {
  @override
  List<Map<String, dynamic>> build() {
    loadSchools();
    return [];
  }

  Future<void> loadSchools() async {
    final list = await DatabaseHelper().getSchoolsList();
    if (!ref.mounted) return;
    state = list;
  }

  Future<String> addSchool({
    required String name,
    required String code,
    String? address,
    String? adminId,
    String status = 'active',
  }) async {
    final id = await DatabaseHelper().createSchool(
      name: name.trim(),
      code: code.trim().toUpperCase(),
      address: address?.trim(),
      adminId: adminId,
    );
    if (adminId != null && adminId.isNotEmpty) {
      await DatabaseHelper().assignSchoolAdmin(id, adminId);
    }
    await loadSchools();
    return id;
  }

  Future<void> updateSchool({
    required String id,
    required String name,
    required String code,
    String? address,
    String? adminId,
    required String status,
  }) async {
    await DatabaseHelper().updateSchool(id, {
      'name': name.trim(),
      'code': code.trim().toUpperCase(),
      'address': address?.trim(),
      'admin_id': adminId,
      'status': status,
    });
    if (adminId != null && adminId.isNotEmpty) {
      await DatabaseHelper().assignSchoolAdmin(id, adminId);
    }
    await loadSchools();
  }

  Future<void> deleteSchool(String id) async {
    await DatabaseHelper().deleteSchool(id);
    await loadSchools();
  }
}

final schoolsListProvider =
    NotifierProvider<SchoolsNotifier, List<Map<String, dynamic>>>(() {
      return SchoolsNotifier();
    });

// Backward-compatible AsyncValue provider
final schoolsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(schoolsListProvider);
});

// Selected school scope filter for Super Admin (null means all schools)
class SuperAdminCampusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  @override
  set state(String? val) => super.state = val;
}

final superAdminSelectedSchoolProvider =
    NotifierProvider<SuperAdminCampusFilterNotifier, String?>(() {
      return SuperAdminCampusFilterNotifier();
    });
