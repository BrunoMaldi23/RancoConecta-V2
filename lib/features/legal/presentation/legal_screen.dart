import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_brand.dart';
import '../../../core/widgets/ranco_site_footer.dart';

// Paleta editorial: texto neutro; el verde queda como acento.
const _ink = Color(0xFF1F2D27);
const _body = Color(0xFF34443D);
const _muted = Color(0xFF66766F);
const _line = Color(0xFFE6ECE9);
const _accent = Color(0xFF2F7D57);
const _accentDark = Color(0xFF145A3A);
const _accentSoft = Color(0xFFEAF5EF);

/// Ancho del layout legal en desktop (índice + artículo).
const _layoutMaxWidth = 1120.0;
const _indexWidth = 232.0;
const _columnGap = 48.0;
const _articleMaxWidth = 720.0;

/// Desde este ancho el índice va al costado; por debajo, arriba y compacto.
const _sideIndexBreakpoint = 960.0;

enum _LegalPage { terms, privacy, contact }

class LegalScreen extends StatelessWidget {
  const LegalScreen({required this.privacy, super.key});

  final bool privacy;

  @override
  Widget build(BuildContext context) {
    // Contenido legal sin cambios: solo se reorganiza su presentación.
    final sections = privacy
        ? const <(String, String)>[
            (
              'Datos que solicitamos',
              'Puedes explorar sin entregar datos personales. Al reservar, contactar un negocio o crear una cuenta, solicitamos los datos necesarios para gestionar esa acción: nombre, teléfono, correo cuando corresponda y los detalles de la solicitud.'
            ),
            (
              'Para qué los usamos',
              'Usamos estos datos para gestionar reservas y solicitudes, permitir que el negocio seleccionado responda, administrar cuentas y proteger el funcionamiento de la plataforma.'
            ),
            (
              'Con quién los compartimos',
              'Los datos de una solicitud o reserva se comparten con el negocio al que la diriges y con los proveedores tecnológicos necesarios para operar Ranco Conecta. No publicamos tu teléfono en el catálogo.'
            ),
            (
              'Analítica y errores',
              'Si estas funciones están habilitadas, registramos eventos de uso anónimos y errores técnicos para mejorar la plataforma. No añadimos nombres, teléfonos ni el texto de tus búsquedas a los eventos de analítica.'
            ),
            (
              'Tus opciones',
              'Puedes consultar, actualizar o solicitar la eliminación de tus datos mediante el canal de contacto de la plataforma, sujeto a las obligaciones de conservación aplicables.'
            ),
          ]
        : const <(String, String)>[
            (
              'Uso de la plataforma',
              'Ranco Conecta permite descubrir negocios y enviar solicitudes o reservas. Explorar el catálogo es libre. Para enviar una solicitud debes entregar datos de contacto correctos.'
            ),
            (
              'Negocios y disponibilidad',
              'Cada negocio es responsable de la información que publica, su disponibilidad, sus precios y la prestación de sus servicios. Una solicitud enviada no garantiza su aceptación.'
            ),
            (
              'Cuentas de proveedores',
              'Los proveedores deben entregar información veraz. Sus publicaciones pueden quedar pendientes de revisión, aprobarse o rechazarse antes de aparecer públicamente.'
            ),
            (
              'Uso responsable',
              'No uses la plataforma para enviar información falsa, contenido ilegal o solicitudes abusivas.'
            ),
          ];

    return _LegalScaffold(
      child: _LegalDocument(
        page: privacy ? _LegalPage.privacy : _LegalPage.terms,
        title: privacy ? 'Política de privacidad' : 'Términos y condiciones',
        description: privacy
            ? 'Qué datos solicitamos, para qué los usamos y con quién los '
                'compartimos.'
            : 'Condiciones de uso de Ranco Conecta para visitantes y negocios.',
        // Introducción tomada literalmente del propio texto legal.
        intro: privacy
            ? 'Puedes explorar sin entregar datos personales.'
            : 'Explorar el catálogo es libre.',
        // Frase existente destacada como aviso discreto.
        highlight: privacy ? 'No publicamos tu teléfono en el catálogo.' : null,
        helpTitle: privacy
            ? '¿Necesitas ayuda con tus datos?'
            : '¿Tienes dudas sobre estas condiciones?',
        sections: sections,
      ),
    );
  }
}

/// Barra institucional simple: volver + marca. La navegación no cambia.
class _LegalScaffold extends StatelessWidget {
  const _LegalScaffold({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 600;
    void back() => context.canPop() ? context.pop() : context.go('/');
    return Scaffold(
      backgroundColor: const Color(0xFFFAFBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 56,
        shape: const Border(bottom: BorderSide(color: _line)),
        leadingWidth: wide ? 112 : 56,
        leading: wide
            ? Tooltip(
                message: 'Volver',
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: TextButton.icon(
                    onPressed: back,
                    style: TextButton.styleFrom(foregroundColor: _ink),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    label: const Text('Volver'),
                  ),
                ),
              )
            : IconButton(
                tooltip: 'Volver',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: back,
              ),
        titleSpacing: wide ? 8 : 0,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          RancoBrandMark(size: 28),
          SizedBox(width: 8),
          Text('Ranco Conecta',
              style: TextStyle(
                  color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      ),
      body: child,
    );
  }
}

class _LegalDocument extends StatefulWidget {
  const _LegalDocument({
    required this.page,
    required this.title,
    required this.description,
    required this.intro,
    required this.helpTitle,
    required this.sections,
    this.highlight,
  });

  final _LegalPage page;
  final String title;
  final String description;
  final String intro;
  final String helpTitle;
  final String? highlight;
  final List<(String, String)> sections;

  @override
  State<_LegalDocument> createState() => _LegalDocumentState();
}

class _LegalDocumentState extends State<_LegalDocument> {
  final _scroll = ScrollController();
  final _stackKey = GlobalKey();
  final _rowKey = GlobalKey();
  final _indexKey = GlobalKey();
  late final List<GlobalKey> _anchors = [
    for (var i = 0; i < widget.sections.length; i++) GlobalKey(),
  ];
  int _active = 0;
  double? _indexTop;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  RenderBox? _box(GlobalKey key) {
    final object = key.currentContext?.findRenderObject();
    return object is RenderBox && object.attached ? object : null;
  }

  /// Sección activa (scroll spy) y posición del índice fijo.
  void _onScroll() {
    if (!mounted) return;
    var active = 0;
    for (var i = 0; i < _anchors.length; i++) {
      final box = _box(_anchors[i]);
      if (box == null) continue;
      if (box.localToGlobal(Offset.zero).dy <= 200) active = i;
    }
    // Al llegar al final, la última sección queda activa aunque su título
    // no alcance el borde superior.
    if (_scroll.hasClients &&
        _scroll.position.pixels >= _scroll.position.maxScrollExtent - 4 &&
        _scroll.position.maxScrollExtent > 0) {
      active = _anchors.length - 1;
    }

    double? indexTop;
    final stack = _box(_stackKey);
    final row = _box(_rowKey);
    final index = _box(_indexKey);
    if (stack != null && row != null) {
      final rowTop = row.localToGlobal(Offset.zero, ancestor: stack).dy;
      final rowBottom = rowTop + row.size.height;
      final indexHeight = index?.size.height ?? 0;
      // Sticky: sigue al contenido hasta 24 px del borde y se detiene antes
      // de alcanzar el final del artículo.
      indexTop = rowTop < 24 ? 24 : rowTop;
      if (indexTop + indexHeight > rowBottom) {
        indexTop = rowBottom - indexHeight;
      }
    }
    if (active != _active || indexTop != _indexTop) {
      setState(() {
        _active = active;
        _indexTop = indexTop;
      });
    }
  }

  void _jumpTo(int index) {
    final target = _anchors[index].currentContext;
    if (target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final side = constraints.maxWidth >= _sideIndexBreakpoint;
      final horizontal = constraints.maxWidth >= 600 ? 32.0 : 20.0;

      final article = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LegalHeader(
            title: widget.title,
            description: widget.description,
            showMeta: true,
          ),
          if (!side) ...[
            const SizedBox(height: 20),
            _CompactIndex(
              sections: widget.sections,
              onSelected: _jumpTo,
            ),
          ],
          const SizedBox(height: 28),
          Text(widget.intro,
              style: const TextStyle(
                  color: _ink,
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var i = 0; i < widget.sections.length; i++)
            _LegalSection(
              key: _anchors[i],
              number: i + 1,
              title: widget.sections[i].$1,
              body: widget.sections[i].$2,
              highlight: widget.highlight,
            ),
          const SizedBox(height: 12),
          _HelpCallout(title: widget.helpTitle),
          const SizedBox(height: 32),
          _LegalNavigation(current: widget.page),
        ],
      );

      final page = SingleChildScrollView(
        controller: _scroll,
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _layoutMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 40, horizontal, 8),
                  child: side
                      ? Row(
                          key: _rowKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Hueco del índice (se pinta fijo encima).
                            const SizedBox(width: _indexWidth),
                            const SizedBox(width: _columnGap),
                            Expanded(
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: _articleMaxWidth),
                                  child: article,
                                ),
                              ),
                            ),
                          ],
                        )
                      : article,
                ),
              ),
            ),
            const RancoSiteFooter(width: RancoContainerWidth.detail),
          ],
        ),
      );

      if (!side) return page;

      final layoutWidth = constraints.maxWidth < _layoutMaxWidth
          ? constraints.maxWidth
          : _layoutMaxWidth;
      final left = (constraints.maxWidth - layoutWidth) / 2 + horizontal;
      return Stack(
        key: _stackKey,
        children: [
          page,
          Positioned(
            left: left,
            top: _indexTop ?? 40,
            width: _indexWidth,
            child: _SideIndex(
              key: _indexKey,
              sections: widget.sections,
              active: _active,
              onSelected: _jumpTo,
            ),
          ),
        ],
      );
    });
  }
}

class _LegalHeader extends StatelessWidget {
  const _LegalHeader({
    required this.title,
    required this.description,
    this.eyebrow = 'INFORMACIÓN LEGAL',
    this.showMeta = false,
  });

  final String title;
  final String description;
  final String eyebrow;
  final bool showMeta;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 768;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow,
            style: const TextStyle(
                color: _accent,
                fontSize: 12,
                letterSpacing: .9,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(title,
            style: TextStyle(
                color: _ink,
                fontSize: desktop ? 32 : 27,
                height: 1.15,
                letterSpacing: -.4,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(description,
            style: const TextStyle(color: _body, fontSize: 16, height: 1.5)),
        if (showMeta) ...[
          const SizedBox(height: 14),
          const Text('Última actualización · 1 oct 2026',
              style: TextStyle(color: _muted, fontSize: 13)),
          const SizedBox(height: 2),
          const Text('Versión 2026-10-01',
              style: TextStyle(color: _muted, fontSize: 13)),
        ],
      ],
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({
    required this.number,
    required this.title,
    required this.body,
    this.highlight,
    super.key,
  });

  final int number;
  final String title;
  final String body;
  final String? highlight;

  @override
  Widget build(BuildContext context) {
    final highlighted = highlight != null && body.contains(highlight!);
    final text = highlighted ? body.replaceAll(highlight!, '').trim() : body;
    return Container(
      padding: const EdgeInsets.only(top: 30, bottom: 30),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(number.toString().padLeft(2, '0'),
              style: const TextStyle(
                  color: _accent,
                  fontSize: 13,
                  letterSpacing: .6,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(
                  color: _ink,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(text,
              style: const TextStyle(color: _body, fontSize: 16, height: 1.65)),
          if (highlighted) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _accentSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded,
                    size: 20, color: _accentDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(highlight!,
                      style: const TextStyle(
                          color: _accentDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

/// Índice lateral fijo con línea vertical y elemento activo destacado.
class _SideIndex extends StatelessWidget {
  const _SideIndex({
    required this.sections,
    required this.active,
    required this.onSelected,
    super.key,
  });

  final List<(String, String)> sections;
  final int active;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 14, bottom: 8),
            child: Text('En esta página',
                style: TextStyle(
                    color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          for (var i = 0; i < sections.length; i++)
            Semantics(
              selected: i == active,
              link: true,
              child: InkWell(
                onTap: () => onSelected(i),
                hoverColor: const Color(0xFFF1F6F3),
                focusColor: const Color(0x332F7D57),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        width: 2,
                        color: i == active ? _accent : _line,
                      ),
                    ),
                  ),
                  child: Text(sections[i].$1,
                      style: TextStyle(
                          color: i == active ? _accentDark : _body,
                          fontSize: 14,
                          height: 1.3,
                          fontWeight:
                              i == active ? FontWeight.w700 : FontWeight.w500)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Índice compacto (móvil/tablet): colapsado por defecto.
class _CompactIndex extends StatelessWidget {
  const _CompactIndex({required this.sections, required this.onSelected});

  final List<(String, String)> sections;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 14),
        childrenPadding: const EdgeInsets.only(bottom: 6),
        title: Text('En esta página · ${sections.length} secciones',
            style: const TextStyle(
                color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
        children: [
          for (var i = 0; i < sections.length; i++)
            ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              leading: Text((i + 1).toString().padLeft(2, '0'),
                  style: const TextStyle(
                      color: _accent, fontWeight: FontWeight.w800)),
              minLeadingWidth: 24,
              title: Text(sections[i].$1,
                  style: const TextStyle(color: _body, fontSize: 14)),
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

class _HelpCallout extends StatelessWidget {
  const _HelpCallout({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _line),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: _ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                    'Puedes utilizar el canal de contacto de Ranco Conecta.',
                    style: TextStyle(color: _body, fontSize: 14.5)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => context.push('/contacto'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              minimumSize: const Size(0, 44),
            ),
            child: const Text('Ir a Contacto'),
          ),
        ],
      ),
    );
  }
}

/// "Más información": enlaces entre páginas legales con la actual marcada.
class _LegalNavigation extends StatelessWidget {
  const _LegalNavigation({required this.current});

  final _LegalPage current;

  @override
  Widget build(BuildContext context) {
    const items = <(_LegalPage, String, IconData, String)>[
      (
        _LegalPage.terms,
        'Términos y condiciones',
        Icons.gavel_rounded,
        '/terminos'
      ),
      (
        _LegalPage.privacy,
        'Política de privacidad',
        Icons.privacy_tip_outlined,
        '/politica-privacidad'
      ),
      (_LegalPage.contact, 'Contacto', Icons.mail_outline_rounded, '/contacto'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Más información',
            style: TextStyle(
                color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        LayoutBuilder(builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 600;
          final tiles = [
            for (final (page, label, icon, route) in items)
              _LegalNavTile(
                label: label,
                icon: icon,
                current: page == current,
                onTap: () => context.push(route),
              ),
          ];
          if (!horizontal) {
            return Column(children: [
              for (final tile in tiles)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: tile),
            ]);
          }
          return Row(children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ]);
        }),
      ],
    );
  }
}

class _LegalNavTile extends StatelessWidget {
  const _LegalNavTile({
    required this.label,
    required this.icon,
    required this.current,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: !current,
      selected: current,
      child: Material(
        color: current ? _accentSoft : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: current ? const Color(0xFFCFE3D8) : _line),
        ),
        child: InkWell(
          onTap: current ? null : onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: const Color(0xFFF1F6F3),
          focusColor: const Color(0x332F7D57),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: current ? _accentDark : _accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: current ? _accentDark : _ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              if (current)
                const Text('Actual',
                    style: TextStyle(
                        color: _accentDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))
              else
                const Icon(Icons.chevron_right_rounded,
                    size: 20, color: _muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    const destination = String.fromEnvironment('CONTACT_EMAIL');
    if (destination.isEmpty) return;
    final uri = Uri(
      scheme: 'mailto',
      path: destination,
      queryParameters: {
        'subject': 'Consulta Ranco Conecta de ${_name.text.trim()}',
        'body':
            'Nombre: ${_name.text.trim()}\nCorreo: ${_email.text.trim()}\n\n${_message.text.trim()}',
      },
    );
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No pudimos abrir tu aplicación de correo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const email = String.fromEnvironment('CONTACT_EMAIL');
    const whatsapp = String.fromEnvironment('CONTACT_WHATSAPP');
    const instagram = String.fromEnvironment('CONTACT_INSTAGRAM');
    final hasChannels =
        whatsapp.isNotEmpty || email.isNotEmpty || instagram.isNotEmpty;
    final horizontal = MediaQuery.sizeOf(context).width >= 600 ? 32.0 : 20.0;

    return _LegalScaffold(
      child: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _articleMaxWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 40, horizontal, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _LegalHeader(
                        eyebrow: 'CONTACTO',
                        title: 'Hablemos',
                        description: 'Consultas, ayuda y solicitudes sobre '
                            'tus datos personales.',
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _line),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Enviar mensaje',
                                  style: TextStyle(
                                      color: _ink,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 14),
                              TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                      labelText: 'Nombre'),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 3
                                          ? 'Ingresa tu nombre.'
                                          : null),
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _email,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                      labelText: 'Correo'),
                                  validator: (value) =>
                                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                              .hasMatch(value?.trim() ?? '')
                                          ? 'Ingresa un correo válido.'
                                          : null),
                              const SizedBox(height: 12),
                              TextFormField(
                                  controller: _message,
                                  minLines: 4,
                                  maxLines: 6,
                                  decoration: const InputDecoration(
                                      labelText: 'Mensaje'),
                                  validator: (value) =>
                                      (value?.trim().length ?? 0) < 10
                                          ? 'Escribe al menos 10 caracteres.'
                                          : null),
                              const SizedBox(height: 16),
                              Wrap(children: [
                                FilledButton(
                                    onPressed: email.isEmpty ? null : _send,
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 46)),
                                    child: const Text('Enviar mensaje')),
                              ]),
                              if (email.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: Text(
                                        'Canal de contacto pendiente de habilitación.',
                                        style: TextStyle(color: _muted))),
                            ],
                          ),
                        ),
                      ),
                      // Solo canales configurados: nunca se inventan datos.
                      if (hasChannels) ...[
                        const SizedBox(height: 24),
                        const Text('Otros canales',
                            style: TextStyle(
                                color: _ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Wrap(spacing: 10, runSpacing: 10, children: [
                          if (whatsapp.isNotEmpty)
                            OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                    Uri.parse('https://wa.me/$whatsapp')),
                                icon: const Icon(Icons.chat_outlined),
                                label: const Text('WhatsApp')),
                          if (email.isNotEmpty)
                            OutlinedButton.icon(
                                onPressed: () => launchUrl(
                                    Uri(scheme: 'mailto', path: email)),
                                icon: const Icon(Icons.mail_outline),
                                label: const Text('Correo')),
                          if (instagram.isNotEmpty)
                            OutlinedButton.icon(
                                onPressed: () =>
                                    launchUrl(Uri.parse(instagram)),
                                icon: const Icon(Icons.camera_alt_outlined),
                                label: const Text('Instagram')),
                        ]),
                      ],
                      const SizedBox(height: 32),
                      const _LegalNavigation(current: _LegalPage.contact),
                    ],
                  ),
                ),
              ),
            ),
            const RancoSiteFooter(width: RancoContainerWidth.detail),
          ],
        ),
      ),
    );
  }
}
