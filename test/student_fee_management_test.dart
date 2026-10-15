import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/core/widgets/app_text_field.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/student_fee_management_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/screens/student_fee_management_screen.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

class _StudentFeeFixture {
  final students = FakeStudentRepository();
  final fees = FakeFeeRepository();

  void seed() {
    students.students.addAll([
      const StudentModel(
        studentId: 'st1',
        name: 'Alice Smith',
        schoolId: 's1',
        className: '10',
        section: 'A',
        rollNumber: 'RN-101',
      ),
      const StudentModel(
        studentId: 'st2',
        name: 'Bob Jones',
        schoolId: 's1',
        className: '10',
        section: 'B',
        // rollNumber is null for Bob
      ),
      const StudentModel(
        studentId: 'st3',
        name: 'Charlie Brown',
        schoolId: 's2', // Other school
        className: '10',
        section: 'A',
      ),
    ]);

    fees.fees.addAll([
      const FeeModel(
        feeId: 'f1',
        studentId: 'st1',
        schoolId: 's1',
        totalDue: 1000,
        paidAmount: 500,
        status: 'Partial',
        updatedAt: '2026-03-30',
        remarks: 'Paid via online transfer',
      ),
      const FeeModel(
        feeId: 'f2',
        studentId: 'st2',
        schoolId: 's1',
        totalDue: 1000,
        paidAmount: 400,
        status: 'Partial',
        updatedAt: '2026-03-30',
      ),
    ]);
  }
}

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  group('StudentFeeManagementController Unit Tests', () {
    test('loads student and fee records for authorized school only', () async {
      final f = _StudentFeeFixture()..seed();
      final controller = StudentFeeManagementController(
        studentRepository: f.students,
        feeRepository: f.fees,
      );

      await controller.load(schoolId: 's1');

      expect(controller.state.status, ViewStatus.ready);
      final data = controller.state.data!;
      expect(data.totalStudents, 2);
      expect(data.items.length, 2);
      expect(data.items[0].student.name, 'Alice Smith');
      expect(data.items[0].student.rollNumber, 'RN-101');
      expect(data.items[0].fee?.status, 'Partial');
      expect(data.items[1].student.name, 'Bob Jones');
      expect(data.items[1].student.rollNumber, isNull);
      expect(data.items[1].fee?.status, 'Partial');
    });

    test('preserves immutable fields (feeId, studentId, schoolId, totalDue) on update', () async {
      final f = _StudentFeeFixture()..seed();
      final controller = StudentFeeManagementController(
        studentRepository: f.students,
        feeRepository: f.fees,
      );

      await controller.load(schoolId: 's1');

      final initialFee = f.fees.fees.firstWhere(
        (element) => element.feeId == 'f2',
      );

      final success = await controller.updateFeeRecord(
        currentFee: initialFee,
        newStatus: 'Paid',
        newPaidAmount: 1000,
        newRemarks: 'Settled full balance',
      );

      expect(success, isTrue);

      final updatedFee = f.fees.fees.firstWhere(
        (element) => element.feeId == 'f2',
      );
      expect(updatedFee.feeId, 'f2');
      expect(updatedFee.studentId, 'st2');
      expect(updatedFee.schoolId, 's1');
      expect(updatedFee.totalDue, 1000); // Preserved
      expect(updatedFee.paidAmount, 1000); // Updated
      expect(updatedFee.status, 'Paid'); // Updated
      expect(updatedFee.remarks, 'Settled full balance'); // Updated
    });

    test(
      'maps repository failure to error state without corrupting UI',
      () async {
        final f = _StudentFeeFixture()..seed();
        f.students.failWith = RepositoryErrorKind.permissionDenied;

        final controller = StudentFeeManagementController(
          studentRepository: f.students,
          feeRepository: f.fees,
        );

        await controller.load(schoolId: 's1');

        expect(controller.state.status, ViewStatus.unauthorized);
      },
    );
  });

  group('StudentFeeManagementScreen Widget Tests', () {
    testWidgets(
      'renders student list, roll number, and missing roll number gracefully',
      (tester) async {
        final f = _StudentFeeFixture()..seed();
        final controller = StudentFeeManagementController(
          studentRepository: f.students,
          feeRepository: f.fees,
        );

        await controller.load(schoolId: 's1');

        await tester.pumpWidget(
          _wrap(
            StudentFeeManagementScreen(controller: controller, schoolId: 's1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Alice Smith'), findsOneWidget);
        expect(find.text('Class 10-A • Roll No: RN-101'), findsOneWidget);
        expect(find.text('Bob Jones'), findsOneWidget);
        expect(find.text('Class 10-B • No Roll No.'), findsOneWidget);
        expect(find.text('Note: Paid via online transfer'), findsOneWidget);
      },
    );

    testWidgets(
      'opens edit fee dialog, validates paid amount, and updates fee status',
      (tester) async {
        final f = _StudentFeeFixture()..seed();
        final controller = StudentFeeManagementController(
          studentRepository: f.students,
          feeRepository: f.fees,
        );

        await controller.load(schoolId: 's1');

        await tester.pumpWidget(
          _wrap(
            StudentFeeManagementScreen(controller: controller, schoolId: 's1'),
          ),
        );
        await tester.pumpAndSettle();

        // Tap Edit Fee on Alice Smith (first item)
        final editButtons = find.text('Edit Fee');
        await tester.tap(editButtons.first);
        await tester.pumpAndSettle();

        expect(find.text('Edit Fee Status'), findsOneWidget);
        expect(find.text('Student: Alice Smith'), findsOneWidget);

        final paidAmountField = find.descendant(
          of: find.widgetWithText(AppTextField, 'Paid Amount (\$)'),
          matching: find.byType(TextField),
        );

        final remarksField = find.descendant(
          of: find.widgetWithText(AppTextField, 'Remarks / Notes'),
          matching: find.byType(TextField),
        );

        // Enter exceeding paid amount
        await tester.enterText(paidAmountField, '9999');
        await tester.tap(find.text('Update Fee Status'));
        await tester.pumpAndSettle();

        expect(
          find.text('Paid amount cannot exceed total due (\$1000)'),
          findsOneWidget,
        );

        // Fix paid amount and enter remarks
        await tester.enterText(paidAmountField, '1000');
        await tester.enterText(remarksField, 'Cleared remaining balance');

        await tester.tap(find.text('Update Fee Status'));
        await tester.pumpAndSettle();

        expect(find.text('Fee record updated successfully.'), findsOneWidget);
      },
    );
  });
}
