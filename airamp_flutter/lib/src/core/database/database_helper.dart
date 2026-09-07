import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

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
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'airamp_local.db');

    return await openDatabase(
      path,
      version: 13,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
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
      'full_name': 'Aira Admin',
      'section': null,
      'grade': null,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('users', {
      'id': 'teacher_1',
      'email': 'john.reyes@deped.gov.ph',
      'password': 'John@123',
      'role': 'admin',
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
        student_count INTEGER NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');

    // Registration Links Table
    await db.execute('''
      CREATE TABLE reg_links (
        code TEXT PRIMARY KEY,
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
}
