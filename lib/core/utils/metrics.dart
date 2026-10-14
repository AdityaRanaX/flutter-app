import '../../models/attendance_model.dart';
import '../../models/exam_model.dart';
import '../../models/fee_model.dart';
import 'app_date.dart';

/// Attendance split by status, for the School Details breakdown.
class AttendanceBreakdown {
  final int present;
  final int absent;
  final int leave;

  const AttendanceBreakdown({
    required this.present,
    required this.absent,
    required this.leave,
  });

  int get total => present + absent + leave;
  bool get isEmpty => total == 0;
}

/// Fee records counted by status, for the School Details breakdown.
///
/// This is a different question from [Metrics.feePaidPercentage]: that one
/// is weighted by amount, this one counts records. Both appear in the
/// wireframes and they are not interchangeable.
class FeeBreakdown {
  final int paid;
  final int partial;
  final int outstanding;

  const FeeBreakdown({
    required this.paid,
    required this.partial,
    required this.outstanding,
  });

  int get total => paid + partial + outstanding;
  bool get isEmpty => total == 0;
}

/// The derived numbers the District screens display.
///
/// None of these is stored in Firestore — each is computed from source
/// records, as recorded in the Day 5 data-model gap report. The formulas
/// here are exactly the ones agreed there; nothing is improvised.
///
/// Percentages return `null` rather than `0` when there is nothing to
/// measure, because "no records yet" and "nobody attended" are different
/// facts and a dashboard must not state the second when it means the first.
abstract class Metrics {
  /// Status values, matched case-insensitively so a record written
  /// `present` is not silently counted as an absence.
  static const String statusPresent = 'present';
  static const String statusAbsent = 'absent';
  static const String statusLeave = 'leave';

  static const String feePaid = 'paid';
  static const String feePartial = 'partial';
  static const String feeOutstanding = 'outstanding';

  /// The attendance threshold below which a school needs attention. Stated
  /// explicitly in the District Dashboard wireframe.
  static const double attentionThreshold = 70.0;

  /// `present ÷ all records × 100`, or null when there are no records.
  ///
  /// Anything that is not `Present` counts towards the denominator, so an
  /// approved `Leave` record lowers the percentage without being treated
  /// as an absence.
  static double? attendancePercentage(List<AttendanceModel> records) {
    if (records.isEmpty) return null;
    final present = records
        .where((r) => r.status.trim().toLowerCase() == statusPresent)
        .length;
    return present / records.length * 100;
  }

  /// Attendance counted into Present / Absent / Leave.
  ///
  /// A status that is none of the three is left out of all three counts
  /// rather than being folded into absent, so unexpected data shows up as
  /// a gap instead of a wrong number.
  static AttendanceBreakdown attendanceBreakdown(
    List<AttendanceModel> records,
  ) {
    var present = 0;
    var absent = 0;
    var leave = 0;
    for (final r in records) {
      switch (r.status.trim().toLowerCase()) {
        case statusPresent:
          present++;
        case statusAbsent:
          absent++;
        case statusLeave:
          leave++;
      }
    }
    return AttendanceBreakdown(present: present, absent: absent, leave: leave);
  }

  /// `sum(paidAmount) ÷ sum(totalDue) × 100`, or null when nothing is due.
  ///
  /// Weighted by amount rather than by counting Paid records, so a
  /// part-paid fee is represented honestly.
  static double? feePaidPercentage(List<FeeModel> fees) {
    if (fees.isEmpty) return null;
    var due = 0.0;
    var paid = 0.0;
    for (final f in fees) {
      due += f.totalDue;
      paid += f.paidAmount;
    }
    if (due <= 0) return null;
    return (paid / due * 100).clamp(0, 100).toDouble();
  }

  /// Fee records counted by status.
  static FeeBreakdown feeBreakdown(List<FeeModel> fees) {
    var paid = 0;
    var partial = 0;
    var outstanding = 0;
    for (final f in fees) {
      switch (f.status.trim().toLowerCase()) {
        case feePaid:
          paid++;
        case feePartial:
          partial++;
        case feeOutstanding:
          outstanding++;
      }
    }
    return FeeBreakdown(paid: paid, partial: partial, outstanding: outstanding);
  }

  /// Exams on or after [from], soonest first.
  ///
  /// The source list is never reordered in place — callers hold onto the
  /// repository's result and filter it more than once.
  static List<ExamModel> upcomingExams(
    List<ExamModel> exams, {
    required DateTime from,
  }) {
    final upcoming = exams
        .where((e) => AppDate.isOnOrAfter(e.date, from))
        .toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  /// Exams falling within [days] days of [from], inclusive.
  ///
  /// The dashboard's "upcoming exams" card uses seven days.
  static List<ExamModel> examsWithinDays(
    List<ExamModel> exams, {
    required DateTime from,
    required int days,
  }) {
    final window = exams
        .where((e) => AppDate.isWithinDays(e.date, from, days))
        .toList();
    window.sort((a, b) => a.date.compareTo(b.date));
    return window;
  }

  /// Every exam, soonest first, past ones included.
  static List<ExamModel> sortedByDate(List<ExamModel> exams) {
    final sorted = List<ExamModel>.from(exams);
    sorted.sort((a, b) => a.date.compareTo(b.date));
    return sorted;
  }

  /// A percentage rendered for display, e.g. `72%`, or an em dash when the
  /// value is null so the screen never prints a number it does not have.
  static String formatPercent(double? value) {
    if (value == null) return '—';
    return '${value.round()}%';
  }
}
