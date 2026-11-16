import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_helper.dart';

/// Centralized service connecting AIRA with Supabase PostgreSQL & Realtime.
/// Solves the Firebase Firestore daily quota limitations with unlimited reads/writes
/// and built-in WebSocket subscriptions.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  static SupabaseService get instance => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://rwwbqcadfsevazgquier.supabase.co';
  static const String supabasePublishableKey = 'sb_publishable_YdkBZMTJZPEsB6rJM3bpQg_-rJf4zMw';

  /// Whether Supabase has been initialized in this application lifecycle
  bool get isInitialized {
    try {
      final _ = Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get client {
    if (!isInitialized) return null;
    return Supabase.instance.client;
  }

  /// Check connectivity to Supabase
  Future<bool> checkConnection() async {
    if (!isInitialized) return false;
    try {
      final res = await client!.from('users').select('id').limit(1);
      debugPrint('[SupabaseService] Connection check OK: $res');
      return true;
    } catch (e) {
      debugPrint('[SupabaseService] Connection check failed: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ── 1. USERS & PROFILES ─────────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchUsers() async {
    if (!isInitialized) return [];
    try {
      final data = await client!.from('users').select().order('created_at');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchUsers error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> fetchUserById(String id) async {
    if (!isInitialized) return null;
    try {
      final data = await client!.from('users').select().eq('id', id).maybeSingle();
      return data;
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserById error: $e');
      return null;
    }
  }

  Future<void> upsertUser(Map<String, dynamic> userData) async {
    if (!isInitialized) return;
    try {
      await client!.from('users').upsert(userData, onConflict: 'id');
    } catch (e) {
      debugPrint('[SupabaseService] upsertUser error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ── 2. SECTIONS & SUBJECTS ──────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchSections() async {
    if (!isInitialized) return [];
    try {
      final data = await client!.from('sections').select().order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchSections error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllSubjects() async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('subjects')
          .select()
          .order('id');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchAllSubjects error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubjects(String sectionId) async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('subjects')
          .select()
          .eq('section_id', sectionId)
          .order('name');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchSubjects error: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ── 3. ANNOUNCEMENTS & REALTIME ─────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchAnnouncements(String sectionId) async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('announcements')
          .select()
          .eq('section_id', sectionId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchAnnouncements error: $e');
      return [];
    }
  }

  Stream<List<Map<String, dynamic>>> streamAnnouncements(String sectionId) {
    if (!isInitialized) return const Stream.empty();
    return client!
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('section_id', sectionId)
        .order('created_at', ascending: false);
  }

  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String sectionId,
    String? authorId,
    String? authorName,
    String? authorRole,
  }) async {
    if (!isInitialized) return;
    try {
      await client!.from('announcements').insert({
        'title': title,
        'content': content,
        'section_id': sectionId,
        'author_id': authorId,
        'author_name': authorName,
        'author_role': authorRole,
      });
    } catch (e) {
      debugPrint('[SupabaseService] createAnnouncement error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ── 4. CHAT (CONVERSATIONS & MESSAGES) ──────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> fetchUserConversations(String userId) async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('conversation_participants')
          .select('conversation_id, conversations(*)')
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchUserConversations error: $e');
      return [];
    }
  }

  /// Real-time message stream for a conversation
  Stream<List<Map<String, dynamic>>> streamMessages(String conversationId) {
    if (!isInitialized) return const Stream.empty();
    return client!
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
  }

  Stream<List<Map<String, dynamic>>> streamConversationMessages(String conversationId) {
    return streamMessages(conversationId);
  }

  /// Save / send a chat message to Supabase Realtime
  Future<void> saveChatMessage({
    required String conversationId,
    required String messageId,
    required Map<String, dynamic> data,
  }) async {
    if (!isInitialized) return;

    try {
      // 1. Ensure conversation exists in Supabase
      try {
        await client!.from('conversations').upsert({
          'id': conversationId,
          'is_group': !conversationId.startsWith('dm_'),
          'title': data['conversation_name'] ??
              (conversationId.startsWith('dm_') ? 'Direct Message' : 'Group Chat'),
        }, onConflict: 'id');
      } catch (_) {}

      // 2. Insert message with text and content
      final text = data['text']?.toString() ?? data['content']?.toString() ?? '';
      final senderId = data['sender_id']?.toString() ?? '';
      final createdAt = data['created_at']?.toString() ?? DateTime.now().toIso8601String();
      final attachmentUrl = data['attachment_url']?.toString();

      await client!.from('messages').upsert({
        'id': messageId,
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': text,
        'content': text,
        'attachment_url': attachmentUrl,
        'created_at': createdAt,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('[SupabaseService] saveChatMessage error: $e');
    }
  }

  /// Sync messages from Supabase to local SQLite
  Future<void> syncCloudMessagesForConversation(String conversationId) async {
    if (!isInitialized) return;

    try {
      final res = await client!
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      final db = DatabaseHelper();
      for (final m in res) {
        final id = m['id']?.toString() ?? '';
        final text = m['text']?.toString() ?? m['content']?.toString() ?? '';
        final senderId = m['sender_id']?.toString() ?? '';
        final createdAt = m['created_at']?.toString() ?? DateTime.now().toIso8601String();
        if (id.isNotEmpty && text.isNotEmpty) {
          await db.saveMessage({
            'id': id,
            'conversation_id': conversationId,
            'sender_id': senderId,
            'text': text,
            'created_at': createdAt,
            'is_read': 0,
          });
        }
      }
    } catch (e) {
      debugPrint('[SupabaseService] syncCloudMessagesForConversation error: $e');
    }
  }

  /// Send a chat message (convenience helper)
  Future<void> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? attachmentUrl,
  }) async {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}';
    await saveChatMessage(
      conversationId: conversationId,
      messageId: msgId,
      data: {
        'conversation_id': conversationId,
        'sender_id': senderId,
        'text': content,
        'content': content,
        'attachment_url': attachmentUrl,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // ── 5. QUIZZES & ATTEMPTS ───────────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<void> ensureSubject({
    required String id,
    required String name,
    required String code,
  }) async {
    if (!isInitialized) return;
    try {
      final existing = await client!.from('subjects').select('id').ilike('code', code).maybeSingle();
      if (existing != null) return;
      await client!.from('subjects').upsert({
        'id': id,
        'name': name,
        'code': code,
      });
    } catch (e) {
      debugPrint('[SupabaseService] ensureSubject error: $e');
    }
  }

  Future<void> saveQuiz({
    required String id,
    required String title,
    required String subjectId,
    String? subjectName,
    String? subjectCode,
    int timeLimitMinutes = 0,
    List<Map<String, dynamic>> questions = const [],
  }) async {
    if (!isInitialized) return;
    try {
      String resolvedSubjectId = subjectId;
      if (subjectCode != null && subjectCode.isNotEmpty) {
        try {
          final existing = await client!.from('subjects').select('id').ilike('code', subjectCode).maybeSingle();
          if (existing != null && existing['id'] != null) {
            resolvedSubjectId = existing['id'].toString();
          } else if (subjectName != null) {
            await ensureSubject(id: subjectId, name: subjectName, code: subjectCode);
          }
        } catch (_) {}
      }
      await client!.from('quizzes').upsert({
        'id': id,
        'title': title,
        'subject_id': resolvedSubjectId,
        'time_limit_minutes': timeLimitMinutes,
        'questions_json': questions,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[SupabaseService] saveQuiz succeeded for $id ($title)');
    } catch (e) {
      debugPrint('[SupabaseService] saveQuiz error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllQuizzes() async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('quizzes')
          .select('*, subjects(code, name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchAllQuizzes error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchQuizzes(
    String subjectId, {
    String? subjectCode,
    String? subjectName,
  }) async {
    if (!isInitialized) return [];
    try {
      final all = await fetchAllQuizzes();
      String? targetCode = subjectCode?.toUpperCase();
      String? targetName = subjectName?.trim().toUpperCase();
      if (targetCode == null || targetCode.isEmpty) {
        try {
          final sub = await client!.from('subjects').select('code, name').eq('id', subjectId).maybeSingle();
          targetCode = sub?['code']?.toString().toUpperCase();
          targetName = sub?['name']?.toString().trim().toUpperCase();
        } catch (_) {}
      }

      final matches = all.where((q) {
        if (q['subject_id']?.toString() == subjectId) return true;
        final subMap = q['subjects'] is Map ? q['subjects'] as Map<String, dynamic> : null;
        final code = subMap?['code']?.toString().toUpperCase();
        final name = subMap?['name']?.toString().trim().toUpperCase();
        if (targetCode != null && targetCode.isNotEmpty && code == targetCode) return true;
        if (targetName != null && targetName.isNotEmpty && name == targetName) return true;
        return false;
      }).toList();

      return matches.isNotEmpty ? matches : all.where((q) => q['subject_id']?.toString() == subjectId).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchQuizzes error: $e');
      return [];
    }
  }

  Future<void> deleteQuiz(String id) async {
    if (!isInitialized) return;
    try {
      await client!.from('quizzes').delete().eq('id', id);
      debugPrint('[SupabaseService] deleteQuiz succeeded for $id');
    } catch (e) {
      debugPrint('[SupabaseService] deleteQuiz error: $e');
    }
  }

  Future<void> submitQuizAttempt({
    required String quizId,
    required String studentId,
    required Map<String, dynamic> answers,
    required double score,
  }) async {
    if (!isInitialized) return;
    try {
      await client!.from('quiz_attempts').insert({
        'quiz_id': quizId,
        'student_id': studentId,
        'answers_json': answers,
        'score': score,
      });
    } catch (e) {
      debugPrint('[SupabaseService] submitQuizAttempt error: $e');
    }
  }

  // ════════════════════════════════════════════════════════════════
  // ── 6. ASSIGNMENTS & SUBMISSIONS ────────────────────────────────
  // ════════════════════════════════════════════════════════════════

  Future<void> saveAssignment({
    required String id,
    required String title,
    required String subjectId,
    String? subjectName,
    String? subjectCode,
    String? description,
    String? dueDate,
    String? attachmentUrl,
  }) async {
    if (!isInitialized) return;
    try {
      String resolvedSubjectId = subjectId;
      if (subjectCode != null && subjectCode.isNotEmpty) {
        try {
          final existing = await client!.from('subjects').select('id').ilike('code', subjectCode).maybeSingle();
          if (existing != null && existing['id'] != null) {
            resolvedSubjectId = existing['id'].toString();
          } else if (subjectName != null) {
            await ensureSubject(id: subjectId, name: subjectName, code: subjectCode);
          }
        } catch (_) {}
      }
      await client!.from('assignments').upsert({
        'id': id,
        'title': title,
        'subject_id': resolvedSubjectId,
        'description': description,
        'due_date': dueDate,
        'attachment_url': attachmentUrl,
        'created_at': DateTime.now().toIso8601String(),
      });
      debugPrint('[SupabaseService] saveAssignment succeeded for $id ($title)');
    } catch (e) {
      debugPrint('[SupabaseService] saveAssignment error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllAssignments() async {
    if (!isInitialized) return [];
    try {
      final data = await client!
          .from('assignments')
          .select('*, subjects(code, name)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('[SupabaseService] fetchAllAssignments error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchAssignments(
    String subjectId, {
    String? subjectCode,
    String? subjectName,
  }) async {
    if (!isInitialized) return [];
    try {
      final all = await fetchAllAssignments();
      String? targetCode = subjectCode?.toUpperCase();
      String? targetName = subjectName?.trim().toUpperCase();
      if (targetCode == null || targetCode.isEmpty) {
        try {
          final sub = await client!.from('subjects').select('code, name').eq('id', subjectId).maybeSingle();
          targetCode = sub?['code']?.toString().toUpperCase();
          targetName = sub?['name']?.toString().trim().toUpperCase();
        } catch (_) {}
      }

      final matches = all.where((a) {
        if (a['subject_id']?.toString() == subjectId) return true;
        final subMap = a['subjects'] is Map ? a['subjects'] as Map<String, dynamic> : null;
        final code = subMap?['code']?.toString().toUpperCase();
        final name = subMap?['name']?.toString().trim().toUpperCase();
        if (targetCode != null && targetCode.isNotEmpty && code == targetCode) return true;
        if (targetName != null && targetName.isNotEmpty && name == targetName) return true;
        return false;
      }).toList();

      return matches.isNotEmpty ? matches : all.where((a) => a['subject_id']?.toString() == subjectId).toList();
    } catch (e) {
      debugPrint('[SupabaseService] fetchAssignments error: $e');
      return [];
    }
  }

  Future<void> deleteAssignment(String id) async {
    if (!isInitialized) return;
    try {
      await client!.from('assignments').delete().eq('id', id);
      debugPrint('[SupabaseService] deleteAssignment succeeded for $id');
    } catch (e) {
      debugPrint('[SupabaseService] deleteAssignment error: $e');
    }
  }

  Future<void> submitAssignment({
    required String assignmentId,
    required String studentId,
    String? textResponse,
    String? attachmentUrl,
    double? score,
    String? feedback,
    String? submittedAt,
    Map<String, dynamic>? metadata,
  }) async {
    if (!isInitialized) return;
    try {
      String? encodedResponse = textResponse;
      if (metadata != null && metadata.isNotEmpty) {
        final payload = {
          if (textResponse != null && textResponse.isNotEmpty)
            'raw_text_response': textResponse,
          ...metadata,
        };
        encodedResponse = jsonEncode(payload);
      }

      final subPayload = <String, dynamic>{
        'assignment_id': assignmentId,
        'student_id': studentId,
        'text_response': encodedResponse,
        'attachment_url': attachmentUrl,
        'submitted_at': submittedAt ?? DateTime.now().toIso8601String(),
      };
      if (score != null) subPayload['score'] = score;
      if (feedback != null) subPayload['feedback'] = feedback;

      await client!.from('submissions').upsert(
        subPayload,
        onConflict: 'assignment_id,student_id',
      );
      debugPrint('[SupabaseService] submitAssignment succeeded for $assignmentId, student $studentId');
    } catch (e) {
      debugPrint('[SupabaseService] submitAssignment error: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubmissions({
    String? assignmentId,
    String? studentId,
  }) async {
    if (isInitialized && client != null) {
      try {
        try {
          var query = client!.from('submissions').select('*, users(full_name, email)');
          if (assignmentId != null && assignmentId.isNotEmpty) {
            query = query.eq('assignment_id', assignmentId);
          }
          if (studentId != null && studentId.isNotEmpty) {
            query = query.eq('student_id', studentId);
          }
          final data = await query.order('submitted_at', ascending: false);
          return List<Map<String, dynamic>>.from(data);
        } catch (joinErr) {
          debugPrint('[SupabaseService] fetchSubmissions join fallback: $joinErr');
          var query = client!.from('submissions').select('*');
          if (assignmentId != null && assignmentId.isNotEmpty) {
            query = query.eq('assignment_id', assignmentId);
          }
          if (studentId != null && studentId.isNotEmpty) {
            query = query.eq('student_id', studentId);
          }
          final data = await query.order('submitted_at', ascending: false);
          return List<Map<String, dynamic>>.from(data);
        }
      } catch (e) {
        debugPrint('[SupabaseService] fetchSubmissions SDK note: $e');
      }
    }

    // Direct REST API fallback via Dio (resilient to uninitialized SDK or platform issues)
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          headers: {
            'apikey': supabasePublishableKey,
            'Authorization': 'Bearer $supabasePublishableKey',
          },
        ),
      );
      String url = '$supabaseUrl/rest/v1/submissions?select=*';
      if (assignmentId != null && assignmentId.isNotEmpty) {
        url += '&assignment_id=eq.$assignmentId';
      }
      if (studentId != null && studentId.isNotEmpty) {
        url += '&student_id=eq.$studentId';
      }
      url += '&order=submitted_at.desc';
      final resp = await dio.get(url);
      if (resp.data is List) {
        return List<Map<String, dynamic>>.from(resp.data);
      }
    } catch (e) {
      debugPrint('[SupabaseService] fetchSubmissions REST error: $e');
    }

    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAllSubmissions() async {
    return fetchSubmissions();
  }
}
