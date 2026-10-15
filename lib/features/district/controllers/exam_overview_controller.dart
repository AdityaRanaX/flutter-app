import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/school_repository.dart';

/// Which exams the overview is showing.
enum ExamFilter {
  /// On or after today.
  upcoming,

  /// Everything, past exams included.
  all,
}

/// Drives the District Exam Overview.
///
/// Exams and schools are read once; switching between Upcoming and All
/// filters what is already in memory rather than querying again, because
/// the toggle changes the view and not the underlying data.
class ExamOverviewController extends ChangeNotifier {
  final ExamRepository examRepository;
  final SchoolRepository schoolRepository;

  /// Injectable so the upcoming/past boundary can be tested without
  /// waiting for the calendar.
  final DateTime Function() clock;

  ExamOverviewController({
    required this.examRepository,
    required this.schoolRepository,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<List<ExamModel>> _state = const ViewState.loading();
  ViewState<List<ExamModel>> get state => _state;

  ExamFilter _filter = ExamFilter.upcoming;
  ExamFilter get filter => _filter;

  /// Every exam that was read, kept so switching the filter never needs a
  /// reload and never mutates what the repository returned.
  List<ExamModel> _all = const [];

  /// School names by id, resolved once for the whole list. An exam stores
  /// only a `schoolId`, but the wireframe shows the school's name.
  Map<String, String> _schoolNames = const {};

  /// The school's name, or null when no such school could be read.
  ///
  /// Returning null rather than the id keeps a fabricated-looking name off
  /// the screen; the row drops the school instead.
  String? schoolNameFor(ExamModel exam) {
    final name = _schoolNames[exam.schoolId];
    if (name == null || name.trim().isEmpty) return null;
    return name;
  }

  Future<void> load() async {
    _state = const ViewState.loading();
    notifyListeners();

    try {
      final exams = await examRepository.getAllExams();
      final schools = await schoolRepository.getSchools();

      _all = exams;
      _schoolNames = {for (final s in schools) s.schoolId: s.schoolName};
      _state = _buildState();
    } catch (e) {
      _all = const [];
      _schoolNames = const {};
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  void setFilter(ExamFilter value) {
    if (value == _filter) return;
    _filter = value;
    // Only re-derive once data has arrived, so toggling during a load or
    // after a failure cannot turn an error into an empty list.
    if (_state.isReady || _state.status == ViewStatus.empty) {
      _state = _buildState();
      notifyListeners();
    }
  }

  ViewState<List<ExamModel>> _buildState() {
    final today = AppDate.today(clock());

    final visible = switch (_filter) {
      ExamFilter.upcoming => Metrics.upcomingExams(_all, from: today),
      ExamFilter.all => Metrics.sortedByDate(_all),
    };

    return ViewState.fromList(
      visible,
      // The two empty cases mean different things, and saying "no exams"
      // when there are past ones would be wrong.
      emptyMessage: _filter == ExamFilter.upcoming
          ? 'No exams are scheduled from today onwards.'
          : 'No exams have been scheduled yet.',
    );
  }
}
