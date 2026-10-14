import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/school_model.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';
import 'school_repository.dart';

/// Firestore-backed [SchoolRepository].
///
/// Which schools come back is decided by the security rules, not by this
/// class: a district admin sees every school, anyone else sees only their
/// own. There is deliberately no role filtering here, because a query
/// filter is not an authorization boundary.
class FirestoreSchoolRepository implements SchoolRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreSchoolRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.schools);

  @override
  Future<List<SchoolModel>> getSchools() async {
    try {
      final snapshot = await _collection.get();
      return snapshot.docs
          .map((doc) => SchoolModel.fromMap(dataWithId(doc, 'schoolId')))
          .toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load schools');
    }
  }

  @override
  Future<SchoolModel?> getSchoolById(String schoolId) async {
    try {
      final doc = await _collection.doc(schoolId).get();
      if (!doc.exists) return null;
      return SchoolModel.fromMap(dataWithId(doc, 'schoolId'));
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load this school');
    }
  }
}
