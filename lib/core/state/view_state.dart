import '../../repositories/repository_exception.dart';

/// Where a screen is in its load.
///
/// The four non-ready values line up with the four approved common-state
/// wireframes. Keeping [empty] and [error] apart matters: a query that
/// succeeded and found nothing is not a failure. Keeping [unauthorized]
/// apart from [error] matters more — a permission denial must never be
/// shown as an empty list, or the UI would imply the data does not exist
/// when it does.
enum ViewStatus { loading, ready, empty, error, unauthorized }

/// The outcome of loading one screen's data.
///
/// Screens hold one of these and hand it to a `ViewStateBuilder`, so every
/// screen renders the four states the same way.
class ViewState<T> {
  final ViewStatus status;
  final T? data;
  final String? message;

  const ViewState._(this.status, {this.data, this.message});

  const ViewState.loading() : this._(ViewStatus.loading);

  const ViewState.ready(T value) : this._(ViewStatus.ready, data: value);

  const ViewState.empty({String? message})
    : this._(ViewStatus.empty, message: message);

  const ViewState.error(String message)
    : this._(ViewStatus.error, message: message);

  const ViewState.unauthorized({String? message})
    : this._(ViewStatus.unauthorized, message: message);

  /// Builds the right failure state from a thrown error.
  ///
  /// This is the single place that decides a denial means "unauthorized"
  /// and anything else means "error", so no screen has to repeat that
  /// judgement — or get it wrong.
  factory ViewState.fromError(Object error) {
    if (error is RepositoryException) {
      if (error.isPermissionDenied) {
        return ViewState.unauthorized(message: error.message);
      }
      return ViewState.error(error.message);
    }
    return const ViewState.error('Something went wrong. Please try again.');
  }

  /// [ViewState.ready] when [value] has items, [ViewState.empty] when it
  /// does not — so a caller never has to remember to check for an empty
  /// list before declaring success.
  static ViewState<List<E>> fromList<E>(List<E> value, {String? emptyMessage}) {
    if (value.isEmpty) return ViewState<List<E>>.empty(message: emptyMessage);
    return ViewState<List<E>>.ready(value);
  }

  bool get isLoading => status == ViewStatus.loading;
  bool get isReady => status == ViewStatus.ready;
}
