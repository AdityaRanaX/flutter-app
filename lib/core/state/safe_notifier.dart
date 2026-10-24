import 'package:flutter/foundation.dart';

/// Lets a controller finish an in-flight load after its screen has gone.
///
/// Every controller here is a [ChangeNotifier] that awaits a repository
/// and then notifies. If the user navigates away while that read is still
/// running, the controller is disposed first and the notification lands
/// on a dead object — `A <X>Controller was used after being disposed`.
/// Flutter raises that as an assertion in debug, and in release the
/// listener list is already gone, so it is a genuine crash path and not
/// only a debug complaint.
///
/// The load itself is still allowed to finish: cancelling a Firestore
/// read mid-flight is not something the repositories support, and
/// abandoning the result quietly is both simpler and safe, because
/// nothing is listening any more.
///
/// Usage: `class FooController extends ChangeNotifier with SafeNotifier`,
/// then call [safeNotify] instead of `notifyListeners`.
mixin SafeNotifier on ChangeNotifier {
  bool _disposed = false;

  /// Whether [dispose] has run. Useful for skipping work after an await
  /// when there is no longer anything to show it to.
  bool get isDisposed => _disposed;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// [notifyListeners], unless this controller has been disposed.
  void safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }
}
