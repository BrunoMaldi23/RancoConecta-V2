import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/ranco_colors.dart';
import '../../theme/ranco_tokens.dart';
import '../layout/ranco_responsive.dart';
import '../../features/legal/application/legal_navigation.dart';

/// Footer público. Vive dentro del scroll de cada página (nunca fijo sobre
/// el contenido). Usar [RancoFooterSliver] al final de un CustomScrollView
/// o [RancoFooterScrollView]: en páginas cortas el footer queda al final de
/// la ventana en vez de pegado al contenido.
class RancoSiteFooter extends StatelessWidget {
  const RancoSiteFooter({
    this.width = RancoContainerWidth.detail,
    super.key,
  });

  /// Ancho del contenido, para alinear el footer con la página que cierra.
  final RancoContainerWidth width;

  static const groups = <(String, List<(String, String)>)>[
    (
      'Ranco Conecta',
      [('Sobre nosotros', '/contacto'), ('Explorar', '/explore')],
    ),
    (
      'Para negocios',
      [
        ('Registrar negocio', '/provider/join'),
        ('Acceso proveedor', '/provider/sign-in'),
      ],
    ),
    (
      'Ayuda',
      [
        ('Términos', '/terminos'),
        ('Privacidad', '/politica-privacidad'),
        ('Contacto', '/contacto'),
      ],
    ),
  ];

  static void _open(BuildContext context, String route) {
    if (route.startsWith('/provider') || route == '/explore') {
      context.go(route);
    } else {
      openLegalPage(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= RancoBreakpoints.medium;

    // Column(min): el footer mide lo que su contenido aunque reciba un alto
    // acotado (p. ej. dentro de RancoFooterSliver); así la superficie gris
    // no se estira para rellenar el hueco de una página corta.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: RancoSpacing.xxl),
          child: Material(
            // Superficie neutra cálida: cierra la página sin parecer otra sección.
            color: const Color(0xFFF5F6F2),
            shape: const Border(top: BorderSide(color: Color(0xFFE3E7E1))),
            child: RancoContentContainer(
              width: width,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  wide ? 20 : RancoSpacing.lg,
                  0,
                  wide ? 16 : RancoSpacing.md,
                ),
                child: wide ? _wideLayout(context) : _compactLayout(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (title, links) in groups)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _GroupTitle(title),
                    const SizedBox(height: RancoSpacing.xs),
                    for (final (label, route) in links)
                      _FooterLink(
                        label: label,
                        onTap: () => _open(context, route),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: RancoSpacing.md),
        const Divider(height: 1, color: Color(0xFFE3E7E1)),
        const SizedBox(height: RancoSpacing.sm),
        const _Copyright(),
      ],
    );
  }

  Widget _compactLayout(BuildContext context) {
    // Móvil: una sola columna compacta. Cada grupo = título + enlaces en
    // línea; sin acordeones ni scroll interno.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (title, links) in groups) ...[
          _GroupTitle(title),
          Wrap(
            spacing: RancoSpacing.lg,
            children: [
              for (final (label, route) in links)
                _FooterLink(
                  label: label,
                  compact: true,
                  onTap: () => _open(context, route),
                ),
            ],
          ),
          const SizedBox(height: RancoSpacing.xs),
        ],
        const SizedBox(height: RancoSpacing.xs),
        const Divider(height: 1, color: Color(0xFFE3E7E1)),
        const SizedBox(height: RancoSpacing.sm),
        const _Copyright(),
      ],
    );
  }
}

/// Coloca el footer al final de un CustomScrollView. Si el contenido es
/// más corto que la ventana, ocupa el espacio restante y se apoya abajo
/// (sin rellenar con un bloque enorme); si es más largo, va tras el
/// contenido. Debe ser el último sliver.
class RancoFooterSliver extends StatelessWidget {
  const RancoFooterSliver({
    this.width = RancoContainerWidth.detail,
    super.key,
  });

  final RancoContainerWidth width;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      fillOverscroll: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: RancoSiteFooter(width: width),
      ),
    );
  }
}

/// ListView equivalente con [RancoFooterSliver] al final.
class RancoFooterScrollView extends StatelessWidget {
  const RancoFooterScrollView({
    required this.children,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.footerWidth = RancoContainerWidth.detail,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final ScrollController? controller;
  final RancoContainerWidth footerWidth;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: controller,
      slivers: [
        SliverPadding(
          padding: padding,
          sliver: SliverList(delegate: SliverChildListDelegate(children)),
        ),
        RancoFooterSliver(width: footerWidth),
      ],
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: RancoColors.textSecondary,
        fontSize: 11.5,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback onTap;

  /// Móvil: filas más bajas para no competir con la navegación inferior.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RancoRadius.xs),
      hoverColor: RancoColors.primary.withValues(alpha: .06),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: compact ? 28 : 32),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: compact ? 3 : 5),
          child: Text(
            label,
            style: const TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _Copyright extends StatelessWidget {
  const _Copyright();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '© 2026 Ranco Conecta · Lago Ranco, Chile',
      style: TextStyle(color: RancoColors.textSecondary, fontSize: 12),
    );
  }
}
