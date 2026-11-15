// Realistic Data Fixture for AIRAMP Semester-End Renewal Testing
import 'dart:convert';
import 'package:crypto/crypto.dart';

class AcademicTermFixture {
  final String schoolId;
  final String adminPassword;
  final String adminSalt;
  late final String adminPasswordHash;

  AcademicTermFixture({
    this.schoolId = 'sch_main',
    this.adminPassword = 'AdminSecret2026!',
    this.adminSalt = 'salt_admin_987',
  }) {
    adminPasswordHash = computeHash(adminPassword, adminSalt);
  }

  static String computeHash(String password, String salt) {
    if (salt.isEmpty) return password;
    final bytes = utf8.encode('$password::$salt');
    return sha256.convert(bytes).toString();
  }

  Map<String, dynamic> get adminUser => {
        'id': 'A-100-0001',
        'institutional_id': 'A-100-0001',
        'email': 'admin@school.edu',
        'full_name': 'Christian Campus Admin',
        'role': 'admin',
        'school_id': schoolId,
        'password': adminPasswordHash,
        'password_salt': adminSalt,
        'created_at': '2026-01-10T08:00:00Z',
        'is_active': 1,
      };

  List<Map<String, dynamic>> get teacherUsers => [
        {
          'id': 'T-100-0001',
          'institutional_id': 'T-100-0001',
          'email': 'maria.santos@school.edu',
          'full_name': 'Prof. Maria Santos',
          'role': 'teacher',
          'department': 'Mathematics',
          'school_id': schoolId,
          'password': computeHash('Teacher1Pass!', 'salt_t1'),
          'password_salt': 'salt_t1',
          'created_at': '2026-01-11T08:00:00Z',
          'is_active': 1,
        },
        {
          'id': 'T-100-0002',
          'institutional_id': 'T-100-0002',
          'email': 'jose.rizal@school.edu',
          'full_name': 'Dr. Jose Rizal',
          'role': 'teacher',
          'department': 'Literature',
          'school_id': schoolId,
          'password': computeHash('Teacher2Pass!', 'salt_t2'),
          'password_salt': 'salt_t2',
          'created_at': '2026-01-11T08:30:00Z',
          'is_active': 1,
        },
      ];

  List<Map<String, dynamic>> get studentUsers => [
        {
          'id': 'S-100-0001',
          'institutional_id': 'S-100-0001',
          'email': 'juan.cruz@school.edu',
          'full_name': 'Juan Dela Cruz',
          'role': 'student',
          'section': '10-Rizal',
          'grade_level': 'Grade 10',
          'student_type': 'regular',
          'school_id': schoolId,
          'enrolled_subjects': ['SUBJ-MATH10', 'SUBJ-ENG10'],
          'enrolled_courses': 2,
          'password': computeHash('StudentPass123!', 'salt_s1'),
          'password_salt': 'salt_s1',
          'created_at': '2026-01-12T09:00:00Z',
          'is_active': 1,
        },
        {
          'id': 'S-100-0002',
          'institutional_id': 'S-100-0002',
          'email': 'maria.clara@school.edu',
          'full_name': 'Maria Clara',
          'role': 'student',
          'section': '10-Bonifacio',
          'grade_level': 'Grade 10',
          'student_type': 'regular',
          'school_id': schoolId,
          'enrolled_subjects': ['SUBJ-MATH10'],
          'enrolled_courses': 1,
          'password': computeHash('StudentPass456!', 'salt_s2'),
          'password_salt': 'salt_s2',
          'created_at': '2026-01-12T09:30:00Z',
          'is_active': 1,
        },
      ];

  List<Map<String, dynamic>> get allUsers => [
        adminUser,
        ...teacherUsers,
        ...studentUsers,
      ];

  List<Map<String, dynamic>> get subjects => [
        {
          'id': 'SUBJ-MATH10',
          'name': 'Mathematics 10',
          'code': 'MATH10',
          'teacher_id': 'T-100-0001',
          'school_id': schoolId,
          'grade_level': 'Grade 10',
          'semester': 'Semester 1',
        },
        {
          'id': 'SUBJ-ENG10',
          'name': 'English Literature 10',
          'code': 'ENG10',
          'teacher_id': 'T-100-0002',
          'school_id': schoolId,
          'grade_level': 'Grade 10',
          'semester': 'Semester 1',
        },
      ];

  List<Map<String, dynamic>> get modules => [
        {
          'id': 'MOD-101',
          'subject_id': 'SUBJ-MATH10',
          'title': 'Algebraic Equations',
          'order': 1,
        },
        {
          'id': 'MOD-102',
          'subject_id': 'SUBJ-MATH10',
          'title': 'Plane Geometry',
          'order': 2,
        },
        {
          'id': 'MOD-201',
          'subject_id': 'SUBJ-ENG10',
          'title': 'Introduction to Drama',
          'order': 1,
        },
      ];

  List<Map<String, dynamic>> get quizzes => [
        {
          'id': 'QUIZ-101',
          'subject_id': 'SUBJ-MATH10',
          'title': 'Algebra Midterm Exam',
          'max_score': 100,
          'passing_score': 75,
        },
        {
          'id': 'QUIZ-102',
          'subject_id': 'SUBJ-MATH10',
          'title': 'Geometry Final Exam',
          'max_score': 100,
          'passing_score': 75,
        },
        {
          'id': 'QUIZ-201',
          'subject_id': 'SUBJ-ENG10',
          'title': 'Shakespeare Reading Quiz',
          'max_score': 100,
          'passing_score': 70,
        },
      ];

  List<Map<String, dynamic>> get quizAssignments => [
        {
          'id': 'QASG-101',
          'quiz_id': 'QUIZ-101',
          'section': '10-Rizal',
          'assigned_date': '2026-02-01T08:00:00Z',
        },
        {
          'id': 'QASG-102',
          'quiz_id': 'QUIZ-102',
          'section': '10-Rizal',
          'assigned_date': '2026-03-01T08:00:00Z',
        },
      ];

  List<Map<String, dynamic>> get quizAttempts => [
        {
          'id': 'QATT-001',
          'quiz_id': 'QUIZ-101',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-MATH10',
          'score': 95.0,
          'max_score': 100,
          'percentage': 95.0,
          'is_completed': 1,
          'completed_at': '2026-02-05T10:30:00Z',
        },
        {
          'id': 'QATT-002',
          'quiz_id': 'QUIZ-102',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-MATH10',
          'score': 91.0,
          'max_score': 100,
          'percentage': 91.0,
          'is_completed': 1,
          'completed_at': '2026-03-10T11:00:00Z',
        },
        {
          'id': 'QATT-003',
          'quiz_id': 'QUIZ-201',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-ENG10',
          'score': 88.0,
          'max_score': 100,
          'percentage': 88.0,
          'is_completed': 1,
          'completed_at': '2026-03-12T14:00:00Z',
        },
        {
          'id': 'QATT-004',
          'quiz_id': 'QUIZ-101',
          'student_id': 'S-100-0002',
          'subject_id': 'SUBJ-MATH10',
          'score': 85.0,
          'max_score': 100,
          'percentage': 85.0,
          'is_completed': 1,
          'completed_at': '2026-02-05T11:00:00Z',
        },
      ];

  List<Map<String, dynamic>> get assignments => [
        {
          'id': 'ASG-101',
          'subject_id': 'SUBJ-MATH10',
          'title': 'Problem Set 1: Quadratic Equations',
          'max_points': 100,
        },
        {
          'id': 'ASG-201',
          'subject_id': 'SUBJ-ENG10',
          'title': 'Essay: Themes in Hamlet',
          'max_points': 100,
        },
      ];

  List<Map<String, dynamic>> get submissions => [
        {
          'id': 'SUB-001',
          'assignment_id': 'ASG-101',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-MATH10',
          'grade': 94.0,
          'status': 'graded',
          'submitted_at': '2026-02-10T18:00:00Z',
        },
        {
          'id': 'SUB-002',
          'assignment_id': 'ASG-201',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-ENG10',
          'grade': 90.0,
          'status': 'graded',
          'submitted_at': '2026-02-20T20:00:00Z',
        },
        {
          'id': 'SUB-003',
          'assignment_id': 'ASG-101',
          'student_id': 'S-100-0002',
          'subject_id': 'SUBJ-MATH10',
          'grade': 82.0,
          'status': 'graded',
          'submitted_at': '2026-02-10T19:30:00Z',
        },
      ];

  List<Map<String, dynamic>> get moduleFlashcards => [
        {
          'id': 'FC-001',
          'module_id': 'MOD-101',
          'front': 'Quadratic Formula',
          'back': 'x = (-b ± √(b² - 4ac)) / (2a)',
        },
        {
          'id': 'FC-002',
          'module_id': 'MOD-102',
          'front': 'Pythagorean Theorem',
          'back': 'a² + b² = c²',
        },
      ];

  List<Map<String, dynamic>> get classSchedules => [
        {
          'id': 'SCHED-001',
          'subject_id': 'SUBJ-MATH10',
          'day': 'Monday',
          'start_time': '08:00',
          'end_time': '09:30',
          'room': 'Room 301',
        },
      ];

  List<Map<String, dynamic>> get enrollmentKeys => [
        {
          'id': 'EKEY-001',
          'subject_id': 'SUBJ-MATH10',
          'key': 'MATH10-SEC-RIZAL',
          'is_used': 1,
        },
      ];

  List<Map<String, dynamic>> get regLinks => [
        {
          'id': 'REGLINK-001',
          'section': '10-Rizal',
          'token': 'tok_reg_rizal_2026',
          'is_active': 1,
        },
      ];

  /// Generates a large collection of transient records (e.g. 450 documents)
  /// specifically to test batch chunking and Firestore 500-operation limits.
  static List<Map<String, dynamic>> generateLargeSubmissionsBatch(int count) {
    return List.generate(count, (index) => {
          'id': 'LARGE-SUB-${index.toString().padLeft(4, '0')}',
          'assignment_id': 'ASG-101',
          'student_id': 'S-100-0001',
          'subject_id': 'SUBJ-MATH10',
          'grade': 85.0 + (index % 15),
          'status': 'graded',
          'submitted_at': '2026-03-01T10:00:00Z',
        });
  }
}
