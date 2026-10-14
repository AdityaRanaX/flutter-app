import 'package:flutter/foundation.dart';

import '../../../core/state/view_state.dart';
import '../models/school_summary.dart';
import 'district_data_loader.dart';

/// Drives the School List.
///
/// Search filters the schools already in memory rather than re-querying
/// Firestore on every keystroke — the district's school list is small and
/// fully loaded, so a round trip per character would cost reads and add
/// latency for nothing.
class SchoolListController extends ChangeNotifier {
  final DistrictDataLoader loader;

  SchoolListController({required this.loader});

  ViewState<List<SchoolSummary>> _state = const ViewState.loading();
  ViewState<List<SchoolSummary>> get state => _state;

  String _query = '';
  String get query => _query;

  /// The unfiltered result, kept so clearing the search does not need a
  /// reload and so filtering never mutates what the repository returned.
  List<SchoolSummary> _all = const [];

  Future<void> load() async {
    _state = const ViewState.loading();
    notifyListeners();

    try {
      final data = await loader.load();
      _all = data.schools;
      _state = _buildState();
    } catch (e) {
      _all = const [];
      _state = ViewState.fromError(e);
    }

    notifyListeners();
  }

  void search(String value) {
    if (value == _query) return;
    _query = value;
    // Only re-derive once data has arrived; typing during a load or after
    // a failure must not turn an error into an empty list.
    if (_state.isReady || _state.status == ViewStatus.empty) {
      _state = _buildState();
      notifyListeners();
    }
  }

  ViewState<List<SchoolSummary>> _buildState() {
    final term = _query.trim().toLowerCase();
    if (term.isEmpty) {
      return ViewState.fromList(
        _all,
        emptyMessage: 'No schools have been added to this district yet.',
      );
    }

    final matches = _all
        .where((s) => s.schoolName.toLowerCase().contains(term))
        .toList();

    return ViewState.fromList(
      matches,
      // A search that matches nothing is worded differently from a
      // district with no schools — otherwise the screen reads as though
      // the data vanished.
      emptyMessage: 'No schools match "${_query.trim()}".',
    );
  }
}
