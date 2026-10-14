import '../../../core/constants/firestore_collections.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/attendance_model.dart';
import '../../../models/fee_model.dart';
import '../../../models/school_model.dart';
import '../../../repositories/attendance_repository.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/fee_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';
import '../../../repositories/user_repository.dart';
import '../models/school_summary.dart';

/// One school's summary alongside the records it was derived from, so the
/// district totals can be pooled without reading everything twice.
typedef _SchoolLoad = ({
  SchoolSummary summary,
  List<AttendanceModel> attendance,
  List<FeeModel> fees,
});

/// Gathers the District Dashboard and School List data in one pass.
///
/// Both screens need the same per-school numbers, so the reads and the
/// arithmetic live here once rather than being repeated — and repeated
/// slightly differently — in two controllers.
///
/// Which schools come back is decided by the security rules. This class
/// never filters by role: a query filter is not an authorization boundary.
class DistrictDataLoader {
  final SchoolRepository schoolRepository;
  final StudentRepository studentRepository;
  final UserRepository userRepository;
  final AttendanceRepository attendanceRepository;
  final FeeRepository feeRepository;
  final ExamRepository examRepository;

  const DistrictDataLoader({
    required this.schoolRepository,
    required this.studentRepository,
    required this.userRepository,
    required this.attendanceRepository,
    required this.feeRepository,
    required this.examRepository,
  });

  Future<DistrictData> load() async {
    final schools = await schoolRepository.getSchools();
    final allExams = await examRepository.getAllExams();

    // Exams are already in hand, so each school's count is taken from
    // that list rather than asking Firestore once more per school.
    final examCounts = <String, int>{};
    for (final exam in allExams) {
      examCounts[exam.schoolId] = (examCounts[exam.schoolId] ?? 0) + 1;
    }

    // Per-school reads run together rather than one after another; with a
    // district of any size, sequential round trips dominate load time.
    final loads = await Future.wait(
      schools.map((school) => _loadSchool(school, examCounts)),
    );

    // District figures come from the pooled records, so a large school
    // counts for more than a small one. Averaging the per-school
    // percentages would weigh them equally and overstate small schools.
    final allAttendance = [for (final l in loads) ...l.attendance];
    final allFees = [for (final l in loads) ...l.fees];

    return DistrictData(
      schools: [for (final l in loads) l.summary],
      districtAttendancePercent: Metrics.attendancePercentage(allAttendance),
      districtFeePaidPercent: Metrics.feePaidPercentage(allFees),
      allExams: allExams,
    );
  }

  Future<_SchoolLoad> _loadSchool(
    SchoolModel school,
    Map<String, int> examCounts,
  ) async {
    final students = await studentRepository.getStudentsBySchool(
      school.schoolId,
    );
    final teachers = await userRepository.getUsersBySchoolAndRole(
      schoolId: school.schoolId,
      role: UserRoles.teacher,
    );
    final attendance = await attendanceRepository.getAttendanceBySchool(
      school.schoolId,
    );
    final fees = await feeRepository.getFeesBySchool(school.schoolId);

    return (
      summary: SchoolSummary(
        school: school,
        studentCount: students.length,
        teacherCount: teachers.length,
        attendancePercent: Metrics.attendancePercentage(attendance),
        feePaidPercent: Metrics.feePaidPercentage(fees),
        examCount: examCounts[school.schoolId] ?? 0,
      ),
      attendance: attendance,
      fees: fees,
    );
  }
}
