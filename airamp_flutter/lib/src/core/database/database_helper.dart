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
      version: 8,
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
        created_at TEXT NOT NULL
      )
    ''');

    // Seed default accounts
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
  }
}
