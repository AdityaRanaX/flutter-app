import 'package:flutter_test/flutter_test.dart';
import 'package:my_flutter_edulens/models/attendance_model.dart';
import 'package:my_flutter_edulens/models/exam_model.dart';
import 'package:my_flutter_edulens/models/fee_model.dart';
import 'package:my_flutter_edulens/models/school_model.dart';
import 'package:my_flutter_edulens/models/student_model.dart';
import 'package:my_flutter_edulens/models/user_model.dart';

void main() {
  group('Data Models Serialization Tests', () {
    test('UserModel serialization and copyWith', () {
      const user = UserModel(
        uid: 'u123',
        name: 'John Doe',
        email: 'john@edulens.org',
        role: 'district_admin',
        schoolId: 's101',
      );

      final map = user.toMap();
      final fromMap = UserModel.fromMap(map);

      expect(fromMap.uid, 'u123');
      expect(fromMap.name, 'John Doe');
      expect(fromMap.email, 'john@edulens.org');
      expect(fromMap.role, 'district_admin');
      expect(fromMap.schoolId, 's101');

      final copied = user.copyWith(name: 'Jane Doe');
      expect(copied.name, 'Jane Doe');
      expect(copied.uid, 'u123');
    });

    test('SchoolModel serialization with approved optional fields & legacy support', () {
      // Legacy document without optional fields
      final legacyMap = {
        'schoolId': 's101',
        'schoolName': 'Central High School',
        'location': 'District 1',
      };

      final fromLegacy = SchoolModel.fromMap(legacyMap);
      expect(fromLegacy.schoolId, 's101');
      expect(fromLegacy.schoolName, 'Central High School');
      expect(fromLegacy.location, 'District 1');
      expect(fromLegacy.address, isNull);
      expect(fromLegacy.contactNumber, isNull);
      expect(fromLegacy.email, isNull);

      // Full document with new approved fields
      const fullSchool = SchoolModel(
        schoolId: 's101',
        schoolName: 'Central High School',
        location: 'District 1',
        address: '123 Education Lane',
        contactNumber: '+1-555-0199',
        email: 'info@centralhigh.edu',
      );

      final fullMap = fullSchool.toMap();
      final fromFull = SchoolModel.fromMap(fullMap);

      expect(fromFull.address, '123 Education Lane');
      expect(fromFull.contactNumber, '+1-555-0199');
      expect(fromFull.email, 'info@centralhigh.edu');

      final copied = fullSchool.copyWith(email: 'contact@centralhigh.edu');
      expect(copied.email, 'contact@centralhigh.edu');
      expect(copied.address, '123 Education Lane');
    });

    test('StudentModel serialization with rollNumber & legacy support', () {
      // Legacy document
      final legacyMap = {
        'studentId': 'st10',
        'name': 'Alice Smith',
        'schoolId': 's101',
        'className': '10',
        'section': 'A',
      };

      final fromLegacy = StudentModel.fromMap(legacyMap);
      expect(fromLegacy.studentId, 'st10');
      expect(fromLegacy.rollNumber, isNull);

      // Full document with rollNumber
      const student = StudentModel(
        studentId: 'st10',
        name: 'Alice Smith',
        schoolId: 's101',
        className: '10',
        section: 'A',
        rollNumber: 'RN-1002',
      );

      final map = student.toMap();
      final fromMap = StudentModel.fromMap(map);

      expect(fromMap.rollNumber, 'RN-1002');
      expect(fromMap.studentId, 'st10');

      final copied = student.copyWith(rollNumber: 'RN-1003');
      expect(copied.rollNumber, 'RN-1003');
      expect(copied.name, 'Alice Smith');
    });

    test('FeeModel serialization with remarks & legacy support', () {
      // Legacy document
      final legacyMap = {
        'feeId': 'f99',
        'studentId': 'st10',
        'schoolId': 's101',
        'totalDue': 500.0,
        'paidAmount': 250.0,
        'status': 'Partial',
        'updatedAt': '2026-03-30T10:00:00Z',
      };

      final fromLegacy = FeeModel.fromMap(legacyMap);
      expect(fromLegacy.feeId, 'f99');
      expect(fromLegacy.remarks, isNull);

      // Full document with remarks
      const fee = FeeModel(
        feeId: 'f99',
        studentId: 'st10',
        schoolId: 's101',
        totalDue: 500.0,
        paidAmount: 250.0,
        status: 'Partial',
        updatedAt: '2026-03-30T10:00:00Z',
        remarks: 'First installment paid on time.',
      );

      final map = fee.toMap();
      final fromMap = FeeModel.fromMap(map);

      expect(fromMap.feeId, 'f99');
      expect(fromMap.totalDue, 500.0);
      expect(fromMap.paidAmount, 250.0);
      expect(fromMap.status, 'Partial');
      expect(fromMap.remarks, 'First installment paid on time.');

      final copied = fee.copyWith(remarks: 'Updated receipt issue.');
      expect(copied.remarks, 'Updated receipt issue.');
      expect(copied.paidAmount, 250.0);
    });

    test('AttendanceModel serialization', () {
      const attendance = AttendanceModel(
        attendanceId: 'a55',
        studentId: 'st10',
        schoolId: 's101',
        teacherId: 't20',
        date: '2026-03-30',
        status: 'Present',
      );

      final map = attendance.toMap();
      final fromMap = AttendanceModel.fromMap(map);

      expect(fromMap.attendanceId, 'a55');
      expect(fromMap.status, 'Present');
    });

    test('ExamModel serialization', () {
      const exam = ExamModel(
        examId: 'e1',
        schoolId: 's101',
        className: '10',
        subject: 'Mathematics',
        date: '2026-04-10',
        startTime: '09:00 AM',
        endTime: '12:00 PM',
        createdBy: 't20',
      );

      final map = exam.toMap();
      final fromMap = ExamModel.fromMap(map);

      expect(fromMap.examId, 'e1');
      expect(fromMap.subject, 'Mathematics');
      expect(fromMap.startTime, '09:00 AM');
    });
  });
}
