import 'package:flutter/material.dart';

import '../../app/theme/app_text_styles.dart';
import '../../app/theme/app_dimensions.dart';
import 'equal_column_grid.dart';

/// A titled section that renders its tiles in [columns] equal-height columns,
/// with an optional control next to the heading.
class GridSection extends StatelessWidget {
  final String title;
  final int columns;
  final Widget? action;
  final List<Widget> children;

  const GridSection({
    super.key,
    required this.title,
    required this.columns,
    this.action,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
          child: Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.heading4)),
              ?action,
            ],
          ),
        ),
        EqualColumnGrid(columns: columns, children: children),
      ],
    );
  }
}
