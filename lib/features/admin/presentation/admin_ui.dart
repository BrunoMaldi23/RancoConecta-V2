import 'package:flutter/material.dart';

import '../../../core/widgets/ranco_segmented_control.dart';
import '../../../theme/ranco_colors.dart';

/// Piezas visuales compartidas por las tablas del panel (usuarios, negocios y
/// futuras). Solo presentan el estado de paginación que ya existe: no
/// consultan datos por sí mismas.

/// Paginador: "Mostrando 1–10 de 14 · Filas por página [10] · ‹ 1 / 2 ›".
///
/// Si [onPageSizeChanged] es null, el selector de filas queda visible pero
/// deshabilitado (la API actual no admite cambiar el tamaño de página).
class AdminPaginator extends StatelessWidget {
  const AdminPaginator({
    required this.offset,
    required this.visibleCount,
    required this.pageSize,
    required this.onPrevious,
    required this.onNext,
    this.onFirst,
    this.onLast,
    this.total,
    this.pageSizeOptions = const [10, 20, 50],
    this.onPageSizeChanged,
    super.key,
  });

  /// Índice (base 0) del primer elemento de la página actual.
  final int offset;

  /// Elementos mostrados en esta página.
  final int visibleCount;

  /// Total real si la API lo entrega; si no, se omite "de N".
  final int? total;

  final int pageSize;
  final List<int> pageSizeOptions;
  final ValueChanged<int>? onPageSizeChanged;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onFirst;
  final VoidCallback? onLast;

  @override
  Widget build(BuildContext context) {
    final from = visibleCount == 0 ? 0 : offset + 1;
    final to = offset + visibleCount;
    final page = pageSize <= 0 ? 1 : offset ~/ pageSize + 1;
    final pages = total == null || pageSize <= 0
        ? null
        : ((total! + pageSize - 1) ~/ pageSize).clamp(1, 1 << 30);
    const muted = TextStyle(color: RancoColors.textSecondary, fontSize: 13);

    final summary = Text(
      total == null ? '$from–$to' : '$from–$to de $total',
      style: const TextStyle(
        color: RancoColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );

    final sizeSelector = Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('Filas', style: muted),
      const SizedBox(width: 8),
      Tooltip(
        message: onPageSizeChanged == null
            ? 'Tamaño de página fijo por ahora'
            : 'Cambiar filas por página',
        child: DropdownButton<int>(
          value: pageSizeOptions.contains(pageSize) ? pageSize : null,
          hint: Text('$pageSize'),
          isDense: true,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(10),
          items: [
            for (final option in pageSizeOptions)
              DropdownMenuItem(value: option, child: Text('$option')),
          ],
          onChanged: onPageSizeChanged == null
              ? null
              : (value) {
                  if (value != null) onPageSizeChanged!(value);
                },
        ),
      ),
    ]);

    // ‹ 1 / 3 ›: primera/última quedan como atajos solo con muchas páginas.
    final many = (pages ?? 0) > 3;
    final pager = Row(mainAxisSize: MainAxisSize.min, children: [
      if (many)
        IconButton(
          tooltip: 'Primera página',
          onPressed: onFirst,
          icon: const Icon(Icons.first_page_rounded),
        ),
      IconButton.outlined(
        tooltip: 'Página anterior',
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          pages == null ? '$page' : '$page / $pages',
          style: const TextStyle(
            color: RancoColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
      IconButton.outlined(
        tooltip: 'Página siguiente',
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
      if (many)
        IconButton(
          tooltip: 'Última página',
          onPressed: onLast,
          icon: const Icon(Icons.last_page_rounded),
        ),
    ]);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 8,
        children: [
          summary,
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [sizeSelector, pager],
          ),
        ],
      ),
    );
  }
}

/// Filtro segmentado compacto con contador opcional por opción. Usa el
/// control segmentado compartido (pista suave, opción activa en blanco).
class AdminSegmentFilter<T> extends StatelessWidget {
  const AdminSegmentFilter({
    required this.options,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  /// (valor, etiqueta, contador opcional).
  final List<(T, String, int?)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: RancoSegmentedControl<T>(
        segments: [
          for (final (value, label, count) in options)
            RancoSegment(value: value, label: label, count: count),
        ],
        selected: selected,
        onChanged: onSelected,
      ),
    );
  }
}

/// Campo de búsqueda compacto para barras de filtros del panel.
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD6E3DD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: RancoColors.forest, width: 1.4),
        ),
      ),
    );
  }
}

/// Aviso para funciones cuyo backend aún no existe (vista previa).
class AdminPreviewNotice extends StatelessWidget {
  const AdminPreviewNotice({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6E6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1DEB8)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline_rounded,
              size: 18, color: Color(0xFF8A5B12)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: Color(0xFF6E4A10), fontSize: 13, height: 1.35)),
          ),
        ]),
      );
}
