import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../models/school_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/school_repository.dart';
import '../../../services/user_bootstrap_service.dart';

/// Drives the School Information screen for the School Administrator.
///
/// Manages loading school details, editing contact and location metadata
/// (`address`, `contactNumber`, `email`), and persisting updates via [SchoolRepository].
class SchoolInfoController extends ChangeNotifier {
  final SchoolRepository schoolRepository;
  final UserBootstrapService? bootstrapService;

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  bool _saveSuccess = false;
  bool get saveSuccess => _saveSuccess;

  SchoolInfoController({required this.schoolRepository, this.bootstrapService});

  ViewState<SchoolModel> _state = const ViewState.loading();
  ViewState<SchoolModel> get state => _state;

  /// Loads the school information for the given [schoolId] or the currently
  /// authenticated user's profile.
  Future<void> load({String? schoolId, UserModel? profile}) async {
    _state = const ViewState.loading();
    _saveError = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      String? targetSchoolId = schoolId;

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        UserModel? userProfile = profile;
        if (userProfile == null && bootstrapService != null) {
          final bootstrapState = await bootstrapService!.bootstrapUser();
          if (bootstrapState.status == UserBootstrapStatus.profileFound) {
            userProfile = bootstrapState.userModel;
          }
        }

        targetSchoolId = userProfile?.schoolId;
      }

      if (targetSchoolId == null || targetSchoolId.isEmpty) {
        _state = const ViewState.error(
          'No school is currently assigned to this account.',
        );
        notifyListeners();
        return;
      }

      final school = await schoolRepository.getSchoolById(targetSchoolId);
      if (school == null) {
        _state = const ViewState.error('Assigned school could not be found.');
        notifyListeners();
        return;
      }

      _state = ViewState.ready(school);
    } catch (e) {
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  /// Persists updated school information while preserving required fields ([schoolId], [schoolName], [location]).
  Future<bool> saveSchoolInfo({
    required String schoolId,
    String? address,
    String? contactNumber,
    String? email,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _saveError = null;
    _saveSuccess = false;
    notifyListeners();

    try {
      final currentSchool =
          _state.data ?? await schoolRepository.getSchoolById(schoolId);
      if (currentSchool == null) {
        _saveError = 'Cannot save: school record not found.';
        _isSaving = false;
        notifyListeners();
        return false;
      }

      // Preserve immutable identifiers (schoolId, schoolName, location)
      final updatedSchool = currentSchool.copyWith(
        address: address?.trim().isEmpty == true ? null : address?.trim(),
        contactNumber: contactNumber?.trim().isEmpty == true
            ? null
            : contactNumber?.trim(),
        email: email?.trim().isEmpty == true ? null : email?.trim(),
      );

      await schoolRepository.saveSchool(updatedSchool);

      _state = ViewState.ready(updatedSchool);
      _saveSuccess = true;
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      final viewError = ViewState<SchoolModel>.fromError(e);
      _saveError = viewError.message ?? 'Failed to save school details.';
      notifyListeners();
      return false;
    }
  }

  void resetSaveStatus() {
    _saveSuccess = false;
    _saveError = null;
    notifyListeners();
  }
}
