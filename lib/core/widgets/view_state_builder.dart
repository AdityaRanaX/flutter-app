import 'package:flutter/material.dart';

import '../state/view_state.dart';
import 'state_message.dart';

/// Renders a [ViewState]: the four non-ready states through the shared
/// [StateMessage], and the ready state through [builder].
///
/// This exists so no screen writes its own switch over loading / empty /
/// error / unauthorized. `StateMessage` already covers the four approved
/// state wireframes, so this is the missing half — the mapping from a
/// load's outcome onto it.
class ViewStateBuilder<T> extends StatelessWidget {
  /// What to render.
  final ViewState<T> state;

  /// Builds the screen's real content once data has arrived.
  final Widget Function(BuildContext context, T data) builder;

  /// Offered on the error state. Omit it and no Retry button is shown.
  ///
  /// It is deliberately not offered on [ViewStatus.unauthorized]: retrying
  /// will not grant permission, and a button that cannot work is worse
  /// than no button.
  final VoidCallback? onRetry;

  /// Optional replacements for the empty state's default wording, for
  /// screens where "nothing here yet" is too vague to act on.
  final String? emptyTitle;
  final String? emptyMessage;

  const ViewStateBuilder({
    super.key,
    required this.state,
    required this.builder,
    this.onRetry,
    this.emptyTitle,
    this.emptyMessage,
  });

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case ViewStatus.loading:
        return const StateMessage(type: StateMessageType.loading);

      case ViewStatus.ready:
        // `ready` is only ever constructed with data, so this is safe.
        return builder(context, state.data as T);

      case ViewStatus.empty:
        return StateMessage(
          type: StateMessageType.empty,
          title: emptyTitle,
          message: emptyMessage ?? state.message,
        );

      case ViewStatus.error:
        return StateMessage(
          type: StateMessageType.error,
          message: state.message,
          onRetry: onRetry,
        );

      case ViewStatus.unauthorized:
        return StateMessage(
          type: StateMessageType.unauthorized,
          message: state.message,
        );
    }
  }
}
