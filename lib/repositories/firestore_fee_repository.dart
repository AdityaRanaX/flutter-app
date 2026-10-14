import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/fee_model.dart';
import 'fee_repository.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';

/// Firestore-backed [FeeRepository].
class FirestoreFeeRepository implements FeeRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreFeeRepository({FirebaseFirestore? firestore})
    : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.fees);

  FeeModel _toModel(DocumentSnapshot<Map<String, dynamic>> doc) =>
      FeeModel.fromMap(dataWithId(doc, 'feeId'));

  @override
  Future<FeeModel?> getFeeByStudentId(String studentId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.studentId, isEqualTo: studentId)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return null;
      return _toModel(snapshot.docs.first);
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load fee details');
    }
  }

  @override
  Future<List<FeeModel>> getFeesBySchool(String schoolId) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .get();
      return snapshot.docs.map(_toModel).toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load fee details');
    }
  }

  @override
  Future<void> updateFeeStatus(FeeModel fee) async {
    try {
      await _collection.doc(fee.feeId).set(fee.toMap());
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'update this fee record');
    }
  }
}
