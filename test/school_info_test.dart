import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/core/state/view_state.dart';
import 'package:my_flutter_edulens/core/theme/app_theme.dart';
import 'package:my_flutter_edulens/features/school_admin/controllers/school_info_controller.dart';
import 'package:my_flutter_edulens/features/school_admin/screens/school_info_screen.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/repositories/repository_exception.dart';

import 'support/fake_repositories.dart';

Widget _wrap(Widget child) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: child),
);

void main() {
  group('SchoolInfoController Unit Tests', () {
    test('loads existing school details', () async {
      final repo = FakeSchoolRepository();
      repo.schools.add(
        const SchoolModel(
          schoolId: 's1',
          schoolName: 'Greenwood High',
          location: 'North Zone',
          address: '100 Main St',
          contactNumber: '+15550100',
          email: 'info@greenwood.edu',
        ),
      );

      final controller = SchoolInfoController(schoolRepository: repo);
      await controller.load(schoolId: 's1');

      expect(controller.state.status, ViewStatus.ready);
      final school = controller.state.data!;
      expect(school.schoolName, 'Greenwood High');
      expect(school.address, '100 Main St');
      expect(school.contactNumber, '+15550100');
      expect(school.email, 'info@greenwood.edu');
    });

    test('preserves immutable identifiers (schoolId, schoolName, location) on update', () async {
      final repo = FakeSchoolRepository();
      repo.schools.add(
        const SchoolModel(
          schoolId: 's1',
          schoolName: 'Greenwood High',
          location: 'North Zone',
        ),
      );

      final controller = SchoolInfoController(schoolRepository: repo);
      await controller.load(schoolId: 's1');

      final success = await controller.saveSchoolInfo(
        schoolId: 's1',
        address: '200 Park Ave',
        contactNumber: '+15550200',
        email: 'contact@greenwood.edu',
      );

      expect(success, isTrue);
      expect(repo.schools.first.schoolId, 's1');
      expect(repo.schools.first.schoolName, 'Greenwood High');
      expect(repo.schools.first.location, 'North Zone');
      expect(repo.schools.first.address, '200 Park Ave');
      expect(repo.schools.first.contactNumber, '+15550200');
      expect(repo.schools.first.email, 'contact@greenwood.edu');
    });

    test('maps save repository exception to error state', () async {
      final repo = FakeSchoolRepository();
      repo.schools.add(
        const SchoolModel(
          schoolId: 's1',
          schoolName: 'Greenwood High',
          location: 'North Zone',
        ),
      );

      final controller = SchoolInfoController(schoolRepository: repo);
      await controller.load(schoolId: 's1');

      repo.failWith = RepositoryErrorKind.unavailable;

      final success = await controller.saveSchoolInfo(
        schoolId: 's1',
        address: '200 Park Ave',
      );

      expect(success, isFalse);
      expect(controller.saveError, isNotNull);
    });
  });

  group('SchoolInfoScreen Widget Tests', () {
    testWidgets(
      'renders school details and missing optional fields gracefully',
      (tester) async {
        final repo = FakeSchoolRepository();
        repo.schools.add(
          const SchoolModel(
            schoolId: 's1',
            schoolName: 'Greenwood High',
            location: 'North Zone',
          ),
        );

        final controller = SchoolInfoController(schoolRepository: repo);
        await controller.load(schoolId: 's1');

        await tester.pumpWidget(
          _wrap(SchoolInfoScreen(controller: controller, schoolId: 's1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('Greenwood High'), findsOneWidget);
        expect(find.text('North Zone'), findsOneWidget);
        expect(
          find.text('Not provided'),
          findsNWidgets(3),
        ); // address, phone, email
        expect(find.text('Edit Information'), findsOneWidget);
      },
    );

    testWidgets('validates email format and contact number input', (
      tester,
    ) async {
      final repo = FakeSchoolRepository();
      repo.schools.add(
        const SchoolModel(
          schoolId: 's1',
          schoolName: 'Greenwood High',
          location: 'North Zone',
        ),
      );

      final controller = SchoolInfoController(schoolRepository: repo);
      await controller.load(schoolId: 's1');

      await tester.pumpWidget(
        _wrap(SchoolInfoScreen(controller: controller, schoolId: 's1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Information'));
      await tester.pumpAndSettle();

      // Enter invalid phone at index 1 & invalid email at index 2
      await tester.enterText(find.byType(TextField).at(1), '123');
      await tester.enterText(find.byType(TextField).at(2), 'not-an-email');

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
      expect(
        find.text('Please enter a valid contact number (at least 7 digits)'),
        findsOneWidget,
      );
    });

    testWidgets('submits valid updates and updates view details', (
      tester,
    ) async {
      final repo = FakeSchoolRepository();
      repo.schools.add(
        const SchoolModel(
          schoolId: 's1',
          schoolName: 'Greenwood High',
          location: 'North Zone',
        ),
      );

      final controller = SchoolInfoController(schoolRepository: repo);
      await controller.load(schoolId: 's1');

      await tester.pumpWidget(
        _wrap(SchoolInfoScreen(controller: controller, schoolId: 's1')),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Information'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), '456 Campus Drive');
      await tester.enterText(find.byType(TextField).at(1), '+15559900');
      await tester.enterText(
        find.byType(TextField).at(2),
        'admin@greenwood.edu',
      );

      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(find.text('School details updated successfully.'), findsOneWidget);
      expect(find.text('456 Campus Drive'), findsOneWidget);
      expect(find.text('+15559900'), findsOneWidget);
      expect(find.text('admin@greenwood.edu'), findsOneWidget);
    });
  });
}
