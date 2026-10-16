import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/attendance_model.dart';
import 'attendance_repository.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';

/// Firestore-backed [AttendanceRepository].
class FirestoreAttendanceRepository implements AttendanceRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreAttendanceRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.attendance);

  AttendanceModel _toModel(DocumentSnapshot<Map<String, dynamic>> doc) =>
      AttendanceModel.fromMap(dataWithId(doc, 'attendanceId'));

  @override
  Future<List<AttendanceModel>> getAttendanceBySchoolAndDate({
    required String schoolId,
    required String date,
  }) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .where(FirestoreFields.date, isEqualTo: date)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load attendance');
    }
  }

  @override
  Future<List<AttendanceModel>> getAttendanceBySchool(String schoolId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load attendance');
    }
  }

  @override
  Future<List<AttendanceModel>> getAttendanceByStudent(String studentId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.studentId, isEqualTo: studentId)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load attendance');
    }
  }

  @override
  Future<AttendanceModel?> getAttendanceByStudentAndDate({
    required String studentId,
    required String date,
  }) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.studentId, isEqualTo: studentId)
          .where(FirestoreFields.date, isEqualTo: date)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return _toModel(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load attendance for student');
    }
  }

  @override
  Future<void> saveAttendance(AttendanceModel attendance) async {
    try {
      await _collection
          .doc(attendance.attendanceId)
          .set(attendance.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'save attendance');
    }
  }

  @override
  Future<void> saveAttendanceBatch(List<AttendanceModel> records) async {
    if (records.isEmpty) return;
    try {
      final batch = _firestore.batch();
      for (final record in records) {
        batch.set(
          _collection.doc(record.attendanceId),
          record.toMap(),
          SetOptions(merge: true),
        );
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'save attendance');
    }
  }
}
