import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/utils/app_date.dart';
import 'package:my_flutter_edulens/core/utils/metrics.dart';

import 'support/fake_repositories.dart';

void main() {
  group('AppDate', () {
    test('parses the stored yyyy-MM-dd format', () {
      final d = AppDate.tryParse('2026-10-16');
      expect(d, DateTime(2026, 10, 16));
    });

    test('a malformed or missing date is null, never a thrown error', () {
      // One bad document must not be able to take a whole screen down.
      expect(AppDate.tryParse(null), isNull);
      expect(AppDate.tryParse(''), isNull);
      expect(AppDate.tryParse('16 Oct 2026'), isNull);
      expect(AppDate.tryParse('not a date'), isNull);
    });

    test('parsing strips the time, so comparisons are by calendar day', () {
      expect(AppDate.tryParse('2026-10-16T14:30:00'), DateTime(2026, 10, 16));
    });

    test('today is on or after today — an exam does not vanish mid-day', () {
      final today = DateTime(2026, 10, 14);
      expect(AppDate.isOnOrAfter('2026-10-14', today), isTrue);
      expect(AppDate.isOnOrAfter('2026-10-15', today), isTrue);
      expect(AppDate.isOnOrAfter('2026-10-13', today), isFalse);
    });

    test('the seven-day window includes both ends', () {
      final from = DateTime(2026, 10, 14);
      expect(AppDate.isWithinDays('2026-10-14', from, 7), isTrue);
      expect(AppDate.isWithinDays('2026-10-21', from, 7), isTrue);
      expect(AppDate.isWithinDays('2026-10-22', from, 7), isFalse);
      expect(AppDate.isWithinDays('2026-10-13', from, 7), isFalse);
    });

    test('an unparseable date is excluded from windows, not assumed', () {
      final from = DateTime(2026, 10, 14);
      expect(AppDate.isWithinDays('whenever', from, 7), isFalse);
      expect(AppDate.isOnOrAfter('whenever', from), isFalse);
    });

    test('formats for display, leaving bad input visible', () {
      expect(AppDate.formatLong('2026-10-16'), '16 Oct 2026');
      expect(
        AppDate.formatWithTime('2026-10-16', '10:00'),
        '16 Oct 2026 · 10:00',
      );
      // Not replaced with a placeholder — bad data should stay obvious.
      expect(AppDate.formatLong('garbage'), 'garbage');
    });
  });

  group('Attendance percentage', () {
    test('is present over all records', () {
      final records = [
        attendance('1', schoolId: 's1', status: 'Present'),
        attendance('2', schoolId: 's1', status: 'Present'),
        attendance('3', schoolId: 's1', status: 'Present'),
        attendance('4', schoolId: 's1', status: 'Absent'),
      ];
      expect(Metrics.attendancePercentage(records), 75.0);
    });

    test('no records is null, not zero', () {
      // "Nobody attended" and "nothing recorded yet" are different facts,
      // and a dashboard must not state the first when it means the second.
      expect(Metrics.attendancePercentage([]), isNull);
    });

    test('status matching ignores case', () {
      final records = [
        attendance('1', schoolId: 's1', status: 'present'),
        attendance('2', schoolId: 's1', status: 'PRESENT'),
      ];
      expect(Metrics.attendancePercentage(records), 100.0);
    });

    test('Leave lowers the percentage without counting as an absence', () {
      final records = [
        attendance('1', schoolId: 's1', status: 'Present'),
        attendance('2', schoolId: 's1', status: 'Leave'),
      ];
      expect(Metrics.attendancePercentage(records), 50.0);

      final breakdown = Metrics.attendanceBreakdown(records);
      expect(breakdown.present, 1);
      expect(breakdown.leave, 1);
      expect(breakdown.absent, 0);
    });

    test('an unrecognised status is counted in no bucket', () {
      final breakdown = Metrics.attendanceBreakdown([
        attendance('1', schoolId: 's1', status: 'Present'),
        attendance('2', schoolId: 's1', status: 'Holiday'),
      ]);
      expect(breakdown.present, 1);
      expect(breakdown.absent, 0);
      expect(breakdown.leave, 0);
      // It still counted towards the percentage's denominator.
      expect(breakdown.total, 1);
    });
  });

  group('Fee percentage', () {
    test('is weighted by amount, not by counting paid records', () {
      final fees = [
        fee(
          '1',
          schoolId: 's1',
          totalDue: 1000,
          paidAmount: 1000,
          status: 'Paid',
        ),
        fee(
          '2',
          schoolId: 's1',
          totalDue: 1000,
          paidAmount: 0,
          status: 'Outstanding',
        ),
      ];
      expect(Metrics.feePaidPercentage(fees), 50.0);
    });

    test('a part payment is represented honestly', () {
      final fees = [
        fee(
          '1',
          schoolId: 's1',
          totalDue: 1000,
          paidAmount: 250,
          status: 'Partial',
        ),
      ];
      // Counting statuses would call this 0% paid, which is not true.
      expect(Metrics.feePaidPercentage(fees), 25.0);
    });

    test('nothing due is null, not 100%', () {
      expect(Metrics.feePaidPercentage([]), isNull);
      expect(
        Metrics.feePaidPercentage([
          fee('1', schoolId: 's1', totalDue: 0, paidAmount: 0, status: 'Paid'),
        ]),
        isNull,
      );
    });

    test('an overpayment is capped at 100%', () {
      final fees = [
        fee(
          '1',
          schoolId: 's1',
          totalDue: 100,
          paidAmount: 250,
          status: 'Paid',
        ),
      ];
      expect(Metrics.feePaidPercentage(fees), 100.0);
    });

    test('the breakdown counts records, which is a different question', () {
      final fees = [
        fee(
          '1',
          schoolId: 's1',
          totalDue: 100,
          paidAmount: 100,
          status: 'Paid',
        ),
        fee(
          '2',
          schoolId: 's1',
          totalDue: 100,
          paidAmount: 50,
          status: 'Partial',
        ),
        fee(
          '3',
          schoolId: 's1',
          totalDue: 100,
          paidAmount: 0,
          status: 'Outstanding',
        ),
      ];
      final b = Metrics.feeBreakdown(fees);
      expect(b.paid, 1);
      expect(b.partial, 1);
      expect(b.outstanding, 1);
      expect(b.total, 3);
      // Weighted percentage disagrees with "1 of 3 paid", on purpose.
      expect(Metrics.feePaidPercentage(fees), 50.0);
    });
  });

  group('Exam filtering', () {
    final now = DateTime(2026, 10, 14);
    final exams = [
      exam('past', schoolId: 's1', date: '2026-10-06'),
      exam('today', schoolId: 's1', date: '2026-10-14'),
      exam('soon', schoolId: 's1', date: '2026-10-19'),
      exam('edge', schoolId: 's1', date: '2026-10-21'),
      exam('later', schoolId: 's1', date: '2026-11-03'),
    ];

    test('upcoming excludes the past and includes today', () {
      final upcoming = Metrics.upcomingExams(exams, from: now);
      expect(upcoming.map((e) => e.examId), ['today', 'soon', 'edge', 'later']);
    });

    test('the seven-day window stops at day seven inclusive', () {
      final window = Metrics.examsWithinDays(exams, from: now, days: 7);
      expect(window.map((e) => e.examId), ['today', 'soon', 'edge']);
    });

    test('results are sorted soonest first', () {
      final shuffled = [exams[4], exams[1], exams[3], exams[2]];
      final upcoming = Metrics.upcomingExams(shuffled, from: now);
      expect(upcoming.map((e) => e.date).toList(), [
        '2026-10-14',
        '2026-10-19',
        '2026-10-21',
        '2026-11-03',
      ]);
    });

    test('filtering never reorders the caller\'s list', () {
      final original = List.of(exams);
      Metrics.upcomingExams(original, from: now);
      Metrics.sortedByDate(original);
      expect(original.map((e) => e.examId).toList(), [
        'past',
        'today',
        'soon',
        'edge',
        'later',
      ]);
    });

    test('an exam with an unreadable date is left out of both lists', () {
      final broken = [exam('broken', schoolId: 's1', date: '10 Oct 2026')];
      expect(Metrics.upcomingExams(broken, from: now), isEmpty);
      expect(Metrics.examsWithinDays(broken, from: now, days: 7), isEmpty);
    });
  });

  group('formatPercent', () {
    test('rounds to a whole number', () {
      expect(Metrics.formatPercent(72.4), '72%');
      expect(Metrics.formatPercent(72.6), '73%');
    });

    test('null prints a dash rather than a number it does not have', () {
      expect(Metrics.formatPercent(null), '—');
    });
  });
}
