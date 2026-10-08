import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_brand.dart';
import '../../../core/widgets/ranco_site_footer.dart';
import '../application/legal_navigation.dart';
import '../data/contact_repository.dart';

// Paleta editorial: texto neutro; el verde queda como acento.
const _ink = Color(0xFF1F2D27);
const _body = Color(0xFF34443D);
const _muted = Color(0xFF66766F);
const _line = Color(0xFFE6ECE9);
const _accent = Color(0xFF2F7D57);
const _accentDark = Color(0xFF145A3A);
const _accentSoft = Color(0xFFEAF5EF);

/// Ancho del layout legal en desktop (índice + artículo, con padding).
const _layoutMaxWidth = 1200.0;

/// Ancho del grid de cards legales (FASE 3.24.1).
const _cardsMaxWidth = 1060.0;

/// El encabezado no supera ~900 px aunque el layout sea más ancho.
const _headerMaxWidth = 900.0;
const _pageBackground = Color(0xFFFAFBF9);

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
        // Frase existente destacada como aviso discreto.
        highlight: privacy ? 'No publicamos tu teléfono en el catálogo.' : null,
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
    void back() => leaveLegalPage(context);
    return Scaffold(
      backgroundColor: _pageBackground,
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
    required this.sections,
    this.highlight,
  });

  final _LegalPage page;
  final String title;
  final String description;
  final String? highlight;
  final List<(String, String)> sections;

  @override
  State<_LegalDocument> createState() => _LegalDocumentState();
}

/// FASE 3.24.1: las secciones son cards expandibles en lugar de un artículo
/// largo con índice. Una sola card abierta a la vez; el texto legal completo
/// solo se muestra al abrirla (sin resumirlo ni modificarlo).
class _LegalDocumentState extends State<_LegalDocument> {
  int? _open;

  void _toggle(int index) =>
      setState(() => _open = _open == index ? null : index);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final horizontal = constraints.maxWidth >= 600 ? 32.0 : 20.0;
      return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _HeaderBand(
                  horizontal: horizontal,
                  maxWidth: _cardsMaxWidth,
                  child: _LegalHeader(
                    title: widget.title,
                    description: widget.description,
                    showMeta: true,
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _cardsMaxWidth),
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCards(
                            sections: widget.sections,
                            highlight: widget.highlight,
                            open: _open,
                            onToggle: _toggle,
                            icons: widget.page == _LegalPage.privacy
                                ? _privacyIcons
                                : _termsIcons,
                          ),
                          const SizedBox(height: 28),
                          _LegalClosing(current: widget.page),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: RancoSiteFooter(width: RancoContainerWidth.legal),
          ),
        ],
      );
    });
  }
}

const _privacyIcons = [
  Icons.person_outline_rounded,
  Icons.task_alt_rounded,
  Icons.share_outlined,
  Icons.insights_outlined,
  Icons.tune_rounded,
];

const _termsIcons = [
  Icons.explore_outlined,
  Icons.storefront_outlined,
  Icons.badge_outlined,
  Icons.verified_user_outlined,
];

/// Primera oración del texto legal (literal), como resumen de la card
/// cerrada.
String legalSectionLead(String body) {
  final match = RegExp(r'^.*?[.!?](?=\s|$)').firstMatch(body.trim());
  return (match?.group(0) ?? body).trim();
}

/// Grid de cards. Desktop: dos columnas independientes (abrir una card no
/// estira a su vecina); con un número impar, la última va a ancho completo.
/// Móvil/tablet: una columna.
class _SectionCards extends StatelessWidget {
  const _SectionCards({
    required this.sections,
    required this.highlight,
    required this.open,
    required this.onToggle,
    required this.icons,
  });

  final List<(String, String)> sections;
  final String? highlight;
  final int? open;
  final ValueChanged<int> onToggle;
  final List<IconData> icons;

  Widget _card(int i) => _LegalCard(
        number: i + 1,
        icon: icons[i % icons.length],
        title: sections[i].$1,
        body: sections[i].$2,
        highlight: highlight,
        expanded: open == i,
        onToggle: () => onToggle(i),
      );

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 16.0;
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _card(i),
            ],
          ],
        );
      }
      final paired =
          sections.length.isOdd ? sections.length - 1 : sections.length;
      Widget column(int start) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = start; i < paired; i += 2) ...[
                if (i > start) const SizedBox(height: gap),
                _card(i),
              ],
            ],
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: column(0)),
              const SizedBox(width: gap),
              Expanded(child: column(1)),
            ],
          ),
          if (paired < sections.length) ...[
            const SizedBox(height: gap),
            _card(sections.length - 1),
          ],
        ],
      );
    });
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.highlight,
    required this.expanded,
    required this.onToggle,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;
  final String? highlight;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final highlighted = highlight != null && body.contains(highlight!);
    final fullText =
        highlighted ? body.replaceAll(highlight!, '').trim() : body;
    const duration = Duration(milliseconds: 180);

    return Semantics(
      button: true,
      expanded: expanded,
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: expanded ? const Color(0xFFBFDCCB) : _line,
          ),
        ),
        child: InkWell(
          onTap: onToggle,
          hoverColor: const Color(0xFFF6FAF8),
          focusColor: const Color(0x332F7D57),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(number.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            color: _accent,
                            fontSize: 13,
                            letterSpacing: .4,
                            fontWeight: FontWeight.w800,
                            fontFeatures: [FontFeature.tabularFigures()])),
                    const SizedBox(width: 10),
                    Icon(icon, size: 18, color: const Color(0xFF7FA594)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(title,
                            style: const TextStyle(
                                color: _ink,
                                fontSize: 17,
                                height: 1.25,
                                fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Cerrada: primera oración literal (máx. 2 líneas). Abierta:
                // el texto legal completo, sin cambios.
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: expanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fullText,
                                style: const TextStyle(
                                    color: _body,
                                    fontSize: 15.5,
                                    height: 1.65)),
                            if (highlighted) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: _accentSoft,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(children: [
                                  const Icon(Icons.verified_user_outlined,
                                      size: 19, color: _accentDark),
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
                        )
                      // Siempre reserva 2 líneas: cards cerradas de igual
                      // alto y filas alineadas en el grid.
                      : Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Text(legalSectionLead(body),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _muted, fontSize: 14.5, height: 1.5)),
                        ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(expanded ? 'Ocultar detalle' : 'Ver detalle',
                        style: const TextStyle(
                            color: _accentDark,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: expanded ? .5 : 0,
                      duration: duration,
                      child: const Icon(Icons.expand_more_rounded,
                          size: 20, color: _accentDark),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Banda superior que integra el encabezado con la barra: separa el título
/// del cuerpo sin encerrarlo en una tarjeta.
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.horizontal,
    required this.child,
    this.maxWidth = _layoutMaxWidth,
  });

  final double horizontal;
  final Widget child;

  /// Mismo ancho que el contenido de la página: bordes izquierdos alineados.
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 768;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF4F9F6)],
        ),
        border: Border(bottom: BorderSide(color: _line)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                horizontal, desktop ? 28 : 20, horizontal, desktop ? 24 : 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _headerMaxWidth),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
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
                fontSize: 11.5,
                letterSpacing: 1,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Semantics(
          header: true,
          child: Text(title,
              style: TextStyle(
                  color: _ink,
                  fontSize: desktop ? 30 : 25,
                  height: 1.15,
                  letterSpacing: -.5,
                  fontWeight: FontWeight.w800)),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(description,
              style: TextStyle(
                  color: _body, fontSize: desktop ? 16 : 15, height: 1.45)),
        ),
        if (showMeta) ...[
          const SizedBox(height: 10),
          // Metadatos en una línea discreta (antes: badges altos).
          const Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.event_outlined, size: 15, color: _muted),
              Text('Actualizado el 1 oct 2026',
                  style: TextStyle(color: _muted, fontSize: 13)),
              Text('·', style: TextStyle(color: _muted, fontSize: 13)),
              Text('Versión 2026-10-01',
                  style: TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ],
      ],
    );
  }
}

/// Cierre único de las páginas legales: banda de ayuda + navegación legal
/// pequeña (Términos · Privacidad · Contacto). Los enlaces usan `push` para
/// conservar el historial real de "Volver".
class _LegalClosing extends StatelessWidget {
  const _LegalClosing({required this.current});

  final _LegalPage current;

  static const _links = <(_LegalPage, String, String)>[
    (_LegalPage.terms, 'Términos', '/terminos'),
    (_LegalPage.privacy, 'Privacidad', '/politica-privacidad'),
    (_LegalPage.contact, 'Contacto', '/contacto'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En Contacto no se ofrece ir a Contacto.
        if (current != _LegalPage.contact)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F7F4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 10,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('¿Necesitas ayuda?',
                        style: TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text(
                        'Puedes utilizar el canal de contacto de Ranco Conecta.',
                        style: TextStyle(color: _body, fontSize: 14.5)),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () => openLegalPage(context, '/contacto'),
                  style:
                      OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contacto'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _line)),
          ),
          child: Semantics(
            key: const ValueKey('legal-links'),
            container: true,
            label: 'Información legal',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Text('Información legal',
                      style: TextStyle(
                          color: _muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                for (final (page, label, route) in _links)
                  _LegalLink(
                    label: label,
                    current: page == current,
                    onTap: () => openLegalPage(context, route),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalLink extends StatelessWidget {
  const _LegalLink({
    required this.label,
    required this.current,
    required this.onTap,
  });

  final String label;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Píldora: la página actual con fondo suave (sin enlace); las demás con
    // hover y foco visibles.
    return Semantics(
      link: !current,
      selected: current,
      child: Material(
        color: current ? _accentSoft : Colors.transparent,
        shape: StadiumBorder(
          side: BorderSide(color: current ? const Color(0xFFCFE3D8) : _line),
        ),
        child: InkWell(
          onTap: current ? null : onTap,
          customBorder: const StadiumBorder(),
          hoverColor: const Color(0xFFF1F6F3),
          focusColor: const Color(0x332F7D57),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Center(
                widthFactor: 1,
                child: Text(label,
                    style: TextStyle(
                        color: current ? _accentDark : _body,
                        fontSize: 13.5,
                        fontWeight:
                            current ? FontWeight.w700 : FontWeight.w600)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContactScreen extends StatefulWidget {
  const ContactScreen({this.repository, super.key});

  final ContactRepository? repository;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

/// Motivos de contacto (solo presentación; viajan en el asunto del mensaje).
const contactReasons = <(String, IconData)>[
  ('Consulta general', Icons.chat_bubble_outline_rounded),
  ('Problema con mi cuenta', Icons.manage_accounts_outlined),
  ('Negocio o publicación', Icons.storefront_outlined),
  ('Privacidad y datos', Icons.privacy_tip_outlined),
  ('Otro', Icons.more_horiz_rounded),
];

enum _ContactFeedback { none, success, error }

class _ContactScreenState extends State<ContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();
  String _reason = contactReasons.first.$1;
  _ContactFeedback _feedback = _ContactFeedback.none;
  bool _sending = false;
  String _contactEmail = '';
  String _contactWhatsApp = '';

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  Future<void> _loadChannels() async {
    try {
      final channels = await (widget.repository ??
              ContactRepository(Supabase.instance.client))
          .channels();
      if (!mounted) return;
      setState(() {
        _contactEmail = channels['email'] ?? '';
        _contactWhatsApp = channels['whatsapp'] ?? '';
      });
    } catch (_) {
      // The form remains usable if public channel settings are unavailable.
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_formKey.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _feedback = _ContactFeedback.none;
    });
    try {
      await (widget.repository ?? ContactRepository(Supabase.instance.client))
          .send(
        name: _name.text,
        email: _email.text,
        subject: _reason,
        message: _message.text,
      );
      if (!mounted) return;
      _name.clear();
      _email.clear();
      _message.clear();
      setState(() {
        _reason = contactReasons.first.$1;
        _feedback = _ContactFeedback.success;
      });
    } catch (_) {
      if (mounted) setState(() => _feedback = _ContactFeedback.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _contactEmail;
    final whatsapp = _contactWhatsApp;
    final hasChannels = whatsapp.isNotEmpty || email.isNotEmpty;
    final horizontal = MediaQuery.sizeOf(context).width >= 600 ? 32.0 : 20.0;

    final form = Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Envíanos un mensaje',
                style: TextStyle(
                    color: _ink, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            LayoutBuilder(builder: (context, constraints) {
              final name = TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (value) {
                  final length = value?.trim().length ?? 0;
                  if (length < 3) return 'Ingresa tu nombre.';
                  if (length > 120) return 'Máximo 120 caracteres.';
                  return null;
                },
              );
              final mail = TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(Icons.mail_outline_rounded),
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.length > 254) return 'Máximo 254 caracteres.';
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)
                      ? null
                      : 'Ingresa un correo válido.';
                },
              );
              if (constraints.maxWidth < 520) {
                return Column(
                    children: [name, const SizedBox(height: 12), mail]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: name),
                  const SizedBox(width: 12),
                  Expanded(child: mail),
                ],
              );
            }),
            const SizedBox(height: 18),
            const Text('Motivo de contacto',
                style: TextStyle(
                    color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Semantics(
              container: true,
              label: 'Motivo de contacto',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, icon) in contactReasons)
                    ChoiceChip(
                      selected: _reason == label,
                      showCheckmark: false,
                      avatar: Icon(icon,
                          size: 17,
                          color: _reason == label ? _accentDark : _muted),
                      label: Text(label),
                      onSelected: (_) => setState(() => _reason = label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _message,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Mensaje',
                hintText: 'Cuéntanos en qué podemos ayudarte.',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                final length = value?.trim().length ?? 0;
                if (length < 10) return 'Escribe al menos 10 caracteres.';
                if (length > 4000) return 'Máximo 4000 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Responderemos utilizando los datos que nos proporciones en '
              'este formulario.',
              style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: switch (_feedback) {
                _ContactFeedback.none => const SizedBox(width: double.infinity),
                _ContactFeedback.success => const _ContactBanner(
                    success: true,
                    text:
                        'Mensaje enviado. Te responderemos al correo indicado.',
                  ),
                _ContactFeedback.error => const _ContactBanner(
                    success: false,
                    text: 'No pudimos enviar tu mensaje. Inténtalo nuevamente.',
                  ),
              },
            ),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Enviar mensaje'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Para responderte mejor',
            style: TextStyle(
                color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final (tip, icon) in const [
          (
            'Elige el motivo que más se acerque a tu consulta.',
            Icons.label_outline_rounded
          ),
          (
            'Si es sobre un negocio, indica su nombre.',
            Icons.storefront_outlined
          ),
          (
            'Revisa que tu correo esté bien escrito.',
            Icons.alternate_email_rounded
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 18, color: _accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tip,
                    style: const TextStyle(
                        color: _body, fontSize: 14.5, height: 1.4)),
              ),
            ]),
          ),
        // Solo canales configurados: nunca se inventan datos.
        if (!hasChannels) ...[
          const SizedBox(height: 10),
          const Text('Canal de contacto adicional pendiente de configuración.',
              style: TextStyle(color: _muted, fontSize: 13.5)),
        ],
        if (hasChannels) ...[
          const SizedBox(height: 10),
          const Text('Otros canales',
              style: TextStyle(
                  color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(spacing: 10, runSpacing: 10, children: [
            if (whatsapp.isNotEmpty)
              _ChannelCard(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp',
                  value: '+$whatsapp',
                  onTap: () => launchUrl(Uri.parse('https://wa.me/$whatsapp'))),
            if (email.isNotEmpty)
              _ChannelCard(
                  icon: Icons.mail_outline,
                  label: 'Correo',
                  value: email,
                  onTap: () => launchUrl(Uri(scheme: 'mailto', path: email))),
          ]),
        ],
      ],
    );

    return _LegalScaffold(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _HeaderBand(
                  horizontal: horizontal,
                  maxWidth: 1000,
                  child: const _LegalHeader(
                    eyebrow: 'CONTACTO',
                    title: 'Hablemos',
                    description: 'Consultas, ayuda y solicitudes sobre Ranco '
                        'Conecta.',
                  ),
                ),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(horizontal, 24, horizontal, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LayoutBuilder(builder: (context, constraints) {
                            if (constraints.maxWidth < 860) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  form,
                                  const SizedBox(height: 20),
                                  aside,
                                ],
                              );
                            }
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 3, child: form),
                                const SizedBox(width: 32),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: aside,
                                  ),
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 28),
                          const _LegalClosing(current: _LegalPage.contact),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SliverToBoxAdapter(
            child: RancoSiteFooter(width: RancoContainerWidth.legal),
          ),
        ],
      ),
    );
  }
}

/// Mensaje en línea tras intentar enviar (éxito o error).
class _ContactBanner extends StatelessWidget {
  const _ContactBanner({required this.success, required this.text});

  final bool success;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tone = success ? _accentDark : const Color(0xFF8E3232);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: success ? _accentSoft : const Color(0xFFFBE7E5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(
                success
                    ? Icons.check_circle_outline_rounded
                    : Icons.error_outline_rounded,
                size: 19,
                color: tone),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text,
                  style: TextStyle(color: tone, fontSize: 14, height: 1.4)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Canal de contacto configurado (solo se muestran los que existen).
class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 320),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 20, color: _accent),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: _ink,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 13)),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
