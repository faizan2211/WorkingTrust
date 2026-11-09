import 'package:flutter/material.dart';

import '../../app/theme/app_dimensions.dart';

/// Lays [children] into rows of [columns] equal-width, equal-height cells.
class EqualColumnGrid extends StatelessWidget {
  final int columns;
  final List<Widget> children;

  const EqualColumnGrid({
    super.key,
    required this.columns,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var start = 0; start < children.length; start += columns) {
      final slice = children.sublist(
        start,
        (start + columns).clamp(0, children.length),
      );
      final padded = <Widget>[
        ...slice,
        for (var i = slice.length; i < columns; i++) const SizedBox(),
      ];
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < padded.length; i++) ...[
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppDimensions.md),
                    child: padded[i],
                  ),
                ),
                if (i != columns - 1) const SizedBox(width: AppDimensions.md),
              ],
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}
