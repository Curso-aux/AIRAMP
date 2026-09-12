import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/chat/application/chat_provider.dart';
import 'package:airamp_flutter/src/features/chat/presentation/chat_list_screen.dart';
import 'package:airamp_flutter/src/features/admin/presentation/subjects_mgmt_screen.dart';

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await DatabaseHelper().database;
  });

  tearDown(() async {
    final db = await DatabaseHelper().database;
    await db.delete('conversations');
    await db.delete('messages');
    await db.delete('subjects');
  });

  group('Contacts Database & State Integration', () {
    test('DatabaseHelper loads users with role, grade, and section', () async {
      final dbHelper = DatabaseHelper();
      final users = await dbHelper.getUsers();

      expect(users.isNotEmpty, isTrue);

      // Verify teachers
      final teachers = users.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin');
      expect(teachers.isNotEmpty, isTrue);

      // Verify students with section and grade
      final students = users.where((u) => u['role'] == 'student');
      expect(students.isNotEmpty, isTrue);

      final maria = students.firstWhere((s) => s['id'] == 'student_1');
      expect(maria['full_name'], 'Maria Lopez');
      expect(maria['section'], contains('Emerald'));
      expect(maria['grade'], 'Grade 10');
    });

    test('ChatNotifier.loadAvailableUsers populates availableUsers with student & teacher metadata', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(chatProvider.notifier).loadAvailableUsers();
      final chatState = container.read(chatProvider);

      expect(chatState.availableUsers.isNotEmpty, isTrue);

      final maria = chatState.availableUsers.firstWhere((u) => u.id == 'student_1');
      expect(maria.role, 'student');
      expect(maria.section, contains('Emerald'));
      expect(maria.grade, 'Grade 10');

      final teacher = chatState.availableUsers.firstWhere((u) => u.id == 'teacher_1');
      expect(teacher.role, 'teacher');
    });

    test('getOrCreateConversation creates a 1-on-1 direct conversation with target user', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );

      await container.read(chatProvider.notifier).loadAvailableUsers();

      final convo = await container.read(chatProvider.notifier).getOrCreateConversation('student_1');
      expect(convo, isNotNull);
      expect(convo!.type, 'direct');
      expect(convo.name, 'Maria Lopez');

      // Second call should return the exact same conversation
      final convo2 = await container.read(chatProvider.notifier).getOrCreateConversation('student_1');
      expect(convo2!.id, convo.id);

      // Check SQLite persistence
      final db = await DatabaseHelper().database;
      final saved = await db.query('conversations', where: 'id = ?', whereArgs: [convo.id]);
      expect(saved.length, 1);
      expect(saved.first['type'], 'direct');
    });
  });

  group('ChatListScreen Contacts Directory UI', () {
    testWidgets('Renders Chats and Contacts tabs and switches between them', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = User(
        id: 'admin_1',
        email: 'aira@admin',
        role: 'admin',
        fullName: 'Aira Admin',
      );

      await tester.runAsync(() async {
        await container.read(chatProvider.notifier).loadAvailableUsers();
        await container.read(chatProvider.notifier).loadLocalConversations();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatListScreen(),
          ),
        ),
      );

      // Advance frames and async isolate
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      expect(find.text('Messages & Contacts'), findsOneWidget);
      expect(find.byKey(const Key('tab_chats')), findsOneWidget);
      expect(find.byKey(const Key('tab_contacts')), findsOneWidget);

      // Tap Contacts tab
      await tester.tap(find.byKey(const Key('tab_contacts')));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pumpAndSettle();

      // Verify contact filters and elements
      expect(find.text('All Contacts'), findsOneWidget);
      expect(find.text('Teachers'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);

      // Verify student labeling and clean contact card
      expect(find.text('Maria Lopez'), findsOneWidget);
      expect(find.text('Student'), findsWidgets);
      expect(find.text('maria@test.com'), findsOneWidget);

      // Verify teacher labeling
      expect(find.text('Sir John Reyes'), findsOneWidget);
      expect(find.text('Teacher'), findsWidgets);

      // Tap on Maria Lopez contact to view profile modal
      await tester.tap(find.text('Maria Lopez'));
      await tester.pumpAndSettle();

      // Verify profile modal contents
      expect(find.text('Grade Level'), findsOneWidget);
      expect(find.text('Grade 10'), findsOneWidget);
      expect(find.text('Section'), findsOneWidget);
      expect(find.textContaining('Emerald'), findsOneWidget);
      expect(find.text('Account Role'), findsOneWidget);
      expect(find.text('Learner'), findsOneWidget);
      expect(find.text('Message Maria'), findsOneWidget);

      // Dismiss profile sheet
      Navigator.of(tester.element(find.text('Grade Level'))).pop();
      await tester.pumpAndSettle();
    });

    testWidgets('Filter by Teachers hides students', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = User(
        id: 'admin_1',
        email: 'aira@admin',
        role: 'admin',
        fullName: 'Aira Admin',
      );

      await tester.runAsync(() async {
        await container.read(chatProvider.notifier).loadAvailableUsers();
        await container.read(chatProvider.notifier).loadLocalConversations();
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatListScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      // Switch to Contacts tab
      await tester.tap(find.byKey(const Key('tab_contacts')));
      await tester.pumpAndSettle();

      // Tap Teachers filter pill
      await tester.tap(find.text('Teachers'));
      await tester.pumpAndSettle();

      expect(find.text('Sir John Reyes'), findsOneWidget);
      expect(find.text('Maria Lopez'), findsNothing);
    });

    testWidgets('Long press on conversation opens options sheet with Edit, Archive, and Delete', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );

      // Initialize users and create a test conversation
      await tester.runAsync(() async {
        await container.read(chatProvider.notifier).loadAvailableUsers();
        final convo = await container.read(chatProvider.notifier).getOrCreateConversation('student_1');
        expect(convo, isNotNull);
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatListScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      // Maria Lopez conversation should appear in active chats
      expect(find.text('Maria Lopez'), findsOneWidget);

      // Long press the conversation
      await tester.longPress(find.text('Maria Lopez'));
      await tester.pumpAndSettle();

      // Verify options sheet
      expect(find.text('Edit Name'), findsOneWidget);
      expect(find.text('Archive Chat'), findsOneWidget);
      expect(find.text('Delete Chat'), findsOneWidget);

      // Tap Archive Chat
      await tester.tap(find.text('Archive Chat'));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 500));

      // Verify it moved to archived
      expect(find.text('No active conversations yet'), findsOneWidget);
      expect(find.text('Archived (1)'), findsOneWidget);

      // Tap Archived pill
      await tester.tap(find.text('Archived (1)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Now Maria Lopez conversation should appear in archived view
      expect(find.text('Maria Lopez'), findsOneWidget);

      // Long press in archived view and Unarchive
      await tester.longPress(find.text('Maria Lopez'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Unarchive Chat'), findsOneWidget);
      await tester.tap(find.text('Unarchive Chat'));
      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pump(const Duration(milliseconds: 500));

      // Tap Active Chats pill
      await tester.tap(find.text('Active Chats'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Maria Lopez'), findsOneWidget);
    });

    testWidgets('Swipe right triggers Edit Name dialog and swipe left triggers options', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(authProvider.notifier).state = User(
        id: 'teacher_1',
        email: 'john.reyes@deped.gov.ph',
        role: 'teacher',
        fullName: 'Sir John Reyes',
      );

      await tester.runAsync(() async {
        await container.read(chatProvider.notifier).loadAvailableUsers();
        await container.read(chatProvider.notifier).getOrCreateConversation('student_1');
      });

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ChatListScreen(),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      // Swipe right on conversation
      await tester.drag(find.text('Maria Lopez'), const Offset(500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify Edit Name dialog appears
      expect(find.text('Edit Chat Name'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Swipe left on conversation
      await tester.drag(find.text('Maria Lopez'), const Offset(-500, 0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify options sheet appears
      expect(find.text('Archive Chat'), findsOneWidget);
      expect(find.text('Delete Chat'), findsOneWidget);
      Navigator.of(tester.element(find.text('Archive Chat'))).pop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });
  });

  group('Subject Creation Clean Workflow', () {
    testWidgets('Creating subject does not show group chat dialogs or toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: SubjectsMgmtScreen()),
          ),
        ),
      );

      for (int i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 30)));
        await tester.pump(const Duration(milliseconds: 30));
      }
      await tester.pumpAndSettle();

      // Tap Create New Subject
      await tester.tap(find.text('Create New Subject'));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify no group chat toggle in the sheet
      expect(find.text('Auto-create Subject Group Chat'), findsNothing);
      expect(find.text('+ Group Chat'), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });
}
