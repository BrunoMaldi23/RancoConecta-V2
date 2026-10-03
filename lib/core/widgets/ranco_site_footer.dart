import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/ranco_colors.dart';
import '../../theme/ranco_tokens.dart';
import '../layout/ranco_responsive.dart';

/// Footer público. Vive dentro del scroll de cada página (nunca fijo sobre
/// el contenido). Usar [RancoFooterSliver] al final de un CustomScrollView o
/// [RancoSiteFooter] como último hijo de un ListView/Column con scroll.
class RancoSiteFooter extends StatelessWidget {
  const RancoSiteFooter({
    this.width = RancoContainerWidth.standard,
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
      context.push(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= RancoBreakpoints.medium;

    return Padding(
      padding: const EdgeInsets.only(top: RancoSpacing.xxxl),
      child: Material(
        // Superficie neutra cálida: cierra la página sin parecer otra sección.
        color: const Color(0xFFF5F6F2),
        shape: const Border(top: BorderSide(color: Color(0xFFE3E7E1))),
        child: RancoContentContainer(
          width: width,
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: wide ? 18 : RancoSpacing.md,
            ),
            child: wide ? _wideLayout(context) : _compactLayout(context),
          ),
        ),
      ),
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
    // Lista compacta de enlaces en vez de acordeones con scroll interno.
    final seen = <String>{};
    final links = [
      for (final (_, values) in groups)
        for (final link in values)
          if (seen.add(link.$1)) link,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GroupTitle('Ranco Conecta'),
        const SizedBox(height: RancoSpacing.xs),
        Wrap(
          spacing: RancoSpacing.lg,
          children: [
            for (final (label, route) in links)
              _FooterLink(label: label, onTap: () => _open(context, route)),
          ],
        ),
        const SizedBox(height: RancoSpacing.sm),
        const _Copyright(),
      ],
    );
  }
}

/// Coloca el footer al final de un CustomScrollView, inmediatamente después
/// del contenido: no se usa como relleno para completar la ventana.
class RancoFooterSliver extends StatelessWidget {
  const RancoFooterSliver({super.key});

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: RancoSiteFooter());
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
        color: RancoColors.primaryDark,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RancoRadius.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
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
