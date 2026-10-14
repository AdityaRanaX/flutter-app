import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../models/user_model.dart';
import 'firestore_document_mapper.dart';
import 'repository_exception.dart';
import 'user_repository.dart';

/// Concrete Firestore implementation of [UserRepository].
class FirestoreUserRepository implements UserRepository {
  final FirebaseFirestore? _customFirestore;

  FirestoreUserRepository({FirebaseFirestore? firestore})
      : _customFirestore = firestore;

  FirebaseFirestore get _firestore =>
      _customFirestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirestoreCollections.users);

  @override
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _collection.doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return null;
      }
      return UserModel.fromMap(dataWithId(doc, 'uid'));
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load your profile');
    }
  }

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      await _collection.doc(user.uid).set(
            user.toMap(),
            SetOptions(merge: true),
          );
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'save this profile');
    }
  }

  @override
  Future<List<UserModel>> getUsersBySchoolAndRole({
    required String schoolId,
    required String role,
  }) async {
    try {
      final snapshot = await _collection
          .where(FirestoreFields.schoolId, isEqualTo: schoolId)
          .where(FirestoreFields.role, isEqualTo: role)
          .get();
      return snapshot.docs
          .map((doc) => UserModel.fromMap(dataWithId(doc, 'uid')))
          .toList();
    } on FirebaseException catch (e) {
      throw RepositoryException.fromFirebase(e, 'load staff for this school');
    }
  }
}
