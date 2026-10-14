import 'package:cloud_firestore/cloud_firestore.dart';

/// The document's data, with its own id filled in when the stored map is
/// missing one.
///
/// Every EduLens document is written with its id duplicated inside it
/// (`schools/school01` also carries `schoolId: 'school01'`), and the
/// models read the field rather than the document path. A document
/// written by hand in the Firebase console, or by an earlier throwaway
/// script, can easily be missing that field — in which case the model
/// would deserialise with an empty id and quietly become unusable.
/// Falling back to the document id keeps those records addressable.
Map<String, dynamic> dataWithId(
  DocumentSnapshot<Map<String, dynamic>> doc,
  String idField,
) {
  final data = Map<String, dynamic>.from(doc.data() ?? const {});
  final existing = data[idField];
  if (existing == null || (existing is String && existing.trim().isEmpty)) {
    data[idField] = doc.id;
  }
  return data;
}
