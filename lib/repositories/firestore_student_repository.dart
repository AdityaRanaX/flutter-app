import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/student_model.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';
import 'student_repository.dart';

/// Firestore-backed [StudentRepository].
class FirestoreStudentRepository implements StudentRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreStudentRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.students);

  StudentModel _toModel(DocumentSnapshot<Map<String, dynamic>> doc) =>
      StudentModel.fromMap(dataWithId(doc, 'studentId'));

  @override
  Future<List<StudentModel>> getStudentsBySchool(String schoolId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load students');
    }
  }

  @override
  Future<StudentModel?> getStudentById(String studentId) async {
    try {
      final doc = await _collection.doc(studentId).get();
      if (!doc.exists) return null;
      return _toModel(doc);
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load this student');
    }
  }

  @override
  Future<List<StudentModel>> getStudentsBySchoolAndClass({
    required String schoolId,
    required String className,
  }) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .where(FirestoreFields.className, isEqualTo: className)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load students for this class');
    }
  }
}
