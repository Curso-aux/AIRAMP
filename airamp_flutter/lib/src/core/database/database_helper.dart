import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import '../utils/section_key_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  // ── Password Hashing & Security Helpers ───────────────────
  static String generateSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  static String hashPassword(String password, String salt) {
    if (salt.isEmpty) return password;
    final bytes = utf8.encode('$password::$salt');
    return sha256.convert(bytes).toString();
  }

  static bool verifyPassword(String password, String storedHash, String? salt) {
    if (salt == null || salt.isEmpty) {
      return password == storedHash;
    }
    final computed = hashPassword(password, salt);
    return computed == storedHash;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> _onDatabaseOpen(Database db) async {
    try {
      await db.execute('PRAGMA busy_timeout = 10000');
    } catch (_) {}
    if (!kIsWeb) {
      try {
        await db.execute('PRAGMA journal_mode = WAL');
      } catch (_) {}
    }
    try {
      await db.execute('ALTER TABLE announcements ADD COLUMN section TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE announcements ADD COLUMN author_id TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE announcements ADD COLUMN author_name TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE announcements ADD COLUMN author_role TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN password_salt TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE users ADD COLUMN student_type TEXT DEFAULT 'regular'");
    } catch (_) {}
    try {
      await db.execute("ALTER TABLE users ADD COLUMN special_notes TEXT");
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE sections ADD COLUMN enrollment_key TEXT');
    } catch (_) {}
    await _seedInitialData(db);
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      try {
        databaseFactory = databaseFactoryFfiWeb;
        return await openDatabase(
          'airamp_local.db',
          version: 20,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: _onDatabaseOpen,
        );
      } catch (e) {
        debugPrint('Failed to open with shared worker, falling back to databaseFactoryFfiWebNoWebWorker: $e');
        databaseFactory = databaseFactoryFfiWebNoWebWorker;
        return await openDatabase(
          'airamp_local.db',
          version: 20,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
          onOpen: _onDatabaseOpen,
        );
      }
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'airamp_local.db');

    return await openDatabase(
      path,
      version: 20,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: _onDatabaseOpen,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Users Table
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        username TEXT,
        password TEXT NOT NULL,
        password_salt TEXT,
        role TEXT NOT NULL,
        full_name TEXT NOT NULL,
        section TEXT,
        grade TEXT,
        student_type TEXT DEFAULT 'regular',
        special_notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    final saltAdmin1 = generateSalt();
    final saltAdmin2 = generateSalt();
    final saltTeacher1 = generateSalt();
    final saltStudent1 = generateSalt();

    // Seed default authentic accounts with salted hashes
    await db.insert('users', {
      'id': 'admin_1',
      'email': 'aira@admin',
      'username': 'Aira Admin',
      'password': hashPassword('aira@admin', saltAdmin1),
      'password_salt': saltAdmin1,
      'role': 'super_admin',
      'full_name': 'Aira Admin',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'admin_2',
      'email': 'admin@aira.edu',
      'username': 'admin',
      'password': hashPassword('Admin@123', saltAdmin2),
      'password_salt': saltAdmin2,
      'role': 'admin',
      'full_name': 'School Administrator',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'teacher_1',
      'email': 'john.reyes@deped.gov.ph',
      'username': 'john.reyes',
      'password': hashPassword('John@123', saltTeacher1),
      'password_salt': saltTeacher1,
      'role': 'teacher',
      'full_name': 'Sir John Reyes',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'student_1',
      'email': 'maria@test.com',
      'username': 'maria.lopez',
      'password': hashPassword('Maria@123', saltStudent1),
      'password_salt': saltStudent1,
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
        section TEXT,
        author_id TEXT,
        author_name TEXT,
        author_role TEXT,
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
        lo_id INTEGER,
        quiz_id INTEGER,
        question_text TEXT NOT NULL,
        option_a TEXT NOT NULL,
        option_b TEXT NOT NULL,
        option_c TEXT NOT NULL,
        option_d TEXT NOT NULL,
        correct_option TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lo_id) REFERENCES learning_outcomes (id) ON DELETE CASCADE,
        FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE
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
        enrollment_key TEXT,
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

    // Quizzes Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quizzes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        subject_id INTEGER NOT NULL,
        lo_id INTEGER,
        teacher_id TEXT NOT NULL,
        teacher_name TEXT,
        time_limit_minutes INTEGER DEFAULT 0,
        passing_score INTEGER DEFAULT 70,
        status TEXT DEFAULT 'published',
        due_date TEXT,
        schedule_start TEXT,
        schedule_end TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // Quiz Assignments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_id INTEGER NOT NULL,
        student_id TEXT NOT NULL,
        assigned_at TEXT NOT NULL,
        due_date TEXT,
        status TEXT DEFAULT 'pending',
        score INTEGER DEFAULT 0,
        total_questions INTEGER DEFAULT 0,
        percentage REAL DEFAULT 0.0,
        completed_at TEXT,
        UNIQUE(quiz_id, student_id),
        FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    // Quiz Attempts Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quiz_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        student_id TEXT NOT NULL,
        lo_id INTEGER,
        quiz_id INTEGER,
        subject_id INTEGER NOT NULL,
        score INTEGER NOT NULL,
        total_questions INTEGER NOT NULL,
        percentage REAL NOT NULL,
        is_passed INTEGER NOT NULL,
        duration_seconds INTEGER,
        attempted_at TEXT NOT NULL
      )
    ''');

    // Assignments Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS assignments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        subject_id INTEGER NOT NULL,
        teacher_id TEXT NOT NULL,
        teacher_name TEXT,
        due_date TEXT,
        total_points INTEGER DEFAULT 100,
        submission_type TEXT DEFAULT 'both',
        status TEXT DEFAULT 'active',
        created_at TEXT NOT NULL,
        FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
      )
    ''');

    // Submissions Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS submissions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assignment_id INTEGER NOT NULL,
        student_id TEXT NOT NULL,
        student_name TEXT,
        submission_type TEXT NOT NULL DEFAULT 'link',
        content_link TEXT,
        file_name TEXT,
        file_size INTEGER,
        file_path TEXT,
        notes TEXT,
        submitted_at TEXT NOT NULL,
        status TEXT DEFAULT 'submitted',
        grade REAL,
        feedback TEXT,
        graded_at TEXT,
        graded_by TEXT,
        UNIQUE(assignment_id, student_id),
        FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
        FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
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
          'role': 'teacher',
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

    if (oldVersion < 16) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS quizzes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          subject_id INTEGER NOT NULL,
          lo_id INTEGER,
          teacher_id TEXT NOT NULL,
          teacher_name TEXT,
          time_limit_minutes INTEGER DEFAULT 0,
          passing_score INTEGER DEFAULT 70,
          status TEXT DEFAULT 'published',
          due_date TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS quiz_assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          quiz_id INTEGER NOT NULL,
          student_id TEXT NOT NULL,
          assigned_at TEXT NOT NULL,
          due_date TEXT,
          status TEXT DEFAULT 'pending',
          score INTEGER DEFAULT 0,
          total_questions INTEGER DEFAULT 0,
          percentage REAL DEFAULT 0.0,
          completed_at TEXT,
          UNIQUE(quiz_id, student_id),
          FOREIGN KEY (quiz_id) REFERENCES quizzes (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute('ALTER TABLE questions ADD COLUMN quiz_id INTEGER');
      } catch (_) {}

      try {
        await db.execute('ALTER TABLE quiz_attempts ADD COLUMN quiz_id INTEGER');
      } catch (_) {}

      await _seedInitialData(db);
    }

    if (oldVersion < 17) {
      try {
        await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
      } catch (_) {}
      await _seedInitialData(db);
    }

    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN schedule_start TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN schedule_end TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE quizzes ADD COLUMN status TEXT DEFAULT \'published\'');
      } catch (_) {}
      await _seedInitialData(db);
    }

    if (oldVersion < 20) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS assignments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          description TEXT,
          subject_id INTEGER NOT NULL,
          teacher_id TEXT NOT NULL,
          teacher_name TEXT,
          due_date TEXT,
          total_points INTEGER DEFAULT 100,
          submission_type TEXT DEFAULT 'both',
          status TEXT DEFAULT 'active',
          created_at TEXT NOT NULL,
          FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS submissions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          assignment_id INTEGER NOT NULL,
          student_id TEXT NOT NULL,
          student_name TEXT,
          submission_type TEXT NOT NULL DEFAULT 'link',
          content_link TEXT,
          file_name TEXT,
          file_size INTEGER,
          file_path TEXT,
          notes TEXT,
          submitted_at TEXT NOT NULL,
          status TEXT DEFAULT 'submitted',
          grade REAL,
          feedback TEXT,
          graded_at TEXT,
          graded_by TEXT,
          UNIQUE(assignment_id, student_id),
          FOREIGN KEY (assignment_id) REFERENCES assignments (id) ON DELETE CASCADE,
          FOREIGN KEY (student_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

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
    if (conversationId.startsWith('dm_')) {
      final parts = conversationId.substring(3).split('_');
      String? altId;
      if (parts.length == 4 && parts[0] == 'teacher' && parts[2] == 'student') {
        altId = 'dm_student_${parts[3]}_teacher_${parts[1]}';
      } else if (parts.length == 4 && parts[0] == 'student' && parts[2] == 'teacher') {
        altId = 'dm_teacher_${parts[3]}_student_${parts[1]}';
      }
      if (altId != null) {
        return await db.query(
          'messages',
          where: 'conversation_id = ? OR conversation_id = ?',
          whereArgs: [conversationId, altId],
          orderBy: 'created_at ASC',
        );
      }
    }
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

  Future<void> markMessagesAsRead(String conversationId, {String? excludeSenderId}) async {
    final db = await database;
    if (excludeSenderId != null) {
      await db.update(
        'messages',
        {'is_read': 1},
        where: 'conversation_id = ? AND sender_id != ? AND is_read = 0',
        whereArgs: [conversationId, excludeSenderId],
      );
    } else {
      await db.update(
        'messages',
        {'is_read': 1},
        where: 'conversation_id = ? AND is_read = 0',
        whereArgs: [conversationId],
      );
    }
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
    final ids = [userId1, userId2]..sort();
    final canonicalId = 'dm_${ids[0]}_${ids[1]}';
    final id1 = 'dm_${userId1}_$userId2';
    final id2 = 'dm_${userId2}_$userId1';
    final res = await db.query(
      'conversations',
      where: 'id = ? OR id = ? OR id = ?',
      whereArgs: [canonicalId, id1, id2],
      limit: 1,
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> normalizeDirectConversations() async {
    final db = await database;
    final rows = await db.query('conversations', where: "id LIKE 'dm_%'");
    final userRows = await db.query('users');
    final userIds = userRows.map((u) => u['id'] as String).toList();

    for (final row in rows) {
      final id = row['id'] as String;
      final matchingUsers = userIds.where((uId) => id.contains(uId)).toList();
      if (matchingUsers.length == 2) {
        final sorted = [matchingUsers[0], matchingUsers[1]]..sort();
        final canonicalId = 'dm_${sorted[0]}_${sorted[1]}';
        if (id != canonicalId) {
          final existingCanonical = await db.query('conversations', where: 'id = ?', whereArgs: [canonicalId]);
          if (existingCanonical.isEmpty) {
            await db.update('conversations', {'id': canonicalId}, where: 'id = ?', whereArgs: [id]);
          } else {
            await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
          }
          await db.update('messages', {'conversation_id': canonicalId}, where: 'conversation_id = ?', whereArgs: [id]);
        }
      }
    }
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

  /// Verify an admin-provided section key.
  /// Returns section info and all matching curriculum subjects with teachers.
  Future<Map<String, dynamic>?> verifySectionKey(String rawKey) async {
    final db = await database;
    final trimmedKey = rawKey.trim();
    if (trimmedKey.isEmpty) return null;

    final keyUpper = trimmedKey.toUpperCase();

    // 1. Check sections table by enrollment_key or name
    final secResults = await db.rawQuery('''
      SELECT * FROM sections
      WHERE UPPER(COALESCE(enrollment_key, '')) = ?
         OR UPPER(name) = ?
         OR UPPER(name) LIKE ?
      ORDER BY id DESC
    ''', [keyUpper, keyUpper, '%$keyUpper%']);

    Map<String, dynamic>? section;
    if (secResults.isNotEmpty) {
      section = Map<String, dynamic>.from(secResults.first);
    } else {
      // 2. Check reg_links table as fallback
      final linkResults = await db.rawQuery('''
        SELECT * FROM reg_links WHERE UPPER(code) = ?
      ''', [keyUpper]);
      if (linkResults.isNotEmpty) {
        final secName = linkResults.first['section'] as String?;
        if (secName != null && secName.isNotEmpty) {
          final matchedSec = await db.rawQuery('''
            SELECT * FROM sections WHERE UPPER(name) = ?
          ''', [secName.toUpperCase()]);
          if (matchedSec.isNotEmpty) {
            section = Map<String, dynamic>.from(matchedSec.first);
          } else {
            section = {
              'name': secName,
              'grade': 'Grade 10',
              'room': 'Assigned Room',
              'description': 'Curriculum Section',
              'enrollment_key': keyUpper,
            };
          }
        }
      }
    }

    if (section == null) return null;

    final grade = section['grade']?.toString() ?? '';
    final sectionName = section['name']?.toString() ?? '';

    // 3. Find subjects associated with this section / grade level
    List<Map<String, dynamic>> matchingSubjects = [];
    if (grade.isNotEmpty) {
      matchingSubjects = await db.query(
        'subjects',
        where: 'LOWER(grade_level) = LOWER(?)',
        whereArgs: [grade],
        orderBy: 'id ASC',
      );
    }

    // If no subjects match exact grade level, load all available subjects
    if (matchingSubjects.isEmpty) {
      matchingSubjects = await db.query(
        'subjects',
        orderBy: 'id ASC',
      );
    }

    // Ensure subjects have teacher names attached
    final List<Map<String, dynamic>> enrichedSubjects = [];
    for (final s in matchingSubjects) {
      final tName = s['teacher_name']?.toString();
      enrichedSubjects.add({
        ...s,
        'teacher_name': (tName != null && tName.isNotEmpty) ? tName : 'Sir John Reyes',
        'room': section['room'] ?? 'Main Campus',
        'section_name': sectionName,
      });
    }

    return {
      'section': section,
      'subjects': enrichedSubjects,
    };
  }

  /// Enrolls a student into a section via the admin-issued key,
  /// updating user record and linking all section curriculum subjects.
  Future<bool> enrollStudentBySectionKey(String studentId, String rawKey) async {
    final db = await database;
    final verified = await verifySectionKey(rawKey);
    if (verified == null) return false;

    final section = verified['section'] as Map<String, dynamic>;
    final subjects = verified['subjects'] as List<Map<String, dynamic>>;

    final sectionName = section['name']?.toString() ?? '';
    final grade = section['grade']?.toString() ?? '';

    // 1. Update user record with section and grade
    await db.update(
      'users',
      {
        'section': sectionName,
        'grade': grade,
      },
      where: 'id = ?',
      whereArgs: [studentId],
    );

    // 2. Increment student_count in sections if section ID exists
    final secId = section['id'];
    if (secId is int) {
      await db.rawUpdate(
        'UPDATE sections SET student_count = student_count + 1 WHERE id = ?',
        [secId],
      );
    }
    // Also increment used_count in reg_links if matching key exists
    await db.rawUpdate(
      'UPDATE reg_links SET used_count = used_count + 1 WHERE code = ?',
      [rawKey.trim().toUpperCase()],
    );

    // 3. Clear old enrollments for this student and enroll in all section subjects
    await db.delete('enrollments', where: 'student_id = ?', whereArgs: [studentId]);
    final now = DateTime.now().toIso8601String();
    for (final s in subjects) {
      final subId = s['id'] as int;
      await db.insert(
        'enrollments',
        {
          'student_id': studentId,
          'subject_id': subId,
          'enrolled_at': now,
          'status': 'active',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    return true;
  }

  /// Get section details for the given student
  Future<Map<String, dynamic>?> getSectionDetailsForStudent(String studentId) async {
    final db = await database;
    final userRes = await db.query('users', where: 'id = ?', whereArgs: [studentId]);
    if (userRes.isEmpty) return null;

    final user = userRes.first;
    final sectionName = user['section']?.toString() ?? '';
    if (sectionName.isEmpty) return null;

    final secRes = await db.query(
      'sections',
      where: 'LOWER(name) = LOWER(?)',
      whereArgs: [sectionName],
    );

    if (secRes.isNotEmpty) {
      return Map<String, dynamic>.from(secRes.first);
    }

    // Fallback: search partial match
    final partialSec = await db.query(
      'sections',
      where: 'LOWER(name) LIKE ?',
      whereArgs: ['%${sectionName.toLowerCase()}%'],
    );
    if (partialSec.isNotEmpty) {
      return Map<String, dynamic>.from(partialSec.first);
    }

    return {
      'name': sectionName,
      'grade': user['grade'] ?? 'Grade 10',
      'room': 'Room 201 - Main Bldg',
      'enrollment_key': 'SEC-EMR10',
      'description': 'Student Class Section',
    };
  }

  /// Leave or unenroll from section
  Future<void> leaveSectionForStudent(String studentId) async {
    final db = await database;
    await db.update(
      'users',
      {'section': null, 'grade': null},
      where: 'id = ?',
      whereArgs: [studentId],
    );
    await db.delete('enrollments', where: 'student_id = ?', whereArgs: [studentId]);
  }

  // ── Student Quiz Attempt Validation ───────────────────────

  /// Check if a student has already completed a specific quiz
  /// Returns true if student has NOT completed the quiz, false if already completed
  Future<bool> hasStudentCompletedQuiz({
    required String studentId,
    required int quizId,
  }) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT COUNT(*) as count
      FROM quiz_attempts
      WHERE student_id = ? AND quiz_id = ? AND quiz_id IS NOT NULL
    ''', [studentId, quizId]);

    return (results.first['count'] as int) == 0;
  }

  /// Get the latest quiz attempt status for a student on a specific quiz
  /// Returns a map with attempt status information
  Future<Map<String, dynamic>> getStudentQuizAttemptStatus({
    required String studentId,
    required int quizId,
  }) async {
    final db = await database;
    final attempts = await db.rawQuery('''
      SELECT * FROM quiz_attempts
      WHERE student_id = ? AND quiz_id = ? AND quiz_id IS NOT NULL
      ORDER BY attempted_at DESC LIMIT 1
    ''', [studentId, quizId]);

    if (attempts.isEmpty) {
      return {
        'canAttempt': true,
        'attemptsCount': 0,
        'lastAttempt': null,
        'lastScore': null,
        'lastPercentage': null,
        'lastPassed': null,
      };
    }

    final attempt = attempts.first;
    return {
      'canAttempt': false,
      'attemptsCount': await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM quiz_attempts
        WHERE student_id = ? AND quiz_id = ? AND quiz_id IS NOT NULL
      ''', [studentId, quizId]),
      'lastAttempt': attempt['attempted_at'],
      'lastScore': attempt['score'],
      'lastPercentage': attempt['percentage'],
      'lastPassed': attempt['is_passed'] == 1,
    };
  }

  /// Get the current quiz assignment status for a student
  Future<Map<String, dynamic>?> getStudentQuizAssignment({
    required String studentId,
    required int quizId,
  }) async {
    final db = await database;
    final assignments = await db.query(
      'quiz_assignments',
      where: 'student_id = ? AND quiz_id = ?',
      whereArgs: [studentId, quizId],
    );

    if (assignments.isEmpty) return null;
    return assignments.first;
  }

  /// Teacher reset functionality - clear all quiz attempts for a specific student
  Future<void> resetStudentQuizAttempts({
    required int quizId,
    required String studentId,
  }) async {
    final db = await database;
    await db.delete(
      'quiz_attempts',
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );

    // Reset assignment status
    await db.update(
      'quiz_assignments',
      {
        'status': 'pending',
        'score': 0,
        'percentage': 0.0,
        'completed_at': null,
      },
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );
  }

  Future<void> recordQuizAttempt({
    required String studentId,
    required int loId,
    int? quizId,
    required int subjectId,
    required int score,
    required int totalQuestions,
    required double percentage,
    required bool isPassed,
    int durationSeconds = 0,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    // Validate quiz attempt - check if student already completed
    if (quizId != null && quizId > 0) {
      final canAttempt = await hasStudentCompletedQuiz(studentId: studentId, quizId: quizId);
      if (!canAttempt) {
        throw Exception('Student has already completed this quiz. Contact the teacher for a reset if needed.');
      }
    }

    await db.insert('quiz_attempts', {
      'student_id': studentId,
      'lo_id': loId,
      'quiz_id': quizId,
      'subject_id': subjectId,
      'score': score,
      'total_questions': totalQuestions,
      'percentage': percentage,
      'is_passed': isPassed ? 1 : 0,
      'duration_seconds': durationSeconds,
      'attempted_at': now,
    });

    if (quizId != null && quizId > 0) {
      await completeQuizAssignment(
        quizId: quizId,
        studentId: studentId,
        score: score,
        totalQuestions: totalQuestions,
        percentage: percentage,
      );
    }

    if (isPassed && loId > 0) {
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

  /// Get comprehensive attempt statistics for a quiz (teacher perspective)
  Future<List<Map<String, dynamic>>> getQuizAttemptStats({
    required int quizId,
  }) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT
        qa.*,
        u.full_name as student_name,
        u.email as student_email,
        CASE
          WHEN qa.score >= q.passing_score THEN 'Passed'
          ELSE 'Failed'
        END as result,
        strftime('%Y-%m-%d %H:%M:%S', qa.attempted_at) as formatted_attempt_time
      FROM quiz_attempts qa
      JOIN users u ON qa.student_id = u.id
      JOIN quizzes q ON qa.quiz_id = q.id
      WHERE qa.quiz_id = ?
      ORDER BY qa.attempted_at DESC
    ''', [quizId]);
  }

  Future<List<Map<String, dynamic>>> getStudentQuizAttempts(String studentId, {int? subjectId}) async {
    final db = await database;
    if (subjectId != null) {
      return await db.rawQuery('''
        SELECT qa.*, 
               s.name as subject_name, 
               s.subject_code, 
               COALESCE(qz.title, lo.title, 'Quiz Assessment') as lo_title, 
               COALESCE(qz.passing_score, lo.passing_score, 70) as passing_score
        FROM quiz_attempts qa
        JOIN subjects s ON qa.subject_id = s.id
        LEFT JOIN learning_outcomes lo ON qa.lo_id = lo.id
        LEFT JOIN quizzes qz ON qa.quiz_id = qz.id
        WHERE qa.student_id = ? AND qa.subject_id = ?
        ORDER BY qa.attempted_at DESC
      ''', [studentId, subjectId]);
    }
    return await db.rawQuery('''
      SELECT qa.*, 
             s.name as subject_name, 
             s.subject_code, 
             COALESCE(qz.title, lo.title, 'Quiz Assessment') as lo_title, 
             COALESCE(qz.passing_score, lo.passing_score, 70) as passing_score
      FROM quiz_attempts qa
      JOIN subjects s ON qa.subject_id = s.id
      LEFT JOIN learning_outcomes lo ON qa.lo_id = lo.id
      LEFT JOIN quizzes qz ON qa.quiz_id = qz.id
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

  /// Load existing quiz data for editing (includes questions, assignments)
  Future<Map<String, dynamic>?> getQuizForEditing(int quizId) async {
    final db = await database;

    // Load quiz metadata
    final quizzes = await db.query('quizzes', where: 'id = ?', whereArgs: [quizId]);
    if (quizzes.isEmpty) return null;

    final quiz = quizzes.first;

    // Load related questions
    final questions = await db.query(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'id ASC',
    );

    // Load assigned students
    final assignments = await db.query(
      'quiz_assignments',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
    );

    // Load assigned student IDs for selection
    final assignedStudentIds = assignments
        .map((a) => a['student_id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    return {
      ...quiz,
      'questions': questions,
      'assigned_student_ids': assignedStudentIds,
      'assignment_count': assignments.length,
    };
  }

  /// Update quiz student assignments (clear old and add new)
  Future<void> updateQuizAssignments({
    required int quizId,
    required List<String> studentIds,
    String? dueDate,
  }) async {
    final db = await database;

    // Clear existing assignments for this quiz
    await db.delete('quiz_assignments', where: 'quiz_id = ?', whereArgs: [quizId]);

    // Add updated assignments
    for (final studentId in studentIds) {
      await db.insert('quiz_assignments', {
        'quiz_id': quizId,
        'student_id': studentId,
        'assigned_at': DateTime.now().toIso8601String(),
        'due_date': dueDate,
        'status': 'pending',
        'score': 0,
        'total_questions': 0,
        'percentage': 0.0,
        'completed_at': null,
      });
    }
  }

  /// Update an existing quiz with new data
  Future<void> updateQuiz({
    required int quizId,
    required String title,
    String? description,
    required int subjectId,
    required int timeLimitMinutes,
    required int passingScore,
    String? status,
    String? dueDate,
    String? scheduleStart,
    String? scheduleEnd,
    required List<Map<String, dynamic>> questions,
  }) async {
    final db = await database;

    // Update quiz basic info
    await db.update(
      'quizzes',
      {
        'title': title.trim(),
        'description': description?.trim(),
        'subject_id': subjectId,
        'time_limit_minutes': timeLimitMinutes,
        'passing_score': passingScore,
        'status': status ?? 'published',
        'due_date': dueDate,
        'schedule_start': scheduleStart,
        'schedule_end': scheduleEnd,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [quizId],
    );

    // Clear old questions for this quiz
    await db.delete('questions', where: 'quiz_id = ?', whereArgs: [quizId]);

    // Insert updated questions
    for (final q in questions) {
      await db.insert('questions', {
        ...q,
        'quiz_id': quizId,
      });
    }
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
             COALESCE(qz.title, lo.title, 'Quiz Assessment') as lo_title, 
             COALESCE(qz.passing_score, lo.passing_score, 70) as passing_score
      FROM quiz_attempts qa
      JOIN users u ON qa.student_id = u.id
      JOIN subjects s ON qa.subject_id = s.id
      LEFT JOIN learning_outcomes lo ON qa.lo_id = lo.id
      LEFT JOIN quizzes qz ON qa.quiz_id = qz.id
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
        'student_type': (u['student_type'] as String?)?.isNotEmpty == true ? u['student_type'] : 'regular',
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

  Future<void> updateStudentClassification(String studentId, String studentType, {String? notes}) async {
    final db = await database;
    final Map<String, dynamic> updateData = {'student_type': studentType};
    if (notes != null) {
      updateData['special_notes'] = notes;
    }
    await db.update('users', updateData, where: 'id = ?', whereArgs: [studentId]);
  }

  /// Bulk import students and faculty members with atomic validation,
  /// password salting, section mapping, and automated course enrollment.
  Future<Map<String, dynamic>> bulkImportUsers(List<Map<String, dynamic>> usersToImport) async {
    final db = await database;
    int successCount = 0;
    final List<Map<String, dynamic>> errors = [];
    final List<Map<String, dynamic>> insertedUsers = [];

    // Pre-fetch existing emails and sections
    final existingUsers = await db.query('users', columns: ['email']);
    final Set<String> existingEmails = existingUsers
        .map((u) => (u['email'] as String? ?? '').toLowerCase().trim())
        .where((e) => e.isNotEmpty)
        .toSet();

    final sections = await db.query('sections');
    final Map<String, Map<String, dynamic>> sectionMap = {};
    for (final s in sections) {
      final name = (s['name'] as String? ?? '').trim().toLowerCase();
      if (name.isNotEmpty) {
        sectionMap[name] = s;
      }
    }

    final now = DateTime.now();

    for (int i = 0; i < usersToImport.length; i++) {
      final row = usersToImport[i];
      final fullName = (row['full_name'] as String? ?? '').trim();
      final email = (row['email'] as String? ?? '').trim().toLowerCase();
      final rawRole = (row['role'] as String? ?? '').trim().toLowerCase();
      final role = (rawRole == 'teacher' || rawRole == 'admin' || rawRole == 'super_admin') ? rawRole : 'student';
      final rawSection = (row['section'] as String? ?? '').trim();
      final rawGrade = (row['grade'] as String? ?? '').trim();
      final studentType = (row['student_type'] as String? ?? 'regular').trim().toLowerCase();
      final specialNotes = (row['special_notes'] as String? ?? '').trim();
      final rawPassword = (row['password'] as String? ?? '').trim();

      // Validation
      if (fullName.isEmpty) {
        errors.add({'row': i + 1, 'email': email, 'reason': 'Missing full name'});
        continue;
      }
      if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
        errors.add({'row': i + 1, 'email': email, 'reason': 'Invalid email address format'});
        continue;
      }
      if (existingEmails.contains(email)) {
        errors.add({'row': i + 1, 'email': email, 'reason': 'Email already registered in system'});
        continue;
      }

      // Resolve section and grade
      String resolvedSection = rawSection;
      String resolvedGrade = rawGrade;

      if (rawSection.isNotEmpty) {
        final secLower = rawSection.toLowerCase();
        Map<String, dynamic>? matchedSection = sectionMap[secLower];
        if (matchedSection == null) {
          for (final entry in sectionMap.entries) {
            if (entry.key.contains(secLower) || secLower.contains(entry.key)) {
              matchedSection = entry.value;
              break;
            }
          }
        }

        if (matchedSection != null) {
          resolvedSection = matchedSection['name'] as String? ?? rawSection;
          if (resolvedGrade.isEmpty) {
            resolvedGrade = matchedSection['grade'] as String? ?? '';
          }
        }
      }

      final userId = '${role}_${now.millisecondsSinceEpoch}_$i';
      final defaultPass = rawPassword.isNotEmpty
          ? rawPassword
          : (role == 'teacher' ? 'Teacher@123' : 'Student@123');
      final salt = generateSalt();
      final hashedPassword = hashPassword(defaultPass, salt);
      final username = email.split('@').first;

      final userRecord = <String, dynamic>{
        'id': userId,
        'email': email,
        'username': username,
        'password': hashedPassword,
        'password_salt': salt,
        'role': role,
        'full_name': fullName,
        'section': resolvedSection.isNotEmpty ? resolvedSection : null,
        'grade': resolvedGrade.isNotEmpty ? resolvedGrade : null,
        'student_type': studentType.isNotEmpty ? studentType : 'regular',
        'special_notes': specialNotes.isNotEmpty ? specialNotes : null,
        'created_at': now.toIso8601String(),
      };

      try {
        await db.insert('users', userRecord);
        existingEmails.add(email); // Prevent duplicates within same import batch
        insertedUsers.add(userRecord);
        successCount++;

        // Auto-enroll if student with assigned section
        if (role == 'student' && resolvedSection.isNotEmpty) {
          await autoEnrollStudentBySection(userId, resolvedSection, resolvedGrade);
          await db.rawUpdate(
            'UPDATE sections SET student_count = student_count + 1 WHERE LOWER(name) = ?',
            [resolvedSection.toLowerCase()],
          );
        }
      } catch (e) {
        errors.add({'row': i + 1, 'email': email, 'reason': 'Database error: $e'});
      }
    }

    return {
      'total': usersToImport.length,
      'successCount': successCount,
      'failedCount': errors.length,
      'errors': errors,
      'insertedUsers': insertedUsers,
    };
  }

  Future<List<String>> getAvailableSectionsList() async {
    final db = await database;
    try {
      final dbSections = await db.query('sections', orderBy: 'grade ASC, name ASC');
      final list = <String>[];
      for (final s in dbSections) {
        final name = s['name'] as String?;
        if (name != null && name.trim().isNotEmpty && !list.contains(name.trim())) {
          list.add(name.trim());
        }
      }
      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}
    return ['Grade 10 - Emerald', 'Grade 11 - STEM B'];
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
    try {
      final rows = await db.query('reg_links', orderBy: 'created_at DESC');
      final sections = await db.query('sections');
      final Map<String, String> sectionGradeMap = {};
      for (final s in sections) {
        final sName = (s['name'] as String?)?.trim().toLowerCase();
        final sGrade = (s['grade'] as String?)?.trim();
        if (sName != null && sGrade != null && sGrade.isNotEmpty) {
          sectionGradeMap[sName] = sGrade;
        }
      }

      return rows.map((r) {
        final secName = (r['section'] as String?)?.trim() ?? '';
        String? resolvedGrade = sectionGradeMap[secName.toLowerCase()];
        if (resolvedGrade == null || resolvedGrade.isEmpty) {
          resolvedGrade = SectionKeyHelper.extractGradeFromSection(secName);
        }
        return {
          ...r,
          'grade': resolvedGrade,
        };
      }).toList();
    } catch (_) {
      return await db.query('reg_links', orderBy: 'created_at DESC');
    }
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
    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}

    // Ensure super admin account exists with username, email, and credentials
    try {
      final existingAdmin1 = await db.query('users', where: 'email = ?', whereArgs: ['aira@admin']);
      final saltAdmin1 = generateSalt();
      if (existingAdmin1.isEmpty) {
        await db.insert('users', {
          'id': 'admin_1',
          'email': 'aira@admin',
          'password': hashPassword('aira@admin', saltAdmin1),
          'password_salt': saltAdmin1,
          'role': 'super_admin',
          'full_name': 'Aira Admin',
          'username': 'Aira Admin',
          'section': null,
          'grade': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        final currentSalt = existingAdmin1.first['password_salt'] as String?;
        final currentPass = existingAdmin1.first['password'] as String?;
        if (currentSalt == null || currentSalt.isEmpty || currentPass == 'aira@admin') {
          await db.update('users', {
            'username': 'Aira Admin',
            'full_name': 'Aira Admin',
            'password': hashPassword('aira@admin', saltAdmin1),
            'password_salt': saltAdmin1,
            'role': 'super_admin',
          }, where: 'email = ?', whereArgs: ['aira@admin']);
        }
      }
    } catch (_) {}

    // Ensure admin_2 has username & hashed password
    try {
      final existingAdmin2 = await db.query('users', where: 'email = ?', whereArgs: ['admin@aira.edu']);
      final saltAdmin2 = generateSalt();
      if (existingAdmin2.isEmpty) {
        await db.insert('users', {
          'id': 'admin_2',
          'email': 'admin@aira.edu',
          'password': hashPassword('Admin@123', saltAdmin2),
          'password_salt': saltAdmin2,
          'role': 'admin',
          'full_name': 'School Administrator',
          'username': 'admin',
          'section': null,
          'grade': null,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        final currentSalt = existingAdmin2.first['password_salt'] as String?;
        final currentPass = existingAdmin2.first['password'] as String?;
        if (currentSalt == null || currentSalt.isEmpty || currentPass == 'Admin@123') {
          await db.update('users', {
            'username': 'admin',
            'password': hashPassword('Admin@123', saltAdmin2),
            'password_salt': saltAdmin2,
          }, where: 'email = ?', whereArgs: ['admin@aira.edu']);
        }
      }
    } catch (_) {}

    // Ensure username column exists on users table if not already present
    try {
      await db.execute('ALTER TABLE users ADD COLUMN username TEXT');
    } catch (_) {}

    // Ensure teacher and student have correct roles, usernames, and hashed passwords
    try {
      final teacherRow = await db.query('users', where: "email = 'john.reyes@deped.gov.ph' OR id = 'teacher_1'");
      if (teacherRow.isNotEmpty) {
        // Ensure teacher role is explicitly 'teacher'
        await db.update(
          'users',
          {'role': 'teacher'},
          where: "(email = 'john.reyes@deped.gov.ph' OR id = 'teacher_1') AND role != 'teacher'",
        );

        final currentSalt = teacherRow.first['password_salt'] as String?;
        final currentPass = teacherRow.first['password'] as String?;
        if (currentSalt == null || currentSalt.isEmpty || currentPass == 'John@123') {
          final saltTeacher = generateSalt();
          await db.update('users', {
            'role': 'teacher',
            'username': 'john.reyes',
            'full_name': 'Sir John Reyes',
            'password': hashPassword('John@123', saltTeacher),
            'password_salt': saltTeacher,
          }, where: "id = ?", whereArgs: [teacherRow.first['id']]);
        }
      }

      final studentRow = await db.query('users', where: "email = 'maria@test.com' OR id = 'student_1'");
      if (studentRow.isNotEmpty) {
        final currentSalt = studentRow.first['password_salt'] as String?;
        final currentPass = studentRow.first['password'] as String?;
        if (currentSalt == null || currentSalt.isEmpty || currentPass == 'Maria@123') {
          final saltStudent = generateSalt();
          await db.update('users', {
            'role': 'student',
            'username': 'maria.lopez',
            'section': 'Emerald',
            'grade': 'Grade 10',
            'password': hashPassword('Maria@123', saltStudent),
            'password_salt': saltStudent,
          }, where: "id = ?", whereArgs: [studentRow.first['id']]);
        }
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

    // Ensure core curriculum subjects CS101 and CS202 exist
    final existingCs101 = await db.query('subjects', where: 'subject_code = ?', whereArgs: ['CS101']);
    int cs101Id = 0;
    int lo1Id = 0;
    if (existingCs101.isEmpty) {
      cs101Id = await db.insert('subjects', {
        'name': 'Introduction to Flutter & Dart',
        'subject_code': 'CS101',
        'description': 'Master cross-platform mobile development with Flutter framework and the modern Dart language.',
        'grade_level': 'Grade 10',
        'semester': '1st Semester',
        'unlock_type': 'Sequential',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
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
      lo1Id = await db.insert('learning_outcomes', {
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

      // Topic 2
      final topic2Id = await db.insert('topics', {
        'subject_id': cs101Id,
        'title': 'Topic 2: Flutter Widgets & Layouts',
        'description': 'Master Stateless and Stateful widgets, layout composition, and Material Design components.',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      // LO 2
      final lo2Id = await db.insert('learning_outcomes', {
        'topic_id': topic2Id,
        'title': 'Widget Tree & Composition',
        'description': 'Understand how Flutter builds and renders the widget tree hierarchy.',
        'performance_criteria': 'Build responsive multi-child layouts using Column, Row, and Flex.',
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
        'title': 'Stateless vs Stateful Widgets',
        'content_data': 'In Flutter, almost everything is a widget. A StatelessWidget never changes its configuration during its lifetime, while a StatefulWidget maintains mutable state that can trigger rebuilds via setState().',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      await db.insert('questions', {
        'lo_id': lo2Id,
        'question_text': 'Which widget is best suited for displaying an immutable icon or label?',
        'option_a': 'StatelessWidget',
        'option_b': 'StatefulWidget',
        'option_c': 'InheritedWidget',
        'option_d': 'RenderObjectWidget',
        'correct_option': 'A',
        'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
      });

      // LO 3
      final lo3Id = await db.insert('learning_outcomes', {
        'topic_id': topic2Id,
        'title': 'State Management Basics',
        'description': 'Manage ephemeral state inside StatefulWidgets.',
        'performance_criteria': 'Properly call setState() to trigger widget tree updates.',
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
        'title': 'Lifecycle of a StatefulWidget',
        'content_data': 'A StatefulWidget creates a State object whose lifecycle includes createState(), initState(), didChangeDependencies(), build(), and dispose(). Always clean up controllers in dispose().',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      });

      await db.insert('questions', {
        'lo_id': lo3Id,
        'question_text': 'Which lifecycle method is called exactly once when a State object is inserted into the tree?',
        'option_a': 'build()',
        'option_b': 'initState()',
        'option_c': 'didUpdateWidget()',
        'option_d': 'dispose()',
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
    } else {
      cs101Id = existingCs101.first['id'] as int;
      await db.update('subjects', {
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'grade_level': 'Grade 10',
      }, where: 'id = ?', whereArgs: [cs101Id]);
    }

    // Ensure Subject 2: CS202 exists
    final existingCs202 = await db.query('subjects', where: 'subject_code = ?', whereArgs: ['CS202']);
    int cs202Id = 0;
    if (existingCs202.isEmpty) {
      cs202Id = await db.insert('subjects', {
        'name': 'Mobile UI & State Management',
        'subject_code': 'CS202',
        'description': 'Advanced mobile UI development with Riverpod and responsive layout design.',
        'grade_level': 'Grade 11',
        'semester': '1st Semester',
        'unlock_type': 'Flexible',
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
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
    } else {
      cs202Id = existingCs202.first['id'] as int;
      await db.update('subjects', {
        'teacher_id': 'teacher_1',
        'teacher_name': 'Sir John Reyes',
        'grade_level': 'Grade 11',
      }, where: 'id = ?', whereArgs: [cs202Id]);
    }

    // Pre-enroll student_1 (Maria Lopez) in CS101 and seed an initial quiz attempt
    if (cs101Id > 0 && lo1Id > 0) {
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

    // Seed Sections if empty and ensure enrollment_key is populated
    try {
      final existingSections = await db.query('sections');
      if (existingSections.isEmpty) {
        await db.insert('sections', {
          'name': 'Grade 10 - Emerald',
          'description': 'Junior High Class Emerald',
          'grade': 'Grade 10',
          'room': 'Room 201 - Main Bldg',
          'student_count': 2,
          'enrollment_key': 'SEC-EMR10',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('sections', {
          'name': 'Grade 11 - STEM B',
          'description': 'STEM Strand Section B - Senior High',
          'grade': 'Grade 11',
          'room': 'Room 304 - Science Bldg',
          'student_count': 1,
          'enrollment_key': 'SEC-STEM11',
          'created_at': DateTime.now().toIso8601String(),
        });
        await db.insert('sections', {
          'name': 'Grade 12 - Gold',
          'description': 'Senior High Class Gold',
          'grade': 'Grade 12',
          'room': 'Room 402 - Tech Bldg',
          'student_count': 0,
          'enrollment_key': 'SEC-GOLD12',
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Backfill any sections missing enrollment keys
        for (final sec in existingSections) {
          final currentKey = sec['enrollment_key'] as String?;
          if (currentKey == null || currentKey.isEmpty) {
            final secName = (sec['name'] as String? ?? '').toUpperCase();
            String key;
            if (secName.contains('EMERALD')) {
              key = 'SEC-EMR10';
            } else if (secName.contains('STEM')) {
              key = 'SEC-STEM11';
            } else if (secName.contains('GOLD')) {
              key = 'SEC-GOLD12';
            } else {
              final clean = secName.replaceAll(RegExp(r'[^A-Z0-9]'), '');
              key = 'SEC-${clean.length > 6 ? clean.substring(0, 6) : clean}';
            }
            await db.update('sections', {'enrollment_key': key}, where: 'id = ?', whereArgs: [sec['id']]);
          }
        }
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

    // Ensure authentic students across multiple sections exist and are enrolled in teacher courses
    try {
      final defaultStudents = [
        {
          'id': 'student_1',
          'email': 'maria@test.com',
          'username': 'maria.lopez',
          'password': 'Maria@123',
          'role': 'student',
          'full_name': 'Maria Lopez',
          'section': 'Grade 10 - Emerald',
          'grade': 'Grade 10',
          'created_at': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
        },
        {
          'id': 'student_2',
          'email': 'juan.delacruz@school.edu',
          'username': 'juan.delacruz',
          'password': 'Juan@123',
          'role': 'student',
          'full_name': 'Juan Dela Cruz',
          'section': 'Grade 10 - Emerald',
          'grade': 'Grade 10',
          'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        },
        {
          'id': 'student_3',
          'email': 'angela.santos@school.edu',
          'username': 'angela.santos',
          'password': 'Angela@123',
          'role': 'student',
          'full_name': 'Angela Santos',
          'section': 'Grade 11 - STEM B',
          'grade': 'Grade 11',
          'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
        },
        {
          'id': 'student_4',
          'email': 'mark.bautista@school.edu',
          'username': 'mark.bautista',
          'password': 'Mark@123',
          'role': 'student',
          'full_name': 'Mark Bautista',
          'section': 'Grade 10 - Emerald',
          'grade': 'Grade 10',
          'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        },
      ];

      for (final s in defaultStudents) {
        final existing = await db.query('users', where: 'id = ? OR email = ?', whereArgs: [s['id'], s['email']]);
        if (existing.isEmpty) {
          final salt = generateSalt();
          final userToInsert = Map<String, dynamic>.from(s);
          userToInsert['password'] = hashPassword(s['password'] as String, salt);
          userToInsert['password_salt'] = salt;
          await db.insert('users', userToInsert);
        } else {
          final currentSalt = existing.first['password_salt'] as String?;
          final currentPass = existing.first['password'] as String?;
          final updateData = <String, dynamic>{
            'section': s['section'],
            'grade': s['grade'],
            'role': 'student',
            'full_name': s['full_name'],
          };
          if (currentSalt == null || currentSalt.isEmpty || currentPass == s['password']) {
            final salt = generateSalt();
            updateData['password'] = hashPassword(s['password'] as String, salt);
            updateData['password_salt'] = salt;
          }
          await db.update('users', updateData, where: 'id = ?', whereArgs: [s['id']]);
        }
      }

      // Normalize existing student records to valid section names from the sections table
      await db.update(
        'users',
        {'section': 'Grade 10 - Emerald', 'grade': 'Grade 10'},
        where: "role = 'student' AND (section IN ('Emerald', 'Ruby') OR id IN ('student_1', 'student_2', 'student_4'))",
      );
      await db.update(
        'users',
        {'section': 'Grade 11 - STEM B', 'grade': 'Grade 11'},
        where: "role = 'student' AND (section IN ('Diamond', 'STEM B') OR id = 'student_3')",
      );
      // Remove any test section from sections table that isn't standard
      await db.delete('sections', where: "name NOT IN ('Grade 10 - Emerald', 'Grade 11 - STEM B') AND name LIKE 'Sapphire%'");
      // Update section student counts accurately
      final emCount = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM users WHERE section = 'Grade 10 - Emerald' AND role = 'student'"
      )) ?? 3;
      final stemCount = Sqflite.firstIntValue(await db.rawQuery(
        "SELECT COUNT(*) FROM users WHERE section = 'Grade 11 - STEM B' AND role = 'student'"
      )) ?? 1;
      await db.update('sections', {'student_count': emCount}, where: "name = 'Grade 10 - Emerald'");
      await db.update('sections', {'student_count': stemCount}, where: "name = 'Grade 11 - STEM B'");

      // Migrate any remaining unhashed passwords to salted SHA-256
      try {
        final unhashedUsers = await db.rawQuery(
          "SELECT id, password FROM users WHERE password_salt IS NULL OR password_salt = ''"
        );
        for (final u in unhashedUsers) {
          final id = u['id'] as String;
          final pass = u['password'] as String;
          final salt = generateSalt();
          final hashed = hashPassword(pass, salt);
          await db.update('users', {
            'password': hashed,
            'password_salt': salt,
          }, where: 'id = ?', whereArgs: [id]);
        }
      } catch (_) {}

      // Remove temporary test subjects that may linger from tests
      await db.delete('subjects', where: "name LIKE 'Test Subject for Deletion%'");

      // Ensure enrollments for CS101 and CS202
      final cs101Rows = await db.query('subjects', where: 'subject_code = ?', whereArgs: ['CS101']);
      final cs202Rows = await db.query('subjects', where: 'subject_code = ?', whereArgs: ['CS202']);

      if (cs101Rows.isNotEmpty) {
        final sub1Id = cs101Rows.first['id'] as int;
        for (final sid in ['student_1', 'student_2', 'student_4']) {
          final enr = await db.query('enrollments', where: 'student_id = ? AND subject_id = ?', whereArgs: [sid, sub1Id]);
          if (enr.isEmpty) {
            await db.insert('enrollments', {
              'student_id': sid,
              'subject_id': sub1Id,
              'enrolled_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
              'status': 'active',
            });
          }
        }
      }

      if (cs202Rows.isNotEmpty) {
        final sub2Id = cs202Rows.first['id'] as int;
        for (final sid in ['student_1', 'student_3']) {
          final enr = await db.query('enrollments', where: 'student_id = ? AND subject_id = ?', whereArgs: [sid, sub2Id]);
          if (enr.isEmpty) {
            await db.insert('enrollments', {
              'student_id': sid,
              'subject_id': sub2Id,
              'enrolled_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
              'status': 'active',
            });
          }
        }
      }

      // If teacher_1 has any other subjects without enrollments, enroll authentic students
      final otherTeacherSubjects = await db.query('subjects', where: "teacher_id = 'teacher_1' OR teacher_id LIKE '%reyes%'");
      for (final sub in otherTeacherSubjects) {
        final sid = sub['id'] as int;
        final enrs = await db.query('enrollments', where: 'subject_id = ?', whereArgs: [sid]);
        if (enrs.isEmpty) {
          final g = (sub['grade_level'] as String?)?.toLowerCase() ?? '';
          final targetStudents = g.contains('11')
              ? ['student_3', 'student_1']
              : ['student_1', 'student_2', 'student_4'];
          for (final stId in targetStudents) {
            await db.insert('enrollments', {
              'student_id': stId,
              'subject_id': sid,
              'enrolled_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
              'status': 'active',
            });
          }
        }
      }
    } catch (_) {}

    // Seed Initial Assigned Quiz if none exists
    try {
      final existingQuizzes = await db.query('quizzes');
      if (existingQuizzes.isEmpty) {
        final subjects = await db.query('subjects', where: 'subject_code = ?', whereArgs: ['CS101']);
        if (subjects.isNotEmpty) {
          final cs101Id = subjects.first['id'] as int;
          final quizId = await db.insert('quizzes', {
            'title': 'CS101: Midterm Quiz Assessment',
            'description': 'Comprehensive assessment covering Dart language fundamentals, sound null safety, and OOP concepts.',
            'subject_id': cs101Id,
            'lo_id': null,
            'teacher_id': 'teacher_1',
            'teacher_name': 'Sir John Reyes',
            'time_limit_minutes': 15,
            'passing_score': 70,
            'status': 'published',
            'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'created_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
          });

          await db.insert('questions', {
            'lo_id': 0,
            'quiz_id': quizId,
            'question_text': 'What is the primary role of the "main()" function in a Dart and Flutter application?',
            'option_a': 'To declare build-time styles',
            'option_b': 'Entry point where program execution begins',
            'option_c': 'To connect to local SQLite database',
            'option_d': 'To configure HTTP headers',
            'correct_option': 'B',
            'created_at': DateTime.now().toIso8601String(),
          });

          await db.insert('questions', {
            'lo_id': 0,
            'quiz_id': quizId,
            'question_text': 'Which keyword is used in Dart to declare a compile-time constant?',
            'option_a': 'final',
            'option_b': 'const',
            'option_c': 'static',
            'option_d': 'var',
            'correct_option': 'B',
            'created_at': DateTime.now().toIso8601String(),
          });

          await db.insert('questions', {
            'lo_id': 0,
            'quiz_id': quizId,
            'question_text': 'In Flutter, what kind of widget should you use when parts of the UI need to change dynamically?',
            'option_a': 'StatelessWidget',
            'option_b': 'StatefulWidget',
            'option_c': 'InheritedWidget',
            'option_d': 'ImmutableWidget',
            'correct_option': 'B',
            'created_at': DateTime.now().toIso8601String(),
          });

          // Assign to student_1 (Maria Lopez)
          await db.insert('quiz_assignments', {
            'quiz_id': quizId,
            'student_id': 'student_1',
            'assigned_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
            'due_date': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
            'status': 'pending',
            'score': 0,
            'total_questions': 3,
            'percentage': 0.0,
            'completed_at': null,
          });
        }
      }
    } catch (_) {}

    // Seed starter assignment for subject 1
    try {
      final existingAssignments = await db.query('assignments');
      if (existingAssignments.isEmpty) {
        final subjects = await db.query('subjects', limit: 1);
        if (subjects.isNotEmpty) {
          final subjId = subjects.first['id'] as int;
          await db.insert('assignments', {
            'title': 'Final Project: Flutter Migration',
            'description': 'Please provide a link to your GitHub repository or Google Drive folder containing the final project files, or attach your project archive.',
            'subject_id': subjId,
            'teacher_id': 'teacher_1',
            'teacher_name': 'Sir John Reyes',
            'due_date': DateTime.now().add(const Duration(days: 14)).toIso8601String(),
            'total_points': 100,
            'submission_type': 'both',
            'status': 'active',
            'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          });
        }
      }
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

  // ── Teachers & Faculty Management ────────────────────────
  Future<List<Map<String, dynamic>>> getTeachersList() async {
    final db = await database;
    final teachers = await db.query(
      'users',
      where: 'role = ?',
      whereArgs: ['teacher'],
      orderBy: 'full_name ASC',
    );

    final List<Map<String, dynamic>> enriched = [];
    for (final t in teachers) {
      final tid = t['id'] as String;
      final subjects = await getSubjectsForTeacher(tid);
      final sections = await getSectionsForTeacher(tid);

      // Student count across assigned subjects
      int studentCount = 0;
      final subIds = subjects.map((s) => s['id'] as int).toList();
      if (subIds.isNotEmpty) {
        final enrollments = await db.query(
          'enrollments',
          columns: ['student_id'],
          where: 'subject_id IN (${subIds.map((_) => '?').join(',')}) AND status = ?',
          whereArgs: [...subIds, 'active'],
        );
        studentCount = enrollments.map((e) => e['student_id'] as String).toSet().length;
      }

      enriched.add({
        ...t,
        'assigned_subjects_count': subjects.length,
        'assigned_subjects': subjects,
        'handled_sections': sections,
        'student_count': studentCount,
      });
    }

    return enriched;
  }

  Future<String> createTeacher({
    required String fullName,
    required String email,
    required String password,
    String? username,
    List<int>? assignSubjectIds,
  }) async {
    final db = await database;
    final salt = generateSalt();
    final hashedPassword = hashPassword(password, salt);
    final teacherId = 'teacher_${DateTime.now().millisecondsSinceEpoch}';
    final resolvedUsername = (username != null && username.trim().isNotEmpty)
        ? username.trim()
        : (email.contains('@') ? email.split('@').first : fullName.trim().toLowerCase().replaceAll(' ', '.'));

    await db.insert('users', {
      'id': teacherId,
      'email': email.trim(),
      'username': resolvedUsername,
      'password': hashedPassword,
      'password_salt': salt,
      'role': 'teacher',
      'full_name': fullName.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });

    if (assignSubjectIds != null && assignSubjectIds.isNotEmpty) {
      for (final subId in assignSubjectIds) {
        await assignTeacherToSubject(subId, teacherId, fullName.trim());
      }
    }

    return teacherId;
  }

  Future<void> updateTeacher(
    String teacherId,
    Map<String, dynamic> data, {
    List<int>? assignSubjectIds,
  }) async {
    final db = await database;
    final updates = <String, dynamic>{};
    if (data.containsKey('full_name')) updates['full_name'] = (data['full_name'] as String).trim();
    if (data.containsKey('email')) updates['email'] = (data['email'] as String).trim();
    if (data.containsKey('username')) updates['username'] = (data['username'] as String).trim();
    if (data.containsKey('password')) {
      final rawPass = data['password'] as String;
      if (rawPass.isNotEmpty) {
        final salt = generateSalt();
        updates['password'] = hashPassword(rawPass, salt);
        updates['password_salt'] = salt;
      }
    }

    if (updates.isNotEmpty) {
      await db.update('users', updates, where: 'id = ?', whereArgs: [teacherId]);
    }

    final teacherRows = await db.query('users', columns: ['full_name'], where: 'id = ?', whereArgs: [teacherId]);
    final teacherName = (teacherRows.isNotEmpty ? teacherRows.first['full_name'] as String? : null) ?? 'Teacher';

    if (assignSubjectIds != null) {
      // Unassign subjects previously assigned to this teacher
      await db.update(
        'subjects',
        {'teacher_id': null, 'teacher_name': null},
        where: 'teacher_id = ?',
        whereArgs: [teacherId],
      );

      // Assign the new list
      for (final subId in assignSubjectIds) {
        await assignTeacherToSubject(subId, teacherId, teacherName);
      }
    }
  }

  Future<void> deleteTeacher(String teacherId) async {
    final db = await database;
    // Unassign all subjects
    await db.update(
      'subjects',
      {'teacher_id': null, 'teacher_name': null},
      where: 'teacher_id = ?',
      whereArgs: [teacherId],
    );
    // Delete the teacher account
    await db.delete('users', where: 'id = ?', whereArgs: [teacherId]);
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

  // ── Component 1: New Database Methods ──────────────────────

  /// Returns exact student counts: total, active, unassigned, and breakdown per grade/section
  Future<Map<String, dynamic>> getExactStudentCounts() async {
    final db = await database;
    final users = await db.query('users', where: "role = 'student'");
    final total = users.length;
    final active = users.where((u) => (u['section'] as String?)?.isNotEmpty == true).length;
    final unassigned = total - active;

    final gradeCounts = <String, int>{};
    final sectionCounts = <String, int>{};
    for (final u in users) {
      final grade = (u['grade'] as String?)?.trim();
      final section = (u['section'] as String?)?.trim();
      if (grade != null && grade.isNotEmpty) {
        gradeCounts[grade] = (gradeCounts[grade] ?? 0) + 1;
      }
      if (section != null && section.isNotEmpty) {
        sectionCounts[section] = (sectionCounts[section] ?? 0) + 1;
      }
    }
    return {
      'total': total,
      'active': active,
      'unassigned': unassigned,
      'gradeCounts': gradeCounts,
      'sectionCounts': sectionCounts,
    };
  }

  /// Teacher dashboard stats: subjects, unique students, attempts, pass rate, avg score, recent attempts
  Future<Map<String, dynamic>> getTeacherDashboardStats(String teacherId) async {
    final db = await database;
    final subjects = await db.query('subjects', where: 'teacher_id = ?', whereArgs: [teacherId]);
    final totalSubjects = subjects.length;
    final subjectIds = subjects.map((s) => s['id'] as int).toList();

    int totalStudents = 0;
    int totalAttempts = 0;
    int passedAttempts = 0;
    double totalPct = 0.0;

    final enrollments = await db.query('enrollments');
    final attempts = await db.query('quiz_attempts');
    final attemptsForTeacher = attempts.where((a) => subjectIds.contains(a['subject_id'])).toList();

    if (subjectIds.isNotEmpty) {
      final studentIds = <String>{};
      for (final e in enrollments) {
        if (subjectIds.contains(e['subject_id'])) {
          studentIds.add(e['student_id'] as String);
        }
      }
      totalStudents = studentIds.length;
      totalAttempts = attemptsForTeacher.length;
      passedAttempts = attemptsForTeacher.where((a) => (a['is_passed'] as int?) == 1).length;
      if (totalAttempts > 0) {
        totalPct = attemptsForTeacher.map((a) => (a['percentage'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / totalAttempts;
      }
    }

    // Fallback: If totalStudents is 0 but teacher has subjects, count students from handled sections
    if (totalStudents == 0 && subjectIds.isNotEmpty) {
      final handledSections = await getSectionsForTeacher(teacherId);
      if (handledSections.isNotEmpty) {
        final handledLower = handledSections.map((s) => s.toLowerCase().trim()).toSet();
        final allStudents = await db.query('users', where: 'role = ?', whereArgs: ['student']);
        final matched = allStudents.where((s) {
          final sec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
          return sec.isNotEmpty && (handledLower.contains(sec) || handledLower.any((h) => h.contains(sec) || sec.contains(h)));
        }).length;
        if (matched > 0) {
          totalStudents = matched;
        }
      }
    }

    // Recent 10 attempts
    final recent = await db.rawQuery('''
      SELECT qa.*, u.full_name as student_name, s.name as subject_name
      FROM quiz_attempts qa
      JOIN users u ON qa.student_id = u.id
      JOIN subjects s ON qa.subject_id = s.id
      WHERE s.teacher_id = ?
      ORDER BY qa.attempted_at DESC
      LIMIT 10
    ''', [teacherId]);

    return {
      'totalSubjects': totalSubjects,
      'totalStudents': totalStudents,
      'totalAttempts': totalAttempts,
      'passedAttempts': passedAttempts,
      'passRate': totalAttempts > 0 ? ((passedAttempts / totalAttempts) * 100).round() : 0,
      'avgScore': totalPct.round(),
      'recentAttempts': recent,
    };
  }

  /// Student roster for teacher with progress per subject and section-based queries
  Future<List<Map<String, dynamic>>> getStudentsForTeacher(String teacherId, {String? section, String? query}) async {
    final db = await database;
    final subjects = await getSubjectsForTeacher(teacherId);
    final subjectIds = subjects.map((s) => s['id'] as int).toList();

    // Enrollments for this teacher's subjects
    List<Map<String, dynamic>> enrollments = [];
    if (subjectIds.isNotEmpty) {
      enrollments = await db.query(
        'enrollments',
        where: 'subject_id IN (${subjectIds.map((_) => '?').join(',')})',
        whereArgs: subjectIds,
      );
    }
    final enrolledStudentIds = enrollments.map((e) => e['student_id'] as String).toSet();

    // Query students
    List<Map<String, dynamic>> students;
    if (section != null && section.isNotEmpty && section != 'All Sections' && section != 'All Handled Sections') {
      // Find students whose section matches or who are enrolled in teacher's subjects with this section
      final cleanSection = section.trim().toLowerCase();
      final candidates = await db.query(
        'users',
        where: 'role = ?',
        whereArgs: ['student'],
      );
      students = candidates.where((s) {
        final studentSec = (s['section'] as String?)?.trim().toLowerCase() ?? '';
        if (studentSec.isEmpty) return false;
        return studentSec == cleanSection || studentSec.contains(cleanSection);
      }).toList();
    } else {
      // All sections: find all students enrolled in teacher's subjects,
      // OR students belonging to any of teacher's handled sections
      final handledSections = await getSectionsForTeacher(teacherId);
      final handledLower = handledSections.map((s) => s.toLowerCase().trim()).toSet();

      final allStudents = await db.query('users', where: 'role = ?', whereArgs: ['student']);
      students = allStudents.where((s) {
        final sid = s['id'] as String;
        final sec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
        return enrolledStudentIds.contains(sid) ||
            (sec.isNotEmpty && handledLower.contains(sec)) ||
            handledLower.any((h) => h.isNotEmpty && sec.isNotEmpty && (sec.contains(h) || h.contains(sec)));
      }).toList();
    }

    final list = <Map<String, dynamic>>[];
    for (final s in students) {
      final sid = s['id'] as String;
      final name = (s['full_name'] as String?) ?? '';
      final email = (s['email'] as String?) ?? '';
      final username = (s['username'] as String?) ?? '';

      if (query != null && query.trim().isNotEmpty) {
        final q = query.toLowerCase().trim();
        if (!name.toLowerCase().contains(q) &&
            !email.toLowerCase().contains(q) &&
            !username.toLowerCase().contains(q)) {
          continue;
        }
      }

      // Progress for this student in teacher's subjects
      int completedLos = 0;
      if (subjectIds.isNotEmpty) {
        final progress = await db.rawQuery('''
          SELECT * FROM student_progress 
          WHERE student_id = ? AND subject_id IN (${subjectIds.map((_) => '?').join(',')})
        ''', [sid, ...subjectIds]);
        completedLos = progress.where((p) => (p['is_completed'] as int?) == 1).length;
      }

      final studentSubjectEnrollments = enrollments.where((e) => e['student_id'] == sid).length;
      final isEnrolled = enrolledStudentIds.contains(sid);

      list.add({
        ...s,
        'completed_los': completedLos,
        'enrolled_subjects': studentSubjectEnrollments,
        'is_enrolled': isEnrolled,
      });
    }

    list.sort((a, b) => (a['full_name'] as String? ?? '').compareTo(b['full_name'] as String? ?? ''));
    return list;
  }

  /// Get handled sections with metadata, student counts, and enrolled courses
  Future<List<Map<String, dynamic>>> getHandledSectionsWithDetails(String teacherId) async {
    final db = await database;
    final handledSectionNames = await getSectionsForTeacher(teacherId);
    final subjects = await getSubjectsForTeacher(teacherId);
    final subjectIds = subjects.map((s) => s['id'] as int).toList();

    // Query sections table for metadata (room, description, grade)
    final dbSections = await db.query('sections');
    final sectionMetaMap = <String, Map<String, dynamic>>{};
    for (final sec in dbSections) {
      final name = (sec['name'] as String?)?.toLowerCase().trim() ?? '';
      if (name.isNotEmpty) {
        sectionMetaMap[name] = sec;
      }
    }

    // Get all enrollments for teacher subjects
    List<Map<String, dynamic>> teacherEnrollments = [];
    if (subjectIds.isNotEmpty) {
      teacherEnrollments = await db.query(
        'enrollments',
        where: 'subject_id IN (${subjectIds.map((_) => '?').join(',')})',
        whereArgs: subjectIds,
      );
    }
    final enrolledStudentIds = teacherEnrollments.map((e) => e['student_id'] as String).toSet();

    final allStudents = await db.query('users', where: 'role = ?', whereArgs: ['student']);

    final details = <Map<String, dynamic>>[];
    for (final secName in handledSectionNames) {
      final secLower = secName.toLowerCase().trim();

      final studentsInSection = allStudents.where((s) {
        final sSec = (s['section'] as String?)?.toLowerCase().trim() ?? '';
        return sSec == secLower || (sSec.isNotEmpty && (sSec.contains(secLower) || secLower.contains(sSec)));
      }).toList();

      final totalStudents = studentsInSection.length;
      final enrolledCount = studentsInSection.where((s) => enrolledStudentIds.contains(s['id'] as String)).length;

      // Determine grade and room
      String grade = '';
      String room = '';
      String description = '';

      Map<String, dynamic>? meta = sectionMetaMap[secLower];
      if (meta == null) {
        for (final entry in sectionMetaMap.entries) {
          if (entry.key.contains(secLower) || secLower.contains(entry.key)) {
            meta = entry.value;
            break;
          }
        }
      }

      if (meta != null) {
        grade = meta['grade']?.toString() ?? '';
        room = meta['room']?.toString() ?? '';
        description = meta['description']?.toString() ?? '';
      }
      if (grade.isEmpty && studentsInSection.isNotEmpty) {
        grade = studentsInSection.first['grade']?.toString() ?? '';
      }
      if (grade.isEmpty) {
        grade = 'Senior High';
      }

      final subjectNames = subjects.map((s) => s['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList();

      details.add({
        'name': secName,
        'grade': grade,
        'room': room,
        'description': description,
        'student_count': totalStudents > 0 ? totalStudents : enrolledCount,
        'enrolled_count': enrolledCount,
        'subjects': subjectNames,
      });
    }

    details.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
    return details;
  }

  /// Get distinct list of sections handled by a teacher (via students enrolled in assigned subjects)
  Future<List<String>> getSectionsForTeacher(String teacherId) async {
    final db = await database;
    final subjects = await getSubjectsForTeacher(teacherId);
    final subjectIds = subjects.map((s) => s['id'] as int).toList();
    final sections = <String>{};

    // Get all valid sections defined in the school sections table
    final availableSections = await getAvailableSectionsList();

    if (subjectIds.isNotEmpty) {
      final enrollments = await db.query(
        'enrollments',
        where: 'subject_id IN (${subjectIds.map((_) => '?').join(',')})',
        whereArgs: subjectIds,
      );
      final studentIds = enrollments.map((e) => e['student_id'] as String).toSet().toList();
      if (studentIds.isNotEmpty) {
        final students = await db.query(
          'users',
          columns: ['section'],
          where: 'id IN (${studentIds.map((_) => '?').join(',')}) AND section IS NOT NULL',
          whereArgs: studentIds,
        );
        for (final s in students) {
          final sec = s['section']?.toString().trim();
          if (sec != null && sec.isNotEmpty) {
            // Match against available sections in the school
            final matched = availableSections.firstWhere(
              (avail) =>
                  avail.toLowerCase() == sec.toLowerCase() ||
                  avail.toLowerCase().contains(sec.toLowerCase()) ||
                  sec.toLowerCase().contains(avail.toLowerCase()),
              orElse: () => '',
            );
            if (matched.isNotEmpty) {
              sections.add(matched);
            }
          }
        }
      }
    }

    // Resilient fallback: If no sections were found via enrollments, but the teacher has assigned subjects
    if (sections.isEmpty && subjects.isNotEmpty) {
      final subjectGrades = subjects
          .map((s) => (s['grade_level'] as String?)?.trim().toLowerCase())
          .where((g) => g != null && g.isNotEmpty)
          .toSet();

      if (subjectGrades.isNotEmpty) {
        final secRows = await db.query('sections');
        for (final r in secRows) {
          final rGrade = (r['grade'] as String?)?.trim().toLowerCase();
          final rName = (r['name'] as String?)?.trim();
          if (rGrade != null && subjectGrades.contains(rGrade) && rName != null && rName.isNotEmpty) {
            sections.add(rName);
          }
        }
      }

      // If still empty and teacher is teacher_1 (default faculty instructor), link to available school sections
      if (sections.isEmpty && (teacherId == 'teacher_1' || teacherId.contains('reyes'))) {
        sections.addAll(availableSections);
      }
    }

    final sorted = sections.toList()..sort();
    return sorted;
  }

  /// Get announcements for a teacher with optional section filtering
  Future<List<Map<String, dynamic>>> getAnnouncementsForTeacher(String teacherId, {String? section}) async {
    final db = await database;
    final all = await db.query('announcements', orderBy: 'id DESC');
    final handledSections = await getSectionsForTeacher(teacherId);

    return all.where((a) {
      final aSec = (a['section'] as String?)?.trim();
      final isAuthor = a['author_id'] == teacherId;

      // When filtered by a specific section (e.g. "Emerald")
      if (section != null &&
          section.isNotEmpty &&
          section != 'All Handled Sections' &&
          section != 'All Sections') {
        return aSec == section;
      }

      // When set to 'All Handled Sections' or no filter:
      // Show if authored by this teacher, or if broadcast to all sections,
      // or if targeted to one of the teacher's handled sections
      if (isAuthor) return true;
      if (aSec == null ||
          aSec.isEmpty ||
          aSec == 'All Sections' ||
          aSec == 'All Handled Sections') {
        return true;
      }
      return handledSections.contains(aSec);
    }).toList();
  }

  /// Get announcements targeted to a student based on audience and section
  Future<List<Map<String, dynamic>>> getAnnouncementsForStudent(String? studentSection) async {
    final db = await database;
    final all = await db.query('announcements', orderBy: 'id DESC');
    return all.where((a) {
      final aud = (a['target_audience'] as String? ?? 'all').toLowerCase();
      if (aud != 'all' && aud != 'students') return false;

      final aSec = (a['section'] as String?)?.trim();
      if (aSec == null ||
          aSec.isEmpty ||
          aSec == 'All Sections' ||
          aSec == 'All Handled Sections') {
        return true;
      }
      if (studentSection != null && studentSection.trim().isNotEmpty) {
        return aSec.toLowerCase() == studentSection.trim().toLowerCase();
      }
      return false;
    }).toList();
  }

  /// Get students enrolled in a subject, or all students if subject enrollments are empty
  Future<List<Map<String, dynamic>>> getStudentsForSubjectOrAll(int subjectId, {String? section, String? query}) async {
    final db = await database;
    try {
      final enrollments = await db.query('enrollments', where: 'subject_id = ?', whereArgs: [subjectId]);
      final studentIds = enrollments.map((e) => e['student_id'] as String).toSet().toList();

      List<Map<String, dynamic>> students = [];
      if (studentIds.isNotEmpty) {
        students = await db.query(
          'users',
          where: 'id IN (${studentIds.map((_) => '?').join(',')}) AND role = ?',
          whereArgs: [...studentIds, 'student'],
          orderBy: 'full_name ASC',
        );
      }

      // If no explicit enrollments for this subject yet, fallback to all registered students
      if (students.isEmpty) {
        students = await db.query(
          'users',
          where: 'role = ?',
          whereArgs: ['student'],
          orderBy: 'full_name ASC',
        );
      }

      final list = <Map<String, dynamic>>[];
      for (final s in students) {
        final sec = (s['section'] as String?) ?? '';
        if (section != null && section.isNotEmpty && section != 'All Sections' && sec != section) continue;
        final name = (s['full_name'] as String?) ?? '';
        final email = (s['email'] as String?) ?? '';
        if (query != null && query.trim().isNotEmpty) {
          final q = query.toLowerCase();
          if (!name.toLowerCase().contains(q) && !email.toLowerCase().contains(q)) continue;
        }
        list.add(s);
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  /// Returns all available subjects with is_enrolled flag and enrollment date for a given student
  Future<List<Map<String, dynamic>>> getStudentEnrollmentsWithDetails(String studentId) async {
    final db = await database;
    final allSubjects = await db.query('subjects', orderBy: 'id ASC');
    final activeEnrollments = await db.query(
      'enrollments',
      where: 'student_id = ? AND status = ?',
      whereArgs: [studentId, 'active'],
    );

    final enrollmentMap = <int, Map<String, dynamic>>{};
    for (final e in activeEnrollments) {
      final subId = e['subject_id'] as int;
      enrollmentMap[subId] = e;
    }

    return allSubjects.map((sub) {
      final id = sub['id'] as int;
      final isEnrolled = enrollmentMap.containsKey(id);
      return {
        ...sub,
        'is_enrolled': isEnrolled,
        'enrolled_at': isEnrolled ? enrollmentMap[id]!['enrolled_at'] : null,
      };
    }).toList();
  }

  /// Sets exactly which subjects a student is enrolled in, activating new ones and removing unselected ones
  Future<void> setStudentEnrollments(String studentId, List<int> subjectIds) async {
    final db = await database;
    if (subjectIds.isEmpty) {
      await db.delete(
        'enrollments',
        where: 'student_id = ?',
        whereArgs: [studentId],
      );
      return;
    }

    // Delete enrollments not in subjectIds
    await db.delete(
      'enrollments',
      where: 'student_id = ? AND subject_id NOT IN (${subjectIds.map((_) => '?').join(',')})',
      whereArgs: [studentId, ...subjectIds],
    );

    // Insert or activate selected subjects
    for (final subId in subjectIds) {
      final existing = await db.query(
        'enrollments',
        where: 'student_id = ? AND subject_id = ?',
        whereArgs: [studentId, subId],
      );

      if (existing.isEmpty) {
        await db.insert('enrollments', {
          'student_id': studentId,
          'subject_id': subId,
          'enrolled_at': DateTime.now().toIso8601String(),
          'status': 'active',
        });
      } else {
        await db.update(
          'enrollments',
          {'status': 'active'},
          where: 'student_id = ? AND subject_id = ?',
          whereArgs: [studentId, subId],
        );
      }
    }
  }

  /// Auto-enroll student in all subjects matching grade/section assigned to teachers
  Future<void> autoEnrollStudentBySection(String studentId, String section, String grade) async {
    final db = await database;
    // Find subjects that match the grade level (via subjects.grade_level) or have teachers assigned
    final subjects = await db.query('subjects');
    for (final s in subjects) {
      final subId = s['id'] as int;
      final gradeLevel = (s['grade_level'] as String?) ?? '';
      // Auto-enroll if subject grade matches student grade, or if no grade restriction
      if (gradeLevel.isEmpty || gradeLevel == grade) {
        await db.insert('enrollments', {
          'student_id': studentId,
          'subject_id': subId,
          'enrolled_at': DateTime.now().toIso8601String(),
          'status': 'active',
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
  }

  /// Validate and consume a registration key atomically
  Future<bool> validateAndConsumeRegistrationKey(String code, String studentId) async {
    final db = await database;
    final res = await db.query('reg_links', where: 'code = ?', whereArgs: [code]);
    if (res.isEmpty) return false;
    final link = res.first;
    final usedCount = (link['used_count'] as int?) ?? 0;
    final maxUses = (link['max_uses'] as int?) ?? 0;
    final expirationStr = link['expiration'] as String?;
    if (expirationStr != null && expirationStr.isNotEmpty) {
      final exp = DateTime.tryParse(expirationStr);
      if (exp != null && exp.isBefore(DateTime.now())) return false;
    }
    if (maxUses > 0 && usedCount >= maxUses) return false;

    // Atomically increment and bind student
    await db.update('reg_links', {
      'used_count': usedCount + 1,
    }, where: 'code = ?', whereArgs: [code]);

    final sectionName = link['section'] as String? ?? '';
    if (sectionName.isNotEmpty) {
      await db.update('users', {
        'section': sectionName,
      }, where: 'id = ?', whereArgs: [studentId]);
      await db.execute('UPDATE sections SET student_count = student_count + 1 WHERE name = ?', [sectionName]);
      await autoEnrollStudentBySection(studentId, sectionName, ''); // grade handled separately if needed
    }
    return true;
  }

  // ── First-Class Quizzes & Bulk Assignment Management ─────

  Future<int> createQuiz({
    required String title,
    String? description,
    required int subjectId,
    int? loId,
    required String teacherId,
    String? teacherName,
    int timeLimitMinutes = 0,
    int passingScore = 70,
    String? dueDate,
    String? scheduleStart,
    String? scheduleEnd,
    String status = 'published',
    List<Map<String, dynamic>> questions = const [],
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final quizId = await db.insert('quizzes', {
      'title': title,
      'description': description,
      'subject_id': subjectId,
      'lo_id': loId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'time_limit_minutes': timeLimitMinutes,
      'passing_score': passingScore,
      'status': status,
      'due_date': dueDate,
      'schedule_start': scheduleStart,
      'schedule_end': scheduleEnd,
      'created_at': now,
    });

    for (final q in questions) {
      await db.insert('questions', {
        'lo_id': loId ?? 0,
        'quiz_id': quizId,
        'question_text': q['question_text'] ?? '',
        'option_a': q['option_a'] ?? '',
        'option_b': q['option_b'] ?? '',
        'option_c': q['option_c'] ?? '',
        'option_d': q['option_d'] ?? '',
        'correct_option': (q['correct_option'] ?? 'A').toString().toUpperCase().trim(),
        'created_at': now,
      });
    }

    return quizId;
  }

  Future<int> assignQuizToStudents({
    required int quizId,
    required List<String> studentIds,
    String? dueDate,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    final qCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM questions WHERE quiz_id = ?', [quizId]);
    final totalQuestions = (qCountRes.first['count'] as int?) ?? 0;

    int assigned = 0;
    for (final sid in studentIds) {
      try {
        await db.insert(
          'quiz_assignments',
          {
            'quiz_id': quizId,
            'student_id': sid,
            'assigned_at': now,
            'due_date': dueDate,
            'status': 'pending',
            'score': 0,
            'total_questions': totalQuestions,
            'percentage': 0.0,
            'completed_at': null,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        assigned++;
      } catch (e) {
        debugPrint('Error assigning quiz $quizId to $sid: $e');
      }
    }
    return assigned;
  }

  Future<List<Map<String, dynamic>>> getQuizzesForSubject(int subjectId) async {
    final db = await database;
    final quizzes = await db.query(
      'quizzes',
      where: 'subject_id = ?',
      whereArgs: [subjectId],
      orderBy: 'created_at DESC',
    );

    final List<Map<String, dynamic>> enriched = [];
    for (final q in quizzes) {
      final qId = q['id'] as int;
      final qCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM questions WHERE quiz_id = ?', [qId]);
      final qCount = (qCountRes.first['count'] as int?) ?? 0;

      final assignCountRes = await db.rawQuery('SELECT COUNT(*) as count FROM quiz_assignments WHERE quiz_id = ?', [qId]);
      final assignCount = (assignCountRes.first['count'] as int?) ?? 0;

      final compCountRes = await db.rawQuery("SELECT COUNT(*) as count FROM quiz_assignments WHERE quiz_id = ? AND status = 'completed'", [qId]);
      final compCount = (compCountRes.first['count'] as int?) ?? 0;

      enriched.add({
        ...q,
        'question_count': qCount,
        'assigned_count': assignCount,
        'completed_count': compCount,
      });
    }
    return enriched;
  }

  Future<List<Map<String, dynamic>>> getAssignedQuizzesForStudent(String studentId, {int? subjectId}) async {
    final db = await database;
    String query = '''
      SELECT qa.*,
             q.title,
             q.description,
             q.subject_id,
             q.lo_id,
             q.teacher_id,
             q.teacher_name,
             q.time_limit_minutes,
             q.passing_score,
             q.status as quiz_status,
             q.schedule_start,
             q.schedule_end,
             s.name as subject_name,
             s.subject_code,
             (SELECT COUNT(*) FROM questions WHERE quiz_id = q.id) as question_count
      FROM quiz_assignments qa
      JOIN quizzes q ON qa.quiz_id = q.id
      LEFT JOIN subjects s ON q.subject_id = s.id
      WHERE qa.student_id = ?
    ''';
    List<dynamic> args = [studentId];
    if (subjectId != null) {
      query += ' AND q.subject_id = ?';
      args.add(subjectId);
    }
    query += ' ORDER BY CASE WHEN qa.status = \'pending\' THEN 0 ELSE 1 END, qa.assigned_at DESC';

    return await db.rawQuery(query, args);
  }

  Future<Map<String, dynamic>?> getQuizById(int quizId) async {
    final db = await database;
    final quizRes = await db.rawQuery('''
      SELECT q.*, s.name as subject_name, s.subject_code
      FROM quizzes q
      LEFT JOIN subjects s ON q.subject_id = s.id
      WHERE q.id = ?
    ''', [quizId]);

    if (quizRes.isEmpty) return null;
    final quiz = quizRes.first;

    final questions = await db.query(
      'questions',
      where: 'quiz_id = ?',
      whereArgs: [quizId],
      orderBy: 'id ASC',
    );

    return {
      ...quiz,
      'questions': questions,
    };
  }

  Future<Map<String, dynamic>?> getQuizAssignment(int quizId, String studentId) async {
    final db = await database;
    final res = await db.query(
      'quiz_assignments',
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<void> completeQuizAssignment({
    required int quizId,
    required String studentId,
    required int score,
    required int totalQuestions,
    required double percentage,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'quiz_assignments',
      {
        'status': 'completed',
        'score': score,
        'total_questions': totalQuestions,
        'percentage': percentage,
        'completed_at': now,
      },
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );

    // Also ensure quiz_attempts has an entry if not already logged
    final existing = await db.query(
      'quiz_attempts',
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );
    if (existing.isEmpty) {
      final qRes = await db.query('quizzes', where: 'id = ?', whereArgs: [quizId]);
      if (qRes.isNotEmpty) {
        final q = qRes.first;
        final subjectId = (q['subject_id'] as int?) ?? 1;
        final loId = (q['lo_id'] as int?) ?? 0;
        final passingScore = (q['passing_score'] as int?) ?? 70;
        final isPassed = percentage >= passingScore;

        await db.insert('quiz_attempts', {
          'student_id': studentId,
          'lo_id': loId,
          'quiz_id': quizId,
          'subject_id': subjectId,
          'score': score,
          'total_questions': totalQuestions,
          'percentage': percentage,
          'is_passed': isPassed ? 1 : 0,
          'duration_seconds': 0,
          'attempted_at': now,
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> getQuizAssignmentRoster(int quizId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT qa.*,
             u.full_name as student_name,
             u.email as student_email,
             u.section as student_section,
             u.grade as student_grade,
             CASE
               WHEN qa.status = 'completed' AND qa.score >= (
                 SELECT passing_score FROM quizzes WHERE id = qa.quiz_id
               ) THEN 'Passed'
               WHEN qa.status = 'completed' THEN 'Failed'
               ELSE 'Pending'
             END as result
      FROM quiz_assignments qa
      JOIN users u ON qa.student_id = u.id
      WHERE qa.quiz_id = ?
      ORDER BY CASE WHEN qa.status = 'completed' THEN 0 ELSE 1 END, qa.score DESC
    ''', [quizId]);
  }

  /// Reset a single student's quiz attempt (teacher resets individual student)
  Future<void> resetStudentQuizAttempt({
    required int quizId,
    required String studentId,
  }) async {
    final db = await database;

    // Delete quiz attempts
    await db.delete(
      'quiz_attempts',
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );

    // Reset assignment
    await db.update(
      'quiz_assignments',
      {
        'status': 'pending',
        'score': 0,
        'total_questions': 0,
        'percentage': 0.0,
        'completed_at': null,
      },
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );
  }

  /// Check if a student has a pending retry eligibility
  Future<bool> canStudentRetryQuiz({
    required int quizId,
    required String studentId,
  }) async {
    final db = await database;
    final assignment = await db.query(
      'quiz_assignments',
      where: 'quiz_id = ? AND student_id = ?',
      whereArgs: [quizId, studentId],
    );

    if (assignment.isEmpty) return false;

    final status = assignment.first['status'];
    // Student can retry if they previously completed the quiz
    return status == 'completed';
  }

  Future<void> deleteQuiz(int quizId) async {
    final db = await database;
    await db.delete('quiz_assignments', where: 'quiz_id = ?', whereArgs: [quizId]);
    await db.delete('questions', where: 'quiz_id = ?', whereArgs: [quizId]);
    await db.delete('quizzes', where: 'id = ?', whereArgs: [quizId]);
  }

  Future<void> updateSubjectUnlockType(int subjectId, String unlockType) async {
    final db = await database;
    await db.update('subjects', {'unlock_type': unlockType}, where: 'id = ?', whereArgs: [subjectId]);
  }

  // ── Assignments & Submissions Management ───────────────

  Future<int> createAssignment({
    required String title,
    String? description,
    required int subjectId,
    required String teacherId,
    String? teacherName,
    String? dueDate,
    int totalPoints = 100,
    String submissionType = 'both',
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert('assignments', {
      'title': title,
      'description': description,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'teacher_name': teacherName,
      'due_date': dueDate,
      'total_points': totalPoints,
      'submission_type': submissionType,
      'status': 'active',
      'created_at': now,
    });
  }

  Future<Map<String, dynamic>?> getAssignmentById(int id) async {
    final db = await database;
    final res = await db.rawQuery('''
      SELECT a.*, s.name as subject_name, s.subject_code
      FROM assignments a
      LEFT JOIN subjects s ON a.subject_id = s.id
      WHERE a.id = ?
    ''', [id]);
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getAssignmentsForSubject(int subjectId) async {
    final db = await database;
    final assignments = await db.rawQuery('''
      SELECT a.*,
             (SELECT COUNT(*) FROM submissions WHERE assignment_id = a.id) as submission_count,
             (SELECT COUNT(*) FROM submissions WHERE assignment_id = a.id AND status = 'graded') as graded_count
      FROM assignments a
      WHERE a.subject_id = ?
      ORDER BY a.created_at DESC
    ''', [subjectId]);
    return assignments;
  }

  Future<List<Map<String, dynamic>>> getAssignmentsForStudent(String studentId, {int? subjectId}) async {
    final db = await database;
    String query = '''
      SELECT a.*,
             s.name as subject_name,
             s.subject_code,
             sub.id as submission_id,
             sub.status as submission_status,
             sub.content_link,
             sub.file_name,
             sub.file_size,
             sub.notes,
             sub.submitted_at,
             sub.grade,
             sub.feedback,
             sub.graded_at
      FROM assignments a
      JOIN subjects s ON a.subject_id = s.id
      LEFT JOIN submissions sub ON sub.assignment_id = a.id AND sub.student_id = ?
    ''';
    List<dynamic> args = [studentId];
    if (subjectId != null) {
      query += ' WHERE a.subject_id = ?';
      args.add(subjectId);
    }
    query += ' ORDER BY CASE WHEN sub.status IS NULL THEN 0 ELSE 1 END, a.due_date ASC, a.created_at DESC';
    return await db.rawQuery(query, args);
  }

  Future<Map<String, dynamic>?> getSubmissionForAssignment(int assignmentId, String studentId) async {
    final db = await database;
    final res = await db.query(
      'submissions',
      where: 'assignment_id = ? AND student_id = ?',
      whereArgs: [assignmentId, studentId],
    );
    return res.isNotEmpty ? res.first : null;
  }

  Future<List<Map<String, dynamic>>> getSubmissionsForAssignment(int assignmentId) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT sub.*, u.full_name, u.email, u.section, u.grade as student_grade_level
      FROM submissions sub
      LEFT JOIN users u ON sub.student_id = u.id
      WHERE sub.assignment_id = ?
      ORDER BY sub.submitted_at DESC
    ''', [assignmentId]);
  }

  Future<int> submitAssignment({
    required int assignmentId,
    required String studentId,
    String? studentName,
    required String submissionType,
    String? contentLink,
    String? fileName,
    int? fileSize,
    String? filePath,
    String? notes,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.insert(
      'submissions',
      {
        'assignment_id': assignmentId,
        'student_id': studentId,
        'student_name': studentName,
        'submission_type': submissionType,
        'content_link': contentLink,
        'file_name': fileName,
        'file_size': fileSize,
        'file_path': filePath,
        'notes': notes,
        'submitted_at': now,
        'status': 'submitted',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> gradeSubmission({
    required int submissionId,
    required double grade,
    String? feedback,
    String? gradedBy,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'submissions',
      {
        'grade': grade,
        'feedback': feedback,
        'graded_at': now,
        'graded_by': gradedBy,
        'status': 'graded',
      },
      where: 'id = ?',
      whereArgs: [submissionId],
    );
  }

  Future<int> deleteAssignment(int id) async {
    final db = await database;
    await db.delete('submissions', where: 'assignment_id = ?', whereArgs: [id]);
    return await db.delete('assignments', where: 'id = ?', whereArgs: [id]);
  }
}


