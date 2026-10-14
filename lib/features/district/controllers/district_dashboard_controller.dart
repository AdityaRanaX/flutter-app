import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../models/school_summary.dart';
import 'district_data_loader.dart';

/// Drives the District Dashboard.
///
/// It coordinates the repository reads and prepares the numbers the cards
/// show. The widgets below it only lay data out; they never query
/// Firestore and never calculate a metric themselves.
///
/// A plain [ChangeNotifier] is used on purpose — four cards and a list do
/// not justify adding a state-management package.
class DistrictDashboardController extends ChangeNotifier {
  final DistrictDataLoader loader;

  /// How far ahead the "upcoming exams" card looks.
  static const int upcomingExamWindowDays = 7;

  /// Injectable so time-dependent behaviour can be tested without waiting
  /// for the calendar to catch up.
  final DateTime Function() clock;

  DistrictDashboardController({
    required this.loader,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<DistrictData> _state = const ViewState.loading();
  ViewState<DistrictData> get state => _state;

  Future<void> load() async {
    _state = const ViewState.loading();
    notifyListeners();

    try {
      final data = await loader.load();
      // No schools is a successful but empty district, not a failure.
      _state = data.isEmpty
          ? const ViewState.empty(
              message: 'No schools have been added to this district yet.',
            )
          : ViewState.ready(data);
    } catch (e) {
      // fromError is what keeps a permission denial out of the error
      // state and in the unauthorized one.
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  // ------------------------------------------------------------ derived

  DistrictData? get _data => _state.data;

  int get totalSchools => _data?.totalSchools ?? 0;

  double? get averageAttendance => _data?.districtAttendancePercent;

  double? get feesPaidPercent => _data?.districtFeePaidPercent;

  /// Exams inside the next seven days, soonest first.
  List<ExamModel> get upcomingExams {
    final data = _data;
    if (data == null) return const [];
    return Metrics.examsWithinDays(
      data.allExams,
      from: AppDate.today(clock()),
      days: upcomingExamWindowDays,
    );
  }

  /// Schools below the attendance threshold the wireframe specifies.
  ///
  /// Only the attendance condition is implemented. The wireframe also
  /// shows a "high fee outstanding" flag, but no approved threshold for it
  /// exists, so inventing a number would mean presenting a judgement the
  /// project never agreed to.
  List<SchoolSummary> get attentionAreas {
    final data = _data;
    if (data == null) return const [];
    final flagged = data.schools
        .where((s) => s.needsAttention(Metrics.attentionThreshold))
        .toList();
    flagged.sort(
      (a, b) => (a.attendancePercent ?? 0).compareTo(b.attendancePercent ?? 0),
    );
    return flagged;
  }
}
