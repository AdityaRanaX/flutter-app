import '../models/student_model.dart';

/// Reads student records.
///
/// Writing students is not part of any approved EduLens flow yet, so this
/// contract stays read-only rather than guessing at a create/update shape.
abstract class StudentRepository {
  /// Every student at [schoolId]. Backs student counts and the School
  /// Admin's student list.
  Future<List<StudentModel>> getStudentsBySchool(String schoolId);

  /// One student, or null when no such record exists.
  Future<StudentModel?> getStudentById(String studentId);

  /// Students at [schoolId] in [className].
  ///
  /// Exam Details needs this: an exam belongs to one school and one class,
  /// so its student list has to be narrowed on both. Filtering by school
  /// alone would show the whole school as sitting the exam.
  Future<List<StudentModel>> getStudentsBySchoolAndClass({
    required String schoolId,
    required String className,
  });
}
