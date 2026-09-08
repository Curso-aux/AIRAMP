import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWeb;
        return await openDatabase(
          'airamp_local.db',
          version: 15,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            await _seedInitialData(db);
          },
        );
      } catch (e) {
        debugPrint('Failed to open with shared worker, falling back to databaseFactoryFfiWebNoWebWorker: $e');
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        return await openDatabase(
          'airamp_local.db',
          version: 15,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: (db) async {
            await _seedInitialData(db);
          },
        );
      }
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'airamp_local.db');

    return await openDatabase(
      path,
      version: 15,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        await _seedInitialData(db);
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        role TEXT NOT NULL,
        full_name TEXT NOT NULL,
        section TEXT,
        grade TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Seed default authentic accounts
    await db.insert('users', {
      'id': 'admin_1',
      'email': 'aira@admin',
      'password': 'aira@admin',
      'role': 'super_admin',
      'full_name': 'Aira Super Admin',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'admin_2',
      'email': 'admin@aira.edu',
      'password': 'Admin@123',
      'role': 'admin',
      'full_name': 'School Administrator',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'teacher_1',
      'email': 'john.reyes@deped.gov.ph',
      'password': 'John@123',
      'role': 'teacher',
      'full_name': 'Sir John Reyes',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'student_1',
      'email': 'maria@test.com',
      'password': 'Maria@123',
      'role': 'student',
      'full_name': 'Maria Lopez',
      'section': 'Emerald',
      'grade': 'Grade 10',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Announcements Table
    await db.execute('''
      CREATE TABLE announcements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        message TEXT NOT NULL,
        priority TEXT NOT NULL,
        target_audience TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Subjects Table
    await db.execute('''
      CREATE TABLE subjects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        subject_code TEXT,
        description TEXT NOT NULL,
        grade_level TEXT,
        semester TEXT,
        unlock_type TEXT,
        teacher_id TEXT,
        teacher_name TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Topics Table
    await db.execute('''
      CREATE TABLE topics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subject_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // Learning Outcomes Table
    await db.execute('''
      CREATE TABLE learning_outcomes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        topic_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        performance_criteria TEXT,
        passing_score INTEGER DEFAULT 0,
        schedule_start TEXT,
        schedule_end TEXT,
        timezone TEXT,
        allow_extend INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE
      )
    ''');

    // Contents Table
    await db.execute('''
      CREATE TABLE contents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lo_id INTEGER NOT NULL,
        content_type TEXT NOT NULL,
        title TEXT NOT NULL,
        content_data TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lo_id) REFERENCES learning_outcomes (id) ON DELETE CASCADE
      )
    ''');

    // Questions Table
    await db.execute('''
      CREATE TABLE questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        lo_id INTEGER NOT NULL,
        question_text TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        correct_option TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lo_id) REFERENCES learning_outcomes (id) ON DELETE CASCADE
      )
    ''');

    // Sections Table
    await db.execute('''
      CREATE TABLE sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        grade TEXT NOT NULL,
        room TEXT,
        student_count INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Registration Links Table
    await db.execute('''
      CREATE TABLE reg_links (
        code TEXT PRIMARY KEY,
        section TEXT,
        max_uses INTEGER NOT NULL,
        used_count INTEGER NOT NULL,
        expiration TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Sessions Table (auth session storage for v9)
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

    // App Settings Table (theme preference, etc.)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Conversations Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        name TEXT,
        subject_id INTEGER,
        is_archived INTEGER DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    // Messages Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        sender_id TEXT NOT NULL,
        text TEXT NOT NULL,
        created_at TEXT NOT NULL,
        is_read INTEGER DEFAULT 0,
        FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
      )
    ''');

    // Enrollments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS enrollments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        subject_id INTEGER NOT NULL,
        enrolled_at TEXT NOT NULL,
        status TEXT DEFAULT 'active',
        UNIQUE(student_id, subject_id)
      )
    ''');

    // Student Progress Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS student_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        lo_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        is_completed INTEGER DEFAULT 0,
        score INTEGER,
        completed_at TEXT,
        UNIQUE(student_id, lo_id)
      )
    ''');

    // Quiz Attempts Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        lo_id INTEGER NOT NULL,
        subject_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        percentage REAL NOT NULL,
        is_passed INTEGER NOT NULL,
        duration_seconds INTEGER,
        attempted_at TEXT NOT NULL
      )
    ''');

    // Seed initial curriculum data
    await _seedInitialData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          email TEXT UNIQUE NOT NULL,
          password TEXT NOT NULL,
          role TEXT NOT NULL,
          full_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // Seed default accounts if upgrading
      final existing = await db.query('users');
      if (existing.isEmpty) {
        await db.insert('users', {
          'id': 'super_admin_1',
          'email': 'aira@admin',
          'password': 'aira@admin',
          'role': 'super_admin',
          'full_name': 'Aira Admin',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('users', {
          'id': 'teacher_1',
          'email': 'john.reyes@deped.gov.ph',
          'password': 'John@123',
          'role': 'admin',
          'full_name': 'Sir John',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('users', {
          'id': 'student_1',
          'email': 'maria@test.com',
          'password': 'Maria@123',
          'role': 'student',
          'full_name': 'Maria Lopez',
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    
    if (oldVersion < 3) {
      // Fix seeded passwords
      await db.update('users', {'password': 'aira@admin'}, where: 'email = ?', whereArgs: ['aira@admin']);
      await db.update('users', {'password': 'John@123'}, where: 'email = ?', whereArgs: ['john.reyes@deped.gov.ph']);
      await db.update('users', {'password': 'Maria@123'}, where: 'email = ?', whereArgs: ['maria@test.com']);
    }
    
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE subjects ADD COLUMN subject_code TEXT');
      await db.execute('ALTER TABLE subjects ADD COLUMN grade_level TEXT');
      await db.execute('ALTER TABLE subjects ADD COLUMN unlock_type TEXT');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE subjects ADD COLUMN semester TEXT');
    }

    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE topics (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          subject_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE TABLE learning_outcomes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          topic_id INTEGER NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          performance_criteria TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (topic_id) REFERENCES topics (id) ON DELETE CASCADE
        )
      ''');
      
      await db.execute('''
        CREATE TABLE contents (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lo_id INTEGER NOT NULL,
          content_type TEXT NOT NULL,
          title TEXT NOT NULL,
          content_data TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (lo_id) REFERENCES learning_outcomes (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE questions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          lo_id INTEGER NOT NULL,
          question_text TEXT NOT NULL,
          option_a TEXT NOT NULL,
          option_b TEXT NOT NULL,
          option_c TEXT NOT NULL,
          option_d TEXT NOT NULL,
          correct_option TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (lo_id) REFERENCES learning_outcomes (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 8) {
      await db.execute('ALTER TABLE learning_outcomes ADD COLUMN passing_score INTEGER DEFAULT 0;');
      await db.execute('ALTER TABLE learning_outcomes ADD COLUMN schedule_start TEXT;');
      await db.execute('ALTER TABLE learning_outcomes ADD COLUMN schedule_end TEXT;');
      await db.execute('ALTER TABLE learning_outcomes ADD COLUMN timezone TEXT;');
      await db.execute('ALTER TABLE learning_outcomes ADD COLUMN allow_extend INTEGER DEFAULT 0;');
    }

    if (oldVersion < 9) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id TEXT NOT NULL,
          token TEXT NOT NULL UNIQUE,
          role TEXT NOT NULL,
          created_at TEXT NOT NULL,
          expires_at TEXT
        )
      ''');
    }

    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }

    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS conversations (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          name TEXT,
          subject_id INTEGER,
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS messages (
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          sender_id TEXT NOT NULL,
          text TEXT NOT NULL,
          created_at TEXT NOT NULL,
          is_read INTEGER DEFAULT 0,
          FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 12) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN section TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE users ADD COLUMN grade TEXT');
      } catch (_) {}

      // Update student_1 with section and grade
      await db.update('users', {
        'section': 'Emerald',
        'grade': 'Grade 10',
      }, where: 'id = ?', whereArgs: ['student_1']);

      // Update teacher_1 name if needed
      await db.update('users', {
        'full_name': 'Sir John Reyes',
      }, where: 'id = ?', whereArgs: ['teacher_1']);

      // Seed additional realistic contacts
      final usersToSeed = [
        {
          'id': 'teacher_2',
          'email': 'sarah.jenkins@university.edu',
          'password': 'Sarah@123',
          'role': 'admin',
          'full_name': 'Prof. Sarah Jenkins',
          'section': null,
          'grade': null,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'student_2',
          'email': 'juan.delacruz@school.edu',
          'password': 'Juan@123',
          'role': 'student',
          'full_name': 'Juan Dela Cruz',
          'section': 'Ruby',
          'grade': 'Grade 10',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'student_3',
          'email': 'angela.santos@school.edu',
          'password': 'Angela@123',
          'role': 'student',
          'full_name': 'Angela Santos',
          'section': 'Diamond',
          'grade': 'Grade 11',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'student_4',
          'email': 'mark.bautista@school.edu',
          'password': 'Mark@123',
          'role': 'student',
          'full_name': 'Mark Bautista',
          'section': 'Emerald',
          'grade': 'Grade 10',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'student_5',
          'email': 'bea.alonzo@school.edu',
          'password': 'Bea@123',
          'role': 'student',
          'full_name': 'Bea Alonzo',
          'section': 'Gold',
          'grade': 'Grade 12',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'student_6',
          'email': 'christian.rivera@school.edu',
          'password': 'Christian@123',
          'role': 'student',
          'full_name': 'Christian Rivera',
          'section': 'Ruby',
          'grade': 'Grade 11',
          'created_at': DateTime.now().toIso8601String(),
        },
      ];

      for (final u in usersToSeed) {
        final exists = await db.query('users', where: 'id = ?', whereArgs: [u['id']]);
        if (exists.isEmpty) {
          await db.insert('users', u);
        }
      }
    }

    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE conversations ADD COLUMN is_archived INTEGER DEFAULT 0');
      } catch (_) {}
      // Clean up hardcoded dummy users so only authentic and registered users remain
      await db.delete('users', where: "id IN ('student_2', 'student_3', 'student_4', 'student_5', 'student_6', 'teacher_2')");
    }

    if (oldVersion < 14) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS enrollments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT NOT NULL,
          subject_id INTEGER NOT NULL,
          enrolled_at TEXT NOT NULL,
          status TEXT DEFAULT 'active',
          UNIQUE(student_id, subject_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS student_progress (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT NOT NULL,
          lo_id INTEGER NOT NULL,
          subject_id INTEGER NOT NULL,
          is_completed INTEGER DEFAULT 0,
          score INTEGER,
          completed_at TEXT,
          UNIQUE(student_id, lo_id)
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quiz_attempts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          student_id TEXT NOT NULL,
          lo_id INTEGER NOT NULL,
          subject_id INTEGER NOT NULL,
          score INTEGER NOT NULL,
          total_questions INTEGER NOT NULL,
          percentage REAL NOT NULL,
          is_passed INTEGER NOT NULL,
          duration_seconds INTEGER,
          attempted_at TEXT NOT NULL
        )
      ''');
      await _seedInitialData(db);
    }

    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE sections ADD COLUMN room TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE subjects ADD COLUMN teacher_id TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE subjects ADD COLUMN teacher_name TEXT');
      } catch (_) {}
      await _seedInitialData(db);
    }
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final res = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Chat Conversations & Messages ──────────────────────────

  Future<List<Map<String, dynamic>>> getConversations() async {
    final db = await database;
    return await db.query('conversations', orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getConversationBySubjectId(int subjectId) async {
    final db = await database;
    final res = await db.query('conversations', where: 'subject_id = ?', whereArgs: [subjectId]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> saveConversation(Map<String, dynamic> convo) async {
    final db = await database;
    await db.insert('conversations', convo, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateConversationName(String id, String newName) async {
    final db = await database;
    await db.update('conversations', {'name': newName}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> setConversationArchived(String id, bool isArchived) async {
    final db = await database;
    await db.update('conversations', {'is_archived': isArchived ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateMessageText(String id, String newText) async {
    final db = await database;
    await db.update('messages', {'text': newText}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final db = await database;
    return await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> saveMessage(Map<String, dynamic> msg) async {
    final db = await database;
    await db.insert('messages', msg, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getLastMessage(String conversationId) async {
    final db = await database;
    final res = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  // ── Users & Contacts ───────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUsers() async {
    final db = await database;
    return await db.query('users', orderBy: 'role ASC, full_name ASC');
  }

  Future<Map<String, dynamic>?> getDirectConversation(String userId1, String userId2) async {
    final db = await database;
    final id1 = 'dm_${userId1}_$userId2';
    final id2 = 'dm_${userId2}_$userId1';
    final res = await db.query(
      'conversations',
      where: 'id = ? OR id = ?',
      whereArgs: [id1, id2],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  // ── Curriculum, Enrollment, Progress & Quizzes ─────────────

  Future<List<Map<String, dynamic>>> getEnrolledSubjects(String studentId) async {
    final db = await database;
    final subjects = await db.rawQuery('''
      SELECT s.*, e.enrolled_at, e.status as enrollment_status
      FROM subjects s
      JOIN enrollments e ON e.subject_id = s.id
      WHERE e.student_id = ?
      ORDER BY e.enrolled_at DESC
    ''', [studentId]);

    final List<Map<String, dynamic>> enriched = [];
    for (final s in subjects) {
      final subjectId = s['id'] as int;

      // Count total LOs
      final totalLoRes = await db.rawQuery('''
        SELECT COUNT(lo.id) as count
        FROM learning_outcomes lo
        JOIN topics t ON lo.topic_id = t.id
        WHERE t.subject_id = ?
      ''', [subjectId]);
      final totalLos = (totalLoRes.first['count'] as int?) ?? 0;

      // Count completed LOs
      final completedLoRes = await db.rawQuery('''
        SELECT COUNT(id) as count
        FROM student_progress
        WHERE student_id = ? AND subject_id = ? AND is_completed = 1
      ''', [studentId, subjectId]);
      final completedLos = (completedLoRes.first['count'] as int?) ?? 0;

      // Count topics (COCs)
      final topicRes = await db.rawQuery('''
        SELECT COUNT(id) as count FROM topics WHERE subject_id = ?
      ''', [subjectId]);
      final cocs = (topicRes.first['count'] as int?) ?? 0;

      final progress = totalLos > 0 ? ((completedLos / totalLos) * 100).round() : 0;

      enriched.add({
        ...s,
        'total_los': totalLos,
        'completed_los': completedLos,
        'cocs': cocs,
        'progress': progress,
      });
    }
    return enriched;
  }

  Future<List<Map<String, dynamic>>> getAvailableSubjects(String studentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM subjects
      WHERE id NOT IN (
        SELECT subject_id FROM enrollments WHERE student_id = ?
      )
      ORDER BY id DESC
    ''', [studentId]);
  }

  Future<void> enrollSubject(String studentId, int subjectId) async {
    final db = await database;
    await db.insert(
      'enrollments',
      {
        'student_id': studentId,
        'subject_id': subjectId,
        'enrolled_at': DateTime.now().toIso8601String(),
        'status': 'active',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> unenrollSubject(String studentId, int subjectId) async {
    final db = await database;
    await db.delete(
      'enrollments',
      where: 'student_id = ? AND subject_id = ?',
      whereArgs: [studentId, subjectId],
    );
  }

  Future<void> recordQuizAttempt({
    required String studentId,
    required int loId,
    required int subjectId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required bool isPassed,
    int durationSeconds = 0,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.insert('quiz_attempts', {
      'student_id': studentId,
      'lo_id': loId,
      'subject_id': subjectId,
      'score': score,
      'total_questions': totalQuestions,
      'percentage': percentage,
      'is_passed': isPassed ? 1 : 0,
      'duration_seconds': durationSeconds,
      'attempted_at': now,
    });

    if (isPassed) {
      await db.insert(
        'student_progress',
        {
          'student_id': studentId,
          'lo_id': loId,
          'subject_id': subjectId,
          'is_completed': 1,
          'score': score,
          'completed_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<List<Map<String, dynamic>>> getStudentQuizAttempts(String studentId, {int? subjectId}) async {
    final db = await database;
    if (subjectId != null) {
      return await db.rawQuery('''
        SELECT qa.*, s.name as subject_name, s.subject_code, lo.title as lo_title, lo.passing_score
        FROM quiz_attempts qa
        JOIN subjects s ON qa.subject_id = s.id
        JOIN learning_outcomes lo ON qa.lo_id = lo.id
        WHERE qa.student_id = ? AND qa.subject_id = ?
        ORDER BY qa.attempted_at DESC
      ''', [studentId, subjectId]);
    }
    return await db.rawQuery('''
      SELECT qa.*, s.name as subject_name, s.subject_code, lo.title as lo_title, lo.passing_score
      FROM quiz_attempts qa
      JOIN subjects s ON qa.subject_id = s.id
      JOIN learning_outcomes lo ON qa.lo_id = lo.id
      WHERE qa.student_id = ?
      ORDER BY qa.attempted_at DESC
    ''', [studentId]);
  }

  Future<Map<String, dynamic>> getStudentProgressSummary(String studentId, {int? subjectId}) async {
    final enrolled = await getEnrolledSubjects(studentId);
    final activeCourses = enrolled.length;

    int totalLos = 0;
    int completedLos = 0;
    for (final s in enrolled) {
      if (subjectId == null || s['id'] == subjectId) {
        totalLos += (s['total_los'] as int? ?? 0);
        completedLos += (s['completed_los'] as int? ?? 0);
      }
    }

    final attempts = await getStudentQuizAttempts(studentId, subjectId: subjectId);
    final totalAttempts = attempts.length;
    final passedAttempts = attempts.where((a) => (a['is_passed'] as int? ?? 0) == 1).length;

    double avgScore = 0.0;
    double bestScore = 0.0;
    if (totalAttempts > 0) {
      double sum = 0;
      for (final a in attempts) {
        final p = (a['percentage'] as num?)?.toDouble() ?? 0.0;
        sum += p;
        if (p > bestScore) bestScore = p;
      }
      avgScore = sum / totalAttempts;
    }

    final pending = (totalLos - completedLos) > 0 ? (totalLos - completedLos) : 0;

    return {
      'activeCourses': activeCourses,
      'completed': completedLos,
      'total': totalLos,
      'pending': pending,
      'average': avgScore,
      'best': bestScore,
      'totalAttempts': totalAttempts,
      'passedAttempts': passedAttempts,
    };
  }

  Future<Map<String, dynamic>?> getLoQuiz(int loId) async {
    final db = await database;
    final loRes = await db.query('learning_outcomes', where: 'id = ?', whereArgs: [loId]);
    if (loRes.isEmpty) return null;

    final lo = loRes.first;
    final topicRes = await db.query('topics', where: 'id = ?', whereArgs: [lo['topic_id']]);
    final subjectId = topicRes.isNotEmpty ? topicRes.first['subject_id'] as int : 0;

    final questions = await db.query('questions', where: 'lo_id = ?', whereArgs: [loId], orderBy: 'id ASC');

    return {
      ...lo,
      'subject_id': subjectId,
      'questions': questions,
    };
  }

  Future<List<Map<String, dynamic>>> getAllQuizScores({String? section, String? query}) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT qa.*, 
             u.full_name as student_name, 
             u.email as student_email, 
             u.section as student_section, 
             u.grade as student_grade,
             s.name as subject_name, 
             s.subject_code, 
             lo.title as lo_title, 
             lo.passing_score
      FROM quiz_attempts qa
      JOIN users u ON qa.student_id = u.id
      JOIN subjects s ON qa.subject_id = s.id
      JOIN learning_outcomes lo ON qa.lo_id = lo.id
      ORDER BY qa.attempted_at DESC
    ''');

    var list = results;
    if (section != null && section.isNotEmpty && section != 'All Sections') {
      list = list.where((r) => r['student_section'] == section).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      list = list.where((r) {
        final name = (r['student_name'] as String? ?? '').toLowerCase();
        final email = (r['student_email'] as String? ?? '').toLowerCase();
        final subject = (r['subject_name'] as String? ?? '').toLowerCase();
        final code = (r['subject_code'] as String? ?? '').toLowerCase();
        final lo = (r['lo_title'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || subject.contains(q) || code.contains(q) || lo.contains(q);
      }).toList();
    }
    return list;
  }

  // ── Admin Web Analytics & Student Management ───────────────

  Future<Map<String, dynamic>> getAdminAnalyticsSummary() async {
    final db = await database;

    final users = await db.query('users');
    final totalUsers = users.length;
    final totalStudents = users.where((u) => u['role'] == 'student').length;
    final totalTeachers = users.where((u) => u['role'] == 'teacher').length;
    final totalAdmins = users.where((u) => u['role'] == 'admin' || u['role'] == 'super_admin').length;

    final subjects = await db.query('subjects');
    final totalSubjects = subjects.length;

    final enrollments = await db.query('enrollments');
    final totalEnrollments = enrollments.length;

    final topics = await db.query('topics');
    final los = await db.query('learning_outcomes');

    final attempts = await db.query('quiz_attempts');
    final totalAttempts = attempts.length;
    final passedAttempts = attempts.where((a) => a['is_passed'] == 1 || a['is_passed'] == true).length;
    final passRate = totalAttempts > 0 ? ((passedAttempts / totalAttempts) * 100).round() : 0;
    final avgScore = totalAttempts > 0
        ? (attempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / totalAttempts).round()
        : 0;

    final List<Map<String, dynamic>> subjectEnrollments = [];
    for (final s in subjects) {
      final subId = s['id'] as int;
      final subEnrollments = enrollments.where((e) => e['subject_id'] == subId).length;
      subjectEnrollments.add({
        'id': subId,
        'name': s['name'] as String? ?? 'Subject',
        'code': s['subject_code'] as String? ?? 'CS',
        'enrollments': subEnrollments,
      });
    }

    final Map<String, int> sectionMap = {};
    for (final u in users) {
      if (u['role'] == 'student') {
        final sec = (u['section'] as String?)?.trim();
        final label = (sec != null && sec.isNotEmpty) ? sec : 'Unassigned';
        sectionMap[label] = (sectionMap[label] ?? 0) + 1;
      }
    }
    final List<Map<String, dynamic>> sectionDistribution = sectionMap.entries
        .map((e) => {'section': e.key, 'count': e.value})
        .toList();

    final announcements = await db.query('announcements', orderBy: 'id DESC', limit: 5);
    final recentAttempts = await getAllQuizScores();

    return {
      'totalUsers': totalUsers,
      'totalStudents': totalStudents,
      'totalTeachers': totalTeachers,
      'totalAdmins': totalAdmins,
      'totalEnrollments': totalEnrollments,
      'totalSubjects': totalSubjects,
      'totalTopics': topics.length,
      'totalLos': los.length,
      'totalAttempts': totalAttempts,
      'passedAttempts': passedAttempts,
      'passRate': passRate,
      'avgScore': avgScore,
      'subjectEnrollments': subjectEnrollments,
      'sectionDistribution': sectionDistribution,
      'recentAnnouncements': announcements,
      'recentAttempts': recentAttempts.take(6).toList(),
    };
  }

  Future<List<Map<String, dynamic>>> getAdminStudentsList({String? section, String? grade, String? query}) async {
    final db = await database;

    final users = await db.query('users', where: "role = 'student'", orderBy: 'full_name ASC');
    final enrollments = await db.query('enrollments');
    final progress = await db.query('student_progress', where: 'is_completed = 1');
    final attempts = await db.query('quiz_attempts');

    List<Map<String, dynamic>> enriched = [];
    for (final u in users) {
      final sId = u['id'] as String;
      final studentEnrollments = enrollments.where((e) => e['student_id'] == sId).length;
      final studentProgress = progress.where((p) => p['student_id'] == sId).length;
      final studentAttempts = attempts.where((a) => a['student_id'] == sId).toList();
      final avgScore = studentAttempts.isNotEmpty
          ? (studentAttempts.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / studentAttempts.length).round()
          : 0;

      enriched.add({
        ...u,
        'enrolled_courses': studentEnrollments,
        'completed_los': studentProgress,
        'avg_score': avgScore,
        'attempts_count': studentAttempts.length,
      });
    }

    if (section != null && section.isNotEmpty && section != 'All') {
      enriched = enriched.where((s) => (s['section'] as String? ?? 'Unassigned') == section).toList();
    }
    if (grade != null && grade.isNotEmpty && grade != 'All') {
      enriched = enriched.where((s) => (s['grade'] as String? ?? '') == grade).toList();
    }
    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase().trim();
      enriched = enriched.where((s) {
        final name = (s['full_name'] as String? ?? '').toLowerCase();
        final email = (s['email'] as String? ?? '').toLowerCase();
        final sec = (s['section'] as String? ?? '').toLowerCase();
        return name.contains(q) || email.contains(q) || sec.contains(q);
      }).toList();
    }

    return enriched;
  }

  Future<void> updateStudentSection(String studentId, String section, {String? grade}) async {
    final db = await database;
    final Map<String, dynamic> updateData = {'section': section};
    if (grade != null && grade.isNotEmpty) {
      updateData['grade'] = grade;
    }
    await db.update('users', updateData, where: 'id = ?', whereArgs: [studentId]);
  }

  Future<List<String>> getAvailableSectionsList() async {
    final db = await database;
    final List<String> list = ['STEM A', 'STEM B', 'STEM C', 'Emerald', 'Ruby', 'Gold', 'Diamond'];
    try {
      final dbSections = await db.query('sections');
      for (final s in dbSections) {
        final name = s['name'] as String?;
        if (name != null && name.isNotEmpty && !list.contains(name)) {
          list.add(name);
        }
      }
    } catch (_) {}
    return list;
  }

  Future<void> generateEnrollmentKey({
    required String code,
    required String section,
    int maxUses = 50,
    String? expiration,
  }) async {
    final db = await database;
    await db.insert(
      'reg_links',
      {
        'code': code.trim().toUpperCase(),
        'section': section,
        'max_uses': maxUses,
        'used_count': 0,
        'expiration': expiration ?? '2026-12-31',
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getEnrollmentKeysList() async {
    final db = await database;
    return await db.query('reg_links', orderBy: 'created_at DESC');
  }

  Future<void> deleteEnrollmentKey(String code) async {
    final db = await database;
    await db.delete('reg_links', where: 'code = ?', whereArgs: [code]);
  }

  // ── Initial Starter Curriculum & Data Seeder ───────────────

  Future<void> _seedInitialData(Database db) async {
    try {
      await db.execute('ALTER TABLE reg_links ADD COLUMN section TEXT');
    } catch (_) {}

    // Ensure teacher role is properly set for teacher accounts
    try {
      await db.update('users', {'role': 'teacher'}, where: 'email = ?', whereArgs: ['john.reyes@deped.gov.ph']);
      final existingAdmin2 = await db.query('users', where: 'email = ?', whereArgs: ['admin@aira.edu']);
      if (existingAdmin2.isEmpty) {
        await db.insert('users', {
          'id': 'admin_2',
          'email': 'admin@aira.edu',
          'password': 'Admin@123',
          'role': 'admin',
          'full_name': 'School Administrator',
          'section': null,
          'grade': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    // Seed Announcements if empty
    final existingAnnouncements = await db.query('announcements');
    if (existingAnnouncements.isEmpty) {
      await db.insert('announcements', {
        'title': 'Welcome to 1st Semester A.Y. 2026-2027!',
        'message': 'All course learning outcomes, reading contents, and quizzes have been updated. Make sure to review your enrolled subjects and prepare for upcoming quizzes.',
        'priority': 'high',
        'target_audience': 'all',
        'created_at': DateTime.now().toIso8601String(),
      });
      await db.insert('announcements', {
        'title': 'Flutter & Dart Assessment Scheduled',
        'message': 'Topic assessments are now active. Students must achieve at least 70% passing score to complete each Learning Outcome.',
        'priority': 'medium',
        'target_audience': 'students',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      });
    }

    // Seed Subjects if empty
    final existingSubjects = await db.query('subjects');
    if (existingSubjects.isEmpty) {
      // Subject 1: CS101
      final cs101Id = await db.insert('subjects', {
        'name': 'Introduction to Flutter & Dart',
        'subject_code': 'CS101',
        'description': 'Master cross-platform mobile development with Flutter framework and the modern Dart language.',
        'grade_level': 'Grade 10',
        'semester': '1st Semester',
        'unlock_type': 'Sequential',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // Topic 1
      final topic1Id = await db.insert('topics', {
        'subject_id': cs101Id,
        'title': 'Topic 1: Dart Fundamentals & OOP',
        'description': 'Learn variables, functions, null safety, and object-oriented programming in Dart.',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // LO 1
      final lo1Id = await db.insert('learning_outcomes', {
        'topic_id': topic1Id,
        'title': 'Variables, Types, and Functions',
        'description': 'Understand variable declarations, data types, and functions in Dart.',
        'performance_criteria': 'Demonstrate knowledge of basic syntax and type declarations.',
        'passing_score': 70,
        'schedule_start': null,
        'schedule_end': null,
        'timezone': 'Asia/Manila',
        'allow_extend': 0,
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // Contents for LO 1
      await db.insert('contents', {
        'lo_id': lo1Id,
        'content_type': 'Text',
        'title': 'Dart Variables & Strong Typing',
        'content_data': 'Dart is a strongly typed language. While type annotation is optional because Dart can infer types with "var", types are known at compile time.\n\nKey Keywords:\n• var - mutable variable with inferred type\n• final - single-assignment variable known at runtime\n• const - compile-time constant',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
      await db.insert('contents', {
        'lo_id': lo1Id,
        'content_type': 'Text',
        'title': 'Functions & Shorthand Arrow Syntax',
        'content_data': 'Functions in Dart are first-class citizens. For functions with a single expression, Dart provides shorthand arrow syntax:\n\nint add(int a, int b) => a + b;\n\nNamed parameters can be wrapped in curly braces { } and can be marked as required.',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // Questions for LO 1
      await db.insert('questions', {
        'lo_id': lo1Id,
        'question_text': 'Which keyword is used to declare a variable whose value cannot be reassigned after initialization?',
        'option_a': 'final',
        'option_b': 'dynamic',
        'option_c': 'var',
        'option_d': 'static',
        'correct_option': 'A',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
      await db.insert('questions', {
        'lo_id': lo1Id,
        'question_text': 'What is the return type of a Dart function that performs an action but does not return any value?',
        'option_a': 'null',
        'option_b': 'void',
        'option_c': 'Nothing',
        'option_d': 'empty',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });
      await db.insert('questions', {
        'lo_id': lo1Id,
        'question_text': 'Which Dart collection stores an unordered group of unique values?',
        'option_a': 'List',
        'option_b': 'Set',
        'option_c': 'Map',
        'option_d': 'Queue',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      });

      // LO 2
      final lo2Id = await db.insert('learning_outcomes', {
        'topic_id': topic1Id,
        'title': 'Classes, Objects & Sound Null Safety',
        'description': 'Construct object classes and handle null safety responsibly.',
        'performance_criteria': 'Apply encapsulation and sound null safety in classes.',
        'passing_score': 70,
        'schedule_start': null,
        'schedule_end': null,
        'timezone': 'Asia/Manila',
        'allow_extend': 0,
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      await db.insert('contents', {
        'lo_id': lo2Id,
        'content_type': 'Text',
        'title': 'Null Safety in Dart',
        'content_data': 'Sound null safety prevents null reference exceptions. By default, types cannot be null.\n\nTo allow a variable to be null, append a question mark (?):\nString? optionalText;\n\nUse the null assertion operator (!) only when you are sure the value is not null.',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      await db.insert('questions', {
        'lo_id': lo2Id,
        'question_text': 'How do you specify that a variable of type String can hold a null value in Dart?',
        'option_a': 'String? text',
        'option_b': 'String! text',
        'option_c': 'nullable String text',
        'option_d': 'String text = null',
        'correct_option': 'A',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });
      await db.insert('questions', {
        'lo_id': lo2Id,
        'question_text': 'Which keyword is used in Dart to inherit methods and properties from a parent class?',
        'option_a': 'implements',
        'option_b': 'extends',
        'option_c': 'inherits',
        'option_d': 'with',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      // Topic 2
      final topic2Id = await db.insert('topics', {
        'subject_id': cs101Id,
        'title': 'Topic 2: Flutter Widget Tree & State',
        'description': 'Explore widgets, stateless vs stateful design, and user interaction.',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });

      // LO 3
      final lo3Id = await db.insert('learning_outcomes', {
        'topic_id': topic2Id,
        'title': 'Stateless vs Stateful Widgets',
        'description': 'Differentiate between immutable and mutable widgets.',
        'performance_criteria': 'Choose appropriate widget types based on state requirements.',
        'passing_score': 70,
        'schedule_start': null,
        'schedule_end': null,
        'timezone': 'Asia/Manila',
        'allow_extend': 0,
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });

      await db.insert('contents', {
        'lo_id': lo3Id,
        'content_type': 'Text',
        'title': 'StatelessWidget vs StatefulWidget',
        'content_data': 'A StatelessWidget never changes once created. Examples include Text, Icon, and Container.\n\nA StatefulWidget can change its appearance in response to user input or events using the setState() method.',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });

      await db.insert('questions', {
        'lo_id': lo3Id,
        'question_text': 'Which widget is best suited for displaying static content like text or icons that never changes?',
        'option_a': 'StatefulWidget',
        'option_b': 'StatelessWidget',
        'option_c': 'InheritedWidget',
        'option_d': 'AnimatedWidget',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });
      await db.insert('questions', {
        'lo_id': lo3Id,
        'question_text': 'What method must be called inside a State class to notify the framework to redraw the widget?',
        'option_a': 'redraw()',
        'option_b': 'setState()',
        'option_c': 'refresh()',
        'option_d': 'update()',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });

      // Subject 2: CS202
      final cs202Id = await db.insert('subjects', {
        'name': 'Mobile UI & State Management',
        'subject_code': 'CS202',
        'description': 'Advanced mobile UI development with Riverpod and responsive layout design.',
        'grade_level': 'Grade 10',
        'semester': '1st Semester',
        'unlock_type': 'Flexible',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      final topic3Id = await db.insert('topics', {
        'subject_id': cs202Id,
        'title': 'Topic 1: Modern State Management with Riverpod',
        'description': 'Learn reactive state patterns, providers, and notifiers.',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      final lo4Id = await db.insert('learning_outcomes', {
        'topic_id': topic3Id,
        'title': 'Riverpod Providers & Notifiers',
        'description': 'Build clean reactive Flutter state using Notifier and Provider.',
        'performance_criteria': 'Properly inject and watch providers without unnecessary rebuilds.',
        'passing_score': 75,
        'schedule_start': null,
        'schedule_end': null,
        'timezone': 'Asia/Manila',
        'allow_extend': 0,
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      await db.insert('contents', {
        'lo_id': lo4Id,
        'content_type': 'Text',
        'title': 'Understanding Riverpod',
        'content_data': 'Riverpod is a compile-safe reactive state management framework for Flutter and Dart. It does not depend on the Flutter widget tree to declare providers, avoiding common BuildContext issues.',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      await db.insert('questions', {
        'lo_id': lo4Id,
        'question_text': 'What widget must be placed at the root of a Flutter app to enable Riverpod providers?',
        'option_a': 'ProviderScope',
        'option_b': 'MultiProvider',
        'option_c': 'RiverpodApp',
        'option_d': 'MaterialAppScope',
        'correct_option': 'A',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });
      await db.insert('questions', {
        'lo_id': lo4Id,
        'question_text': 'Which method on WidgetRef is used in build() to listen to a provider and trigger rebuilds on state change?',
        'option_a': 'ref.read',
        'option_b': 'ref.watch',
        'option_c': 'ref.listen',
        'option_d': 'ref.refresh',
        'correct_option': 'B',
        'created_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      });

      // Pre-enroll student_1 (Maria Lopez) in CS101 and seed an initial quiz attempt
      await db.insert('enrollments', {
        'student_id': 'student_1',
        'subject_id': cs101Id,
        'enrolled_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        'status': 'active',
      });

      // Record Maria\'s attempt for LO 1 (Score 3/3, 100%, passed)
      await db.insert('quiz_attempts', {
        'student_id': 'student_1',
        'lo_id': lo1Id,
        'subject_id': cs101Id,
        'score': 3,
        'total_questions': 3,
        'percentage': 100.0,
        'is_passed': 1,
        'duration_seconds': 145,
        'attempted_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });

      // Mark LO 1 completed for student_1
      await db.insert('student_progress', {
        'student_id': 'student_1',
        'lo_id': lo1Id,
        'subject_id': cs101Id,
        'is_completed': 1,
        'score': 3,
        'completed_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      });
    }

    // Seed Sections if empty
    try {
      final existingSections = await db.query('sections');
      if (existingSections.isEmpty) {
        await db.insert('sections', {
          'name': 'Grade 11 - STEM B',
          'description': 'STEM Strand Section B - Senior High',
          'grade': 'Grade 11',
          'room': 'Room 304 - Science Bldg',
          'student_count': 1,
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('sections', {
          'name': 'Grade 10 - Emerald',
          'description': 'Junior High Class Emerald',
          'grade': 'Grade 10',
          'room': 'Room 201 - Main Bldg',
          'student_count': 2,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (_) {}

    // Ensure initial subjects have assigned teacher
    try {
      await db.update(
        'subjects',
        {
          'teacher_id': 'teacher_1',
          'teacher_name': 'Sir John Reyes',
        },
        where: 'teacher_id IS NULL OR teacher_id = ?',
        whereArgs: [''],
      );
    } catch (_) {}
  }

  // ── Sections Management (Admin) ──────────────────────────
  Future<List<Map<String, dynamic>>> getSectionsList() async {
    final db = await database;
    return await db.query('sections', orderBy: 'id DESC');
  }

  Future<int> insertSection(Map<String, dynamic> section) async {
    final db = await database;
    return await db.insert('sections', section);
  }

  Future<int> updateSection(int id, Map<String, dynamic> section) async {
    final db = await database;
    return await db.update('sections', section, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteSection(int id) async {
    final db = await database;
    return await db.delete('sections', where: 'id = ?', whereArgs: [id]);
  }

  // ── Teachers & Subject Assignment ────────────────────────
  Future<List<Map<String, dynamic>>> getTeachersList() async {
    final db = await database;
    return await db.query(
      'users',
      columns: ['id', 'email', 'full_name', 'role'],
      where: 'role = ?',
      whereArgs: ['teacher'],
      orderBy: 'full_name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getSubjectsForTeacher(String teacherId) async {
    final db = await database;
    return await db.query(
      'subjects',
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
      orderBy: 'id DESC',
    );
  }

  Future<int> assignTeacherToSubject(int subjectId, String teacherId, String teacherName) async {
    final db = await database;
    return await db.update(
      'subjects',
      {
        'teacher_id': teacherId,
        'teacher_name': teacherName,
      },
      where: 'id = ?',
      whereArgs: [subjectId],
    );
  }
}

