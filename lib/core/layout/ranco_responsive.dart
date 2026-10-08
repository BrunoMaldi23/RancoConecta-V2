import 'package:flutter/material.dart';

import '../../theme/ranco_tokens.dart';

/// Anchos máximos por tipo de vista. Evitan contenido diminuto en monitores
/// grandes y tarjetas estiradas en exceso.
enum RancoContainerWidth {
  /// Home, Explorar, Categorías, Guardados: 1240–1280.
  standard,

  /// Vistas de gestión anchas.
  wide,

  /// Formularios de varias secciones.
  form,

  /// Ficha de negocio: 1120–1150.
  detail,

  /// Contenido de una columna.
  narrow,

  /// Flujo de reserva: 1080.
  booking,

  /// Acceso / registro: 480.
  auth,

  /// Páginas legales (índice + artículo): 1048.
  legal,

  /// Panel administrativo: hasta 1400.
  admin,
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
      RancoContainerWidth.auth => 480,
      RancoContainerWidth.narrow => 640,
      RancoContainerWidth.form => 760,
      RancoContainerWidth.legal => 1048,
      RancoContainerWidth.booking => 1080,
      RancoContainerWidth.detail => large ? 1150 : 1120,
      RancoContainerWidth.standard => large ? 1280 : 1240,
      RancoContainerWidth.wide => large ? 1360 : 1280,
      RancoContainerWidth.admin => 1400,
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
    this.equalHeightRows = false,
    super.key,
  });

  final List<Widget> children;
  final double minItemWidth;
  final double spacing;
  final double runSpacing;
  final int maxColumns;
  final int minColumns;

  /// Iguala la altura de los elementos de cada fila (tarjetas con distinta
  /// metadata). Los hijos no deben usar LayoutBuilder.
  final bool equalHeightRows;

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

        if (equalHeightRows) {
          return SizedBox(
            width: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var start = 0;
                    start < children.length;
                    start += columns) ...[
                  if (start > 0) SizedBox(height: runSpacing),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var index = start;
                            index < start + columns && index < children.length;
                            index++) ...[
                          if (index > start) SizedBox(width: spacing),
                          SizedBox(width: itemWidth, child: children[index]),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Ancho completo: un único elemento queda alineado al inicio, no
        // centrado por el contenedor padre.
        return SizedBox(
          width: constraints.maxWidth,
          child: Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: [
              for (final child in children)
                SizedBox(
                  width: itemWidth,
                  child: child,
                ),
            ],
          ),
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
