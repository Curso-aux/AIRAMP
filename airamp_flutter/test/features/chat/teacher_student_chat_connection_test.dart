import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/chat/application/chat_provider.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.delete('conversations');
    await db.delete('messages');
  });

  group('Teacher - Student Two-Way Chat Connection Tests', () {
    test('Teacher messages Student and Student receives message with correct display name and unread badge', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dbHelper = DatabaseHelper();
      final users = await dbHelper.getUsers();
      final teacherUser = users.firstWhere((u) => u['id'] == 'teacher_1');
      final studentUser = users.firstWhere((u) => u['id'] == 'student_1');

      // ── Step 1: Teacher logs in ────────────────────────────────
      final teacherAuth = User(
        id: teacherUser['id'] as String,
        email: teacherUser['email'] as String,
        role: teacherUser['role'] as String,
        fullName: teacherUser['full_name'] as String,
      );
      container.read(authProvider.notifier).state = teacherAuth;

      await container.read(chatProvider.notifier).loadAvailableUsers();
      await container.read(chatProvider.notifier).loadLocalConversations();

      // ── Step 2: Teacher initiates chat with Student (Maria Lopez) ──
      final teacherConvo = await container
          .read(chatProvider.notifier)
          .getOrCreateConversation('student_1');

      expect(teacherConvo, isNotNull);
      expect(teacherConvo!.name, 'Maria Lopez'); // To teacher, chat is named Maria Lopez
      expect(teacherConvo.type, 'direct');
      final convId = teacherConvo.id;

      // Teacher sends a message
      const teacherMsgText = 'Hello Maria, please submit your Module 1 quiz today.';
      container.read(chatProvider.notifier).sendMessage(convId, teacherMsgText);

      // Verify SQLite has the message
      final savedMessages = await dbHelper.getMessages(convId);
      expect(savedMessages.length, 1);
      expect(savedMessages.first['sender_id'], 'teacher_1');
      expect(savedMessages.first['text'], teacherMsgText);
      expect(savedMessages.first['is_read'], 0); // Unread for recipient

      // ── Step 3: Switch to Student account (Maria Lopez) ────────
      final studentAuth = User(
        id: studentUser['id'] as String,
        email: studentUser['email'] as String,
        role: studentUser['role'] as String,
        fullName: studentUser['full_name'] as String,
      );
      container.read(authProvider.notifier).state = studentAuth;

      // Reload conversations as student
      await container.read(chatProvider.notifier).loadAvailableUsers();
      await container.read(chatProvider.notifier).loadLocalConversations();

      final studentChatState = container.read(chatProvider);
      expect(studentChatState.conversations.isNotEmpty, isTrue);

      // Find the conversation from student perspective
      final studentConvo = studentChatState.conversations.firstWhere(
        (c) => c.id == convId,
      );

      // CRITICAL: To the student, the chat MUST be named "Sir John Reyes", NOT "Maria Lopez"!
      expect(studentConvo.name, 'Sir John Reyes');
      expect(studentConvo.lastMessage, isNotNull);
      expect(studentConvo.lastMessage!.text, teacherMsgText);
      expect(studentConvo.lastMessage!.senderId, 'teacher_1');
      // Unread count should be 1 because student hasn't opened it yet
      expect(studentConvo.unreadCount, 1);

      // ── Step 4: Student opens the conversation (reads it) ──────
      await container.read(chatProvider.notifier).reloadMessages(convId);
      await container.read(chatProvider.notifier).markConversationAsRead(convId);

      final studentReadState = container.read(chatProvider);
      final readConvo = studentReadState.conversations.firstWhere((c) => c.id == convId);
      expect(readConvo.unreadCount, 0); // Badge cleared!

      // ── Step 5: Student sends a reply ─────────────────────────
      const studentReplyText = 'Good afternoon Sir John! I have submitted it just now.';
      container.read(chatProvider.notifier).sendMessage(convId, studentReplyText);

      // Verify DB now has 2 messages
      final dbMsgsAfterReply = await dbHelper.getMessages(convId);
      expect(dbMsgsAfterReply.length, 2);
      expect(dbMsgsAfterReply[1]['sender_id'], 'student_1');
      expect(dbMsgsAfterReply[1]['text'], studentReplyText);

      // ── Step 6: Switch back to Teacher account ─────────────────
      container.read(authProvider.notifier).state = teacherAuth;

      await container.read(chatProvider.notifier).loadAvailableUsers();
      await container.read(chatProvider.notifier).loadLocalConversations();

      final teacherNewState = container.read(chatProvider);
      final teacherUpdatedConvo = teacherNewState.conversations.firstWhere((c) => c.id == convId);

      // To teacher, chat is still Maria Lopez
      expect(teacherUpdatedConvo.name, 'Maria Lopez');
      // Unread count is 1 for the teacher (the student's new reply!)
      expect(teacherUpdatedConvo.unreadCount, 1);
      expect(teacherUpdatedConvo.lastMessage!.text, studentReplyText);

      // Teacher marks as read
      await container.read(chatProvider.notifier).reloadMessages(convId);
      await container.read(chatProvider.notifier).markConversationAsRead(convId);

      final finalState = container.read(chatProvider);
      final finalConvo = finalState.conversations.firstWhere((c) => c.id == convId);
      expect(finalConvo.unreadCount, 0);
      expect(finalState.messages[convId]!.length, 2);
    });

    test('Direct conversation ID is canonical regardless of whether Teacher or Student initiates', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(chatProvider.notifier).loadAvailableUsers();

      // Teacher initiates
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );
      final c1 = await container.read(chatProvider.notifier).getOrCreateConversation('student_1');

      // Student initiates
      container.read(authProvider.notifier).state = User(
        id: 'student_1',
        email: 'maria@test.com',
        role: 'student',
        fullName: 'Maria Lopez',
      );
      final c2 = await container.read(chatProvider.notifier).getOrCreateConversation('teacher_1');

      // Both must point to the exact same conversation ID
      expect(c1!.id, c2!.id);
      expect(c1.id, 'dm_student_1_teacher_1');

      await Future.delayed(Duration.zero);
    });

    test('Newly enrolled student (e.g. Juan Dela Cruz) dynamically appears in contacts and connects with Teacher', () async {
      final db = await DatabaseHelper().database;
      final newStudentId = 'student_${DateTime.now().millisecondsSinceEpoch}';

      final email = 'juan_${DateTime.now().millisecondsSinceEpoch}@school.edu';

      // 1. Simulate newly registered/enrolled student in SQLite
      await db.insert('users', {
        'id': newStudentId,
        'email': email,
        'password': 'password123',
        'full_name': 'Juan Dela Cruz',
        'role': 'student',
        'grade': 'Grade 11',
        'section': 'Emerald',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      addTearDown(() async {
        await db.delete('users', where: 'id = ?', whereArgs: [newStudentId]);
        await db.delete('conversations', where: 'id LIKE ?', whereArgs: ['%$newStudentId%']);
        await db.delete('messages', where: 'sender_id = ?', whereArgs: [newStudentId]);
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 2. Teacher logs in and loads contacts
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );

      await container.read(chatProvider.notifier).loadAvailableUsers();
      final teacherState = container.read(chatProvider);

      // Verify new student is present in teacher's contacts
      final juanInContacts = teacherState.availableUsers.any((u) => u.id == newStudentId && u.fullName == 'Juan Dela Cruz');
      expect(juanInContacts, isTrue);

      // 3. Teacher messages Juan Dela Cruz
      final convo = await container.read(chatProvider.notifier).getOrCreateConversation(newStudentId);
      expect(convo, isNotNull);
      expect(convo!.name, 'Juan Dela Cruz');

      const teacherMsg = 'Hello Juan, welcome to Grade 11 Emerald!';
      container.read(chatProvider.notifier).sendMessage(convo.id, teacherMsg);

      // 4. Juan Dela Cruz logs in
      container.read(authProvider.notifier).state = User(
        id: newStudentId,
        email: email,
        role: 'student',
        fullName: 'Juan Dela Cruz',
      );

      await container.read(chatProvider.notifier).loadAvailableUsers();
      await container.read(chatProvider.notifier).loadLocalConversations();

      final studentState = container.read(chatProvider);
      final studentConvo = studentState.conversations.firstWhere((c) => c.id == convo.id);

      // Juan sees teacher's name dynamically
      expect(studentConvo.name, 'Sir John Reyes');
      expect(studentConvo.unreadCount, 1);
      expect(studentConvo.lastMessage!.text, teacherMsg);

      // 5. Juan replies back
      const juanReply = 'Thank you Sir John, excited to learn!';
      container.read(chatProvider.notifier).sendMessage(convo.id, juanReply);

      // 6. Teacher logs back in and sees Juan's reply
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );

      await container.read(chatProvider.notifier).loadLocalConversations();
      final teacherUpdatedState = container.read(chatProvider);
      final teacherConvo = teacherUpdatedState.conversations.firstWhere((c) => c.id == convo.id);

      expect(teacherConvo.name, 'Juan Dela Cruz');
      expect(teacherConvo.unreadCount, 1);
      expect(teacherConvo.lastMessage!.text, juanReply);

      await Future.delayed(Duration.zero);
    });
  });
}
