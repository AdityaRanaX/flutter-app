// Development seeding tool — NOT part of the EduLens app.
//
// It signs in with a development account and writes a small, realistic
// dataset so the District screens have something to show during manual
// QA. Credentials are passed in at run time, never stored in the repo.
//
// Run it with:
//
//   flutter run -t tool/seed_firestore.dart -d chrome \
//     --dart-define=SEED_EMAIL=edulens.test@gmail.com \
//     --dart-define=SEED_PASSWORD=your-dev-password
//
// Re-running is safe: every document is written with an explicit id, so
// a second run overwrites the first rather than duplicating records.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:my_flutter_edulens/firebase_options.dart';

const String kSeedEmail = String.fromEnvironment('SEED_EMAIL');
const String kSeedPassword = String.fromEnvironment('SEED_PASSWORD');

/// Today, as the seeded data assumes it. Exam dates are placed relative
/// to this so the "next seven days" window and the Upcoming/All toggle
/// both have records on either side of the boundary.
final DateTime kToday = DateTime.now();

/// A date [offsetDays] away from today, as the `yyyy-MM-dd` string the
/// models expect. Stored as text, not a Firestore timestamp, because
/// every model reads these fields with `as String?`.
String _day(int offsetDays) {
  final d = kToday.add(Duration(days: offsetDays));
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '${d.year}-$mm-$dd';
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const SeedApp());
}

class SeedApp extends StatelessWidget {
  const SeedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduLens Seed',
      debugShowCheckedModeBanner: false,
      home: const SeedScreen(),
    );
  }
}

class SeedScreen extends StatefulWidget {
  const SeedScreen({super.key});

  @override
  State<SeedScreen> createState() => _SeedScreenState();
}

class _SeedScreenState extends State<SeedScreen> {
  final List<String> _log = [];
  bool _running = false;
  bool _done = false;
  bool _failed = false;

  void _say(String line) {
    debugPrint(line);
    if (mounted) setState(() => _log.add(line));
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _failed = false;
      _done = false;
      _log.clear();
    });

    try {
      if (kSeedEmail.isEmpty || kSeedPassword.isEmpty) {
        throw StateError(
          'Missing credentials. Pass --dart-define=SEED_EMAIL=... and '
          '--dart-define=SEED_PASSWORD=... when running this tool.',
        );
      }

      final auth = FirebaseAuth.instance;
      final db = FirebaseFirestore.instance;

      _say('Signing in as $kSeedEmail ...');
      final cred = await auth.signInWithEmailAndPassword(
        email: kSeedEmail,
        password: kSeedPassword,
      );
      final uid = cred.user!.uid;
      _say('Signed in. UID: $uid');

      // The security rules deliberately stop a signed-in user from making
      // themselves a district admin: self-create is limited to the student
      // role, and self-update cannot change `role`. So this tool cannot
      // bootstrap its own privileges — it can only check that somebody
      // already granted them from the Firebase console, which bypasses
      // rules. Every write below depends on that having happened.
      _say('Checking your profile and role ...');
      final profile = await db.collection('users').doc(uid).get();
      if (!profile.exists) {
        throw StateError(
          'No users/$uid document exists.\n\n'
          'Create it by hand in the Firebase console (console writes skip '
          'the security rules), with these fields:\n'
          '  uid      (string) $uid\n'
          '  name     (string) your name\n'
          '  email    (string) $kSeedEmail\n'
          '  role     (string) districtAdmin\n'
          '  schoolId (string) leave empty\n\n'
          'Then run this tool again.',
        );
      }
      final role = profile.data()?['role'];
      if (role != 'districtAdmin' && role != 'district_admin') {
        throw StateError(
          'users/$uid has role "$role", but seeding needs "districtAdmin".\n\n'
          'The rules do not let you change your own role, so edit the '
          'document in the Firebase console and run this tool again.',
        );
      }
      _say('  users/$uid — role "$role". Good.');

      await _seedSchools(db);
      await _seedTeachers(db);
      await _seedStudents(db);
      await _seedAttendance(db);
      await _seedFees(db);
      await _seedExams(db);

      _say('');
      _say('Done. Sign in to the app as $kSeedEmail to see the data.');
      setState(() => _done = true);
    } catch (e) {
      _say('');
      _say('FAILED: $e');
      setState(() => _failed = true);
    } finally {
      setState(() => _running = false);
    }
  }

  // ---------------------------------------------------------------- schools

  static const List<Map<String, String>> _schools = [
    {
      'schoolId': 'school01',
      'schoolName': 'Greenwood High',
      'location': 'Sector 12, North District',
    },
    {
      'schoolId': 'school02',
      'schoolName': 'Riverside Public School',
      'location': 'Sector 45, East District',
    },
    {
      'schoolId': 'school03',
      'schoolName': 'Hilltop Academy',
      'location': 'Sector 7, West District',
    },
  ];

  Future<void> _seedSchools(FirebaseFirestore db) async {
    _say('Writing schools ...');
    for (final s in _schools) {
      await db.collection('schools').doc(s['schoolId']).set(s);
      _say('  schools/${s['schoolId']} — ${s['schoolName']}');
    }
  }

  // --------------------------------------------------------------- teachers

  /// Teacher profiles exist so the School List can derive a teacher count
  /// from users where role == teacher. They are profile records only;
  /// they have no Firebase Auth accounts behind them.
  Future<void> _seedTeachers(FirebaseFirestore db) async {
    _say('Writing teacher profiles ...');
    const names = {
      'school01': ['Priya Sharma', 'Rahul Verma', 'Neha Iyer'],
      'school02': ['Arjun Nair', 'Kavita Rao'],
      'school03': ['Sanjay Mehta', 'Divya Pillai', 'Imran Khan', 'Rita Das'],
    };
    for (final entry in names.entries) {
      final schoolId = entry.key;
      for (var i = 0; i < entry.value.length; i++) {
        final id = '$schoolId-teacher${i + 1}';
        await db.collection('users').doc(id).set({
          'uid': id,
          'name': entry.value[i],
          'email': '$id@edulens.test',
          'role': 'teacher',
          'schoolId': schoolId,
        });
      }
      _say('  $schoolId — ${entry.value.length} teachers');
    }
  }

  // --------------------------------------------------------------- students

  /// Six students per school, split across two classes, so Exam Details
  /// can filter by schoolId + className and get a sensible subset.
  List<Map<String, String>> _studentsFor(String schoolId) {
    const firstNames = ['Ananya', 'Rohan', 'Ishita', 'Vikram', 'Meera', 'Karan'];
    const lastNames = ['Shah', 'Kumar', 'Banerjee', 'Gupta', 'Reddy', 'Joshi'];
    return List.generate(6, (i) {
      return {
        'studentId': '$schoolId-student${i + 1}',
        'name': '${firstNames[i]} ${lastNames[i]}',
        'schoolId': schoolId,
        'className': i < 3 ? 'Class 10' : 'Class 9',
        'section': i.isEven ? 'A' : 'B',
      };
    });
  }

  Future<void> _seedStudents(FirebaseFirestore db) async {
    _say('Writing students ...');
    for (final s in _schools) {
      final schoolId = s['schoolId']!;
      for (final student in _studentsFor(schoolId)) {
        await db.collection('students').doc(student['studentId']).set(student);
      }
      _say('  $schoolId — 6 students');
    }
  }

  // ------------------------------------------------------------- attendance

  /// Attendance percentages are set deliberately per school so the
  /// dashboard's "attendance below 70%" attention rule has exactly one
  /// school that trips it (school03) and two that do not.
  static const Map<String, double> _attendanceTargets = {
    'school01': 0.85,
    'school02': 0.72,
    'school03': 0.61,
  };

  Future<void> _seedAttendance(FirebaseFirestore db) async {
    _say('Writing attendance ...');
    final dates = [_day(-3), _day(-2), _day(-1)];

    for (final s in _schools) {
      final schoolId = s['schoolId']!;
      final students = _studentsFor(schoolId);
      final total = students.length * dates.length;
      final presentTarget = (total * _attendanceTargets[schoolId]!).round();

      var written = 0;
      for (final date in dates) {
        for (final student in students) {
          final status = written < presentTarget ? 'Present' : 'Absent';
          final id = '${student['studentId']}-$date';
          await db.collection('attendance').doc(id).set({
            'attendanceId': id,
            'studentId': student['studentId'],
            'schoolId': schoolId,
            'teacherId': '$schoolId-teacher1',
            'date': date,
            'status': status,
          });
          written++;
        }
      }
      final pct = (presentTarget / total * 100).toStringAsFixed(0);
      _say('  $schoolId — $total records, $presentTarget present (~$pct%)');
    }
  }

  // ------------------------------------------------------------------- fees

  /// One fee record per student, cycling Paid / Partial / Outstanding so
  /// the fee breakdown on School Details has all three buckets filled.
  Future<void> _seedFees(FirebaseFirestore db) async {
    _say('Writing fees ...');
    const totalDue = 25000.0;
    final updatedAt = _day(-5);

    for (final s in _schools) {
      final schoolId = s['schoolId']!;
      final students = _studentsFor(schoolId);
      for (var i = 0; i < students.length; i++) {
        final student = students[i];
        final String status;
        final double paid;
        switch (i % 3) {
          case 0:
            status = 'Paid';
            paid = totalDue;
          case 1:
            status = 'Partial';
            paid = 12000.0;
          default:
            status = 'Outstanding';
            paid = 0.0;
        }
        final id = '${student['studentId']}-fee';
        await db.collection('fees').doc(id).set({
          'feeId': id,
          'studentId': student['studentId'],
          'schoolId': schoolId,
          'totalDue': totalDue,
          'paidAmount': paid,
          'status': status,
          'updatedAt': updatedAt,
        });
      }
      _say('  $schoolId — 6 fee records (2 paid, 2 partial, 2 outstanding)');
    }
  }

  // ------------------------------------------------------------------ exams

  /// Exam dates straddle two boundaries on purpose: past vs future (the
  /// Upcoming/All toggle) and inside vs outside seven days (the
  /// dashboard's upcoming-exams count).
  Future<void> _seedExams(FirebaseFirestore db) async {
    _say('Writing exams ...');
    final rows = <Map<String, String>>[
      // Already happened — All Exams only.
      {'s': 'school01', 'c': 'Class 10', 'sub': 'Mathematics', 'd': _day(-8)},
      {'s': 'school02', 'c': 'Class 9', 'sub': 'History', 'd': _day(-4)},
      // Inside the next seven days — counted on the dashboard.
      {'s': 'school01', 'c': 'Class 10', 'sub': 'Science', 'd': _day(2)},
      {'s': 'school02', 'c': 'Class 10', 'sub': 'English', 'd': _day(5)},
      {'s': 'school03', 'c': 'Class 9', 'sub': 'Geography', 'd': _day(7)},
      // Upcoming, but beyond seven days — excluded from that count.
      {'s': 'school01', 'c': 'Class 9', 'sub': 'Hindi', 'd': _day(20)},
      {'s': 'school03', 'c': 'Class 10', 'sub': 'Computer Science', 'd': _day(33)},
    ];

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final id = 'exam${(i + 1).toString().padLeft(2, '0')}';
      await db.collection('exams').doc(id).set({
        'examId': id,
        'schoolId': r['s'],
        'className': r['c'],
        'subject': r['sub'],
        'date': r['d'],
        'startTime': '10:00',
        'endTime': '12:00',
        'createdBy': '${r['s']}-teacher1',
      });
      _say('  $id — ${r['sub']} @ ${r['d']} (${r['s']})');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EduLens — seed Firestore')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton.icon(
              onPressed: _running ? null : _run,
              icon: _running
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_running ? 'Seeding...' : 'Seed Firestore'),
            ),
            const SizedBox(height: 16),
            if (_done)
              const Text(
                'Seeding complete.',
                style: TextStyle(color: Colors.green),
              ),
            if (_failed)
              const Text(
                'Seeding failed — see the log below.',
                style: TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: const Color(0xFFF5F5F5),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _log.isEmpty
                        ? 'Press "Seed Firestore" to begin.'
                        : _log.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
