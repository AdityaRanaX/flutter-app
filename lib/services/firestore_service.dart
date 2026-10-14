import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore Service handling database operations for EduLens.
class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Writes a demo document to the 'schools' collection in Cloud Firestore.
  Future<void> addDemoSchool() async {
    try {
      await _db.collection('schools').add({
        'name': 'Demo School',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw Exception('Firestore write error [${e.code}]: ${e.message}');
    } catch (e) {
      throw Exception('Failed to write to Firestore: ${e.toString()}');
    }
  }
}
