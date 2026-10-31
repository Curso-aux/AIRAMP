import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:airamp_flutter/src/core/components/user_avatar_widget.dart';
import 'package:airamp_flutter/src/core/database/database_helper.dart';
import 'package:airamp_flutter/src/core/database/firestore_service.dart';
import 'package:airamp_flutter/src/features/auth/application/auth_provider.dart';
import 'package:airamp_flutter/src/features/auth/data/auth_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    HttpOverrides.global = null;
  });

  group('Student Profile Customization & Avatar Tests', () {
    testWidgets('UserAvatarWidget renders letter initial when profileImage is null or empty',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              imageSource: null,
              fallbackInitial: 'K',
              size: 50,
            ),
          ),
        ),
      );

      expect(find.text('K'), findsOneWidget);
    });

    testWidgets('UserAvatarWidget renders preset icon when profileImage is preset:scholar',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              imageSource: 'preset:scholar',
              fallbackInitial: 'K',
              size: 60,
            ),
          ),
        ),
      );

      // Verify the school icon from kAvatarPresets is rendered
      expect(find.byIcon(Icons.school_rounded), findsOneWidget);
      expect(find.text('K'), findsNothing);
    });

    testWidgets('UserAvatarWidget decodes and renders base64 data URL without error',
        (tester) async {
      // 1x1 transparent PNG in base64
      const transparent1x1Png =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatarWidget(
              imageSource: transparent1x1Png,
              fallbackInitial: 'K',
              size: 60,
            ),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    test('Student updates own profile: name, username, and avatar preset persist to SQLite & Firestore',
        () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final studentEmail = 'student_profile_$timestamp@school.edu';
      const initialPassword = 'Password@123';
      final dbHelper = DatabaseHelper();

      // Create student
      final studentId = await dbHelper.createStudent(
        fullName: 'Original Student Name',
        email: studentEmail,
        password: initialPassword,
        username: 'orig_student_$timestamp',
        grade: 'Grade 11',
        section: 'STEM B',
      );
      expect(studentId, isNotEmpty);

      final authRepo = AuthRepository();

      // Student changes their own profile
      const updatedFullName = 'King Khevin L. Curso';
      const updatedUsername = 'dasu_coder';
      const chosenPresetAvatar = 'preset:coder';

      await authRepo.updateProfile(
        userId: studentId,
        fullName: updatedFullName,
        username: updatedUsername,
        profileImage: chosenPresetAvatar,
      );

      // Verify in local SQLite database
      final db = await dbHelper.database;
      final localRows = await db.query('users', where: 'id = ?', whereArgs: [studentId]);
      expect(localRows, isNotEmpty);
      expect(localRows.first['full_name'], equals(updatedFullName));
      expect(localRows.first['username'], equals(updatedUsername));
      expect(localRows.first['profile_image'], equals(chosenPresetAvatar));

      // Verify in Cloud Firestore
      final cloudUser = await FirestoreService().findUserByIdentifier(studentEmail);
      expect(cloudUser, isNotNull);
      expect(cloudUser!['full_name'], equals(updatedFullName));
      expect(cloudUser['username'], equals(updatedUsername));
      expect(cloudUser['profile_image'] ?? cloudUser['profileImage'], equals(chosenPresetAvatar));

      // Verify login returns updated profile image and details
      final loginResult = await authRepo.login(studentEmail, initialPassword);
      final loggedInUser = loginResult['user'] as Map<String, dynamic>;
      expect(loggedInUser['fullName'], equals(updatedFullName));
      expect(loggedInUser['username'], equals(updatedUsername));
      expect(loggedInUser['profileImage'], equals(chosenPresetAvatar));
    });

    test('Student uploads custom photo: base64 image persists and restores properly', () async {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final studentEmail = 'photo_student_$timestamp@school.edu';
      const initialPassword = 'Password@123';
      final dbHelper = DatabaseHelper();

      final studentId = await dbHelper.createStudent(
        fullName: 'Photo Tester',
        email: studentEmail,
        password: initialPassword,
        username: 'photo_test_$timestamp',
      );

      const uploadedDataUrl =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';

      final authRepo = AuthRepository();
      await authRepo.updateProfile(
        userId: studentId,
        profileImage: uploadedDataUrl,
      );

      // Check SQLite
      final db = await dbHelper.database;
      final localRows = await db.query('users', where: 'id = ?', whereArgs: [studentId]);
      expect(localRows.first['profile_image'], equals(uploadedDataUrl));

      // Check User model parsing
      final userModel = User.fromJson({
        'id': studentId,
        'email': studentEmail,
        'role': 'student',
        'full_name': 'Photo Tester',
        'profile_image': uploadedDataUrl,
      });
      expect(userModel.profileImage, equals(uploadedDataUrl));
    });
  });
}
