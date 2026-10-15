import '../models/exam_model.dart';

/// Reads and writes examination records.
abstract class ExamRepository {
  /// Every exam at one school.
  Future<List<ExamModel>> getExamsBySchool(String schoolId);

  /// Every exam at [schoolId] for [className].
  Future<List<ExamModel>> getExamsBySchoolAndClass({
    required String schoolId,
    required String className,
  });

  /// Every exam the caller is allowed to read, across all schools.
  ///
  /// The District Exam Overview lists exams district-wide, so it cannot
  /// work school by school. Splitting these into upcoming and past is a
  /// presentation concern and deliberately not done here — the repository
  /// returns the records and the caller filters them.
  Future<List<ExamModel>> getAllExams();

  /// One exam by its id, or null when no such record exists.
  ///
  /// Exam Details is reached by id and not by subject, because several
  /// schools and classes can hold an exam in the same subject.
  Future<ExamModel?> getExamById(String examId);

  /// Creates or replaces an exam, keyed on its `examId`.
  Future<void> saveExam(ExamModel exam);
}
