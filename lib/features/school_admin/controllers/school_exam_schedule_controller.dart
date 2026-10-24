import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../../../core/state/safe_notifier.dart';
import '../../../core/utils/app_date.dart';
import '../../../core/utils/metrics.dart';
import '../../../models/exam_model.dart';
import '../../../models/school_model.dart';
import '../../../models/user_model.dart';
import '../../../repositories/exam_repository.dart';
import '../../../repositories/school_repository.dart';
import '../../../services/user_bootstrap_service.dart';
import '../../district/controllers/exam_overview_controller.dart';

/// Drives the School Exam Schedule view for School Admins, Teachers, and Students.
class SchoolExamScheduleController extends ChangeNotifier with SafeNotifier {
  final ExamRepository examRepository;
  final SchoolRepository schoolRepository;
  final UserBootstrapService? bootstrapService;
  final DateTime Function() clock;

  SchoolExamScheduleController({
    required this.examRepository,
    required this.schoolRepository,
    this.bootstrapService,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  ViewState<List<ExamModel>> _state = const ViewState.loading();
  ViewState<List<ExamModel>> get state => _state;

  ExamFilter _filter = ExamFilter.upcoming;
  ExamFilter get filter => _filter;

  SchoolModel? _school;
  SchoolModel? get school => _school;

  String? _targetSchoolId;
  String? get targetSchoolId => _targetSchoolId;

  List<ExamModel> _allExams = const [];

  bool _isSaving = false;
  bool get isSaving => _isSaving;

  String? _saveError;
  String? get saveError => _saveError;

  /// Loads the exam schedule for [schoolId] or the authenticated profile's school.
  Future<void> load({String? schoolId, UserModel? profile}) async {
    _state = const ViewState.loading();
    _saveError = null;
    safeNotify();

    try {
      String? schoolIdToLoad = schoolId;

      if (schoolIdToLoad == null || schoolIdToLoad.isEmpty) {
        UserModel? userProfile = profile;
        if (userProfile == null && bootstrapService != null) {
          final bootstrapState = await bootstrapService!.bootstrapUser();
          if (bootstrapState.status == UserBootstrapStatus.profileFound) {
            userProfile = bootstrapState.userModel;
          }
        }
        schoolIdToLoad = userProfile?.schoolId;
      }

      if (schoolIdToLoad == null || schoolIdToLoad.isEmpty) {
        _state = const ViewState.error(
          'No school is currently assigned to this account.',
        );
        safeNotify();
        return;
      }

      _targetSchoolId = schoolIdToLoad;
      _school = await schoolRepository.getSchoolById(schoolIdToLoad);
      final exams = await examRepository.getExamsBySchool(schoolIdToLoad);

      _allExams = exams;
      _state = _buildState();
    } catch (e) {
      _allExams = const [];
      _state = ViewState.fromError(e);
    }

    safeNotify();
  }

  void setFilter(ExamFilter value) {
    if (value == _filter) return;
    _filter = value;
    if (_state.isReady || _state.status == ViewStatus.empty) {
      _state = _buildState();
      safeNotify();
    }
  }

  ViewState<List<ExamModel>> _buildState() {
    final today = AppDate.today(clock());

    final visible = switch (_filter) {
      ExamFilter.upcoming => Metrics.upcomingExams(_allExams, from: today),
      ExamFilter.all => Metrics.sortedByDate(_allExams),
    };

    return ViewState.fromList(
      visible,
      emptyMessage: _filter == ExamFilter.upcoming
          ? 'No upcoming exams scheduled for this school.'
          : 'No exams scheduled for this school.',
    );
  }

  /// Creates and persists a new exam record for the school.
  Future<bool> addExam({
    required String schoolId,
    required String subject,
    required String className,
    required String date,
    required String startTime,
    required String endTime,
    required String createdBy,
  }) async {
    if (_isSaving) return false;

    _isSaving = true;
    _saveError = null;
    safeNotify();

    try {
      final newExam = ExamModel(
        examId: 'exam_${DateTime.now().millisecondsSinceEpoch}',
        schoolId: schoolId,
        className: className.trim(),
        subject: subject.trim(),
        date: date.trim(),
        startTime: startTime.trim(),
        endTime: endTime.trim(),
        createdBy: createdBy,
      );

      await examRepository.saveExam(newExam);

      _isSaving = false;
      await load(schoolId: schoolId);
      return true;
    } catch (e) {
      _isSaving = false;
      final viewError = ViewState<List<ExamModel>>.fromError(e);
      _saveError = viewError.message ?? 'Failed to schedule exam.';
      safeNotify();
      return false;
    }
  }
}
