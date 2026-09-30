import 'package:flutter/material.dart';

import '../../theme/ranco_tokens.dart';

enum RancoContainerWidth {
  standard,
  wide,
  form,
  detail,
  narrow,
}

extension RancoResponsiveContext on BuildContext {
  double get rancoWidth => MediaQuery.sizeOf(this).width;
  bool get isRancoDesktop => rancoWidth >= RancoBreakpoints.expanded;
  bool get isRancoLargeDesktop => rancoWidth >= RancoBreakpoints.large;
}

class RancoContentContainer extends StatelessWidget {
  const RancoContentContainer({
    required this.child,
    this.width = RancoContainerWidth.standard,
    this.padding,
    this.alignment = Alignment.topCenter,
    super.key,
  });

  final Widget child;
  final RancoContainerWidth width;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context).width;
    final horizontalPadding = _horizontalPadding(viewport);

    return Align(
      alignment: alignment,
      child: Padding(
        padding: padding ??
            EdgeInsets.symmetric(
              horizontal: horizontalPadding,
            ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth(width, viewport)),
          child: child,
        ),
      ),
    );
  }

  static double _horizontalPadding(double viewport) {
    if (viewport >= RancoBreakpoints.expanded) return 28;
    if (viewport >= RancoBreakpoints.medium) return 24;
    return 16;
  }

  static double _maxWidth(RancoContainerWidth width, double viewport) {
    final large = viewport >= RancoBreakpoints.large;
    return switch (width) {
      RancoContainerWidth.narrow => 640,
      RancoContainerWidth.form => 760,
      RancoContainerWidth.detail => large ? 1200 : 1080,
      RancoContainerWidth.wide => large ? 1360 : 1280,
      RancoContainerWidth.standard => large ? 1320 : 1180,
    };
  }
}

class RancoResponsiveGrid extends StatelessWidget {
  const RancoResponsiveGrid({
    required this.children,
    this.minItemWidth = 260,
    this.spacing = RancoSpacing.md,
    this.runSpacing = RancoSpacing.md,
    this.maxColumns = 4,
    this.minColumns = 1,
    super.key,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int maxColumns;
  final int minColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = rancoGridColumns(
          constraints.maxWidth,
          minItemWidth: minItemWidth,
          spacing: spacing,
          maxColumns: maxColumns,
          minColumns: minColumns,
        );
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }
}

int rancoGridColumns(
  double width, {
  double minItemWidth = 260,
  double spacing = RancoSpacing.md,
  int maxColumns = 4,
  int minColumns = 1,
}) {
  final raw = ((width + spacing) / (minItemWidth + spacing)).floor();
  return raw.clamp(minColumns, maxColumns);
}

Future<T?> showRancoAdaptiveModal<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool useRootNavigator = false,
  double maxWidth = 560,
  double maxHeightFactor = .82,
}) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= RancoBreakpoints.expanded) {
    return showDialog<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) {
        final height = MediaQuery.sizeOf(dialogContext).height;
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: height * maxHeightFactor,
            ),
            child: builder(dialogContext),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}
