import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../models/exam_model.dart';
import '../../../models/student_model.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../repositories/student_repository.dart';

/// One exam plus the information the details screen shows beside it.
class ExamDetails {
  final ExamModel exam;

  /// Null when the school could not be read. The screen then omits it
  /// rather than showing an id.
  final String? schoolName;

  /// Students at the exam's school **and** in its class.
  ///
  /// Narrowed on both, because an exam belongs to one class. Counting the
  /// whole school — or the whole district — would overstate it badly.
  final List<StudentModel> students;

  const ExamDetails({
    required this.exam,
    required this.schoolName,
    required this.students,
  });

  int get totalStudents => students.length;
}

/// Drives the Exam Details screen.
///
/// The exam is fetched by its id. A subject is not an identifier: several
/// schools and classes can hold a Mathematics exam, and the screen must
/// show the one that was tapped.
class ExamDetailsController extends ChangeNotifier {
  final ExamRepository examRepository;
  final SchoolRepository schoolRepository;
  final StudentRepository studentRepository;

  ExamDetailsController({
    required this.examRepository,
    required this.schoolRepository,
    required this.studentRepository,
  });

  ViewState<ExamDetails> _state = const ViewState.loading();
  ViewState<ExamDetails> get state => _state;

  String _query = '';
  String get query => _query;

  /// Students matching the current search, or all of them when the box is
  /// empty. The underlying list is never filtered in place.
  List<StudentModel> get visibleStudents {
    final students = _state.data?.students ?? const <StudentModel>[];
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) return students;
    return students.where((s) => s.name.toLowerCase().contains(term)).toList();
  }

  Future<void> load(String examId) async {
    _state = const ViewState.loading();
    _query = '';
    notifyListeners();

    try {
      final exam = await examRepository.getExamById(examId);
      if (exam == null) {
        // Not-found, not empty. An empty state would suggest the exam
        // exists but has nothing in it, which is a different claim.
        _state = const ViewState.error('This exam could not be found.');
        notifyListeners();
        return;
      }

      // A missing school must not take the screen down — the exam itself
      // is still worth showing.
      String? schoolName;
      try {
        final school = await schoolRepository.getSchoolById(exam.schoolId);
        schoolName = school?.schoolName;
      } catch (_) {
        schoolName = null;
      }

      final students = await studentRepository.getStudentsBySchoolAndClass(
        schoolId: exam.schoolId,
        className: exam.className,
      );

      _state = ViewState.ready(
        ExamDetails(exam: exam, schoolName: schoolName, students: students),
      );
    } catch (e) {
      // Cleared rather than kept, so a failed load cannot leave the
      // previous exam's details on screen.
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  void search(String value) {
    if (value == _query) return;
    _query = value;
    notifyListeners();
  }
}
