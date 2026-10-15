import '../models/school_model.dart';

/// Reads and writes school information.
abstract class SchoolRepository {
  /// Retrieves all schools in the district.
  Future<List<SchoolModel>> getSchools();

  /// Retrieves a specific school by its [schoolId].
  Future<SchoolModel?> getSchoolById(String schoolId);

  /// Creates or updates a school record.
  Future<void> saveSchool(SchoolModel school);
}
