import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/exam_model.dart';
import 'exam_repository.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';

/// Firestore-backed [ExamRepository].
class FirestoreExamRepository implements ExamRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreExamRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.exams);

  ExamModel _toModel(DocumentSnapshot<Map<String, dynamic>> doc) =>
      ExamModel.fromMap(dataWithId(doc, 'examId'));

  @override
  Future<List<ExamModel>> getExamsBySchool(String schoolId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load exams');
    }
  }

  @override
  Future<List<ExamModel>> getExamsBySchoolAndClass({
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
      throw RepositoryException.fromFirebase(e, 'load class exams');
    }
  }

  @override
  Future<List<ExamModel>> getAllExams() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load exams');
    }
  }

  @override
  Future<ExamModel?> getExamById(String examId) async {
    try {
      final doc = await _collection.doc(examId).get();
      if (!doc.exists) return null;
      return _toModel(doc);
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load this exam');
    }
  }

  @override
  Future<void> saveExam(ExamModel exam) async {
    try {
      await _collection
          .doc(exam.examId)
          .set(exam.toMap(), SetOptions(merge: true));
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'save this exam');
    }
  }
}
