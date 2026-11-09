import 'package:flutter/material.dart';

import '../../../core/widgets/app_error_widget.dart';
import '../../../core/widgets/app_loader.dart';
import '../controller/read_state.dart';

/// The three states every read-only financial screen shares.
///
/// [builder] draws the data for [ReadState.ready] and the empty state for
/// [ReadState.empty]; this widget only answers the spinner, the error card with
/// its retry button, and the nothing-yet blank. A failed read never falls
/// through to stale numbers.
class ReadView extends StatelessWidget {
  final ReadState state;
  final String error;
  final VoidCallback onRetry;
  final WidgetBuilder builder;
  final Widget? empty;

  const ReadView({
    super.key,
    required this.state,
    required this.error,
    required this.onRetry,
    required this.builder,
    this.empty,
  });

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      ReadState.loading => const AppLoader(),
      ReadState.failed => AppErrorWidget(message: error, onRetry: onRetry),
      ReadState.empty => empty ?? const SizedBox.shrink(),
      ReadState.ready || ReadState.idle => Builder(builder: builder),
    };
  }
}
