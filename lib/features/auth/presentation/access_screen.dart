import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/result/result.dart';
import '../../../core/telemetry/telemetry.dart';
import '../../../features/locations/application/location_providers.dart';
import '../../../shared/models/location.dart';
import '../../../theme/ranco_colors.dart';
import '../../profile/application/profile_providers.dart';
import '../../legal/data/consent_repository.dart';
import '../../legal/presentation/consent_fields.dart';
import '../application/auth_controller.dart';
import '../data/supabase_auth_repository.dart';
import '../data/visitor_profile_repository.dart';
import 'visitor_contact_validation.dart';

class AccessScreen extends ConsumerStatefulWidget {
  const AccessScreen({this.nextRoute, super.key});

  final String? nextRoute;

  @override
  ConsumerState<AccessScreen> createState() => _AccessScreenState();
}

class _AccessScreenState extends ConsumerState<AccessScreen> {
  final bool _busy = false;
  String? _error;

  Future<void> _continueAsGuest() async {
    if (_busy) return;
    Telemetry.capture('visitor_enter');
    context.go(_safeNext(widget.nextRoute) ?? '/');
  }

  @override
  Widget build(BuildContext context) {
    final providerNext = _safeNext(widget.nextRoute, allowProtected: true);
    if (_busy) return const _AccessSkeleton();
    return _WelcomeLayout(
      contactIntent: false,
      onVisitor: _continueAsGuest,
      onProvider: () => context.go(Uri(
        path: '/provider/sign-in',
        queryParameters: providerNext == null ? null : {'next': providerNext},
      ).toString()),
      error: _error,
      onRetry: _continueAsGuest,
    );
  }
}

class VisitorProfileScreen extends ConsumerStatefulWidget {
  const VisitorProfileScreen({this.nextRoute, super.key});

  final String? nextRoute;

  @override
  ConsumerState<VisitorProfileScreen> createState() =>
      _VisitorProfileScreenState();
}

class _VisitorProfileScreenState extends ConsumerState<VisitorProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String? _locationId;
  String? _error;
  bool _busy = false;
  bool _initialized = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _acceptedDataProcessing = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms || !_acceptedPrivacy || !_acceptedDataProcessing) {
      setState(
          () => _error = 'Acepta los tres consentimientos para continuar.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    if (ref.read(authRepositoryProvider).currentUser() == null &&
        ref.read(authStateProvider).valueOrNull == null) {
      final session =
          await ref.read(authRepositoryProvider).signInAnonymously();
      if (!mounted) return;
      if (session case Failure()) {
        setState(() {
          _error = 'No pudimos crear tu perfil. Intenta nuevamente.';
          _busy = false;
        });
        return;
      }
    }
    try {
      await ref
          .read(consentRepositoryProvider)
          .record(context: 'visitor_contact');
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'No pudimos guardar tu consentimiento. Intenta nuevamente.';
          _busy = false;
        });
      }
      return;
    }
    final result = await ref.read(visitorProfileRepositoryProvider).save(
          fullName: _name.text,
          phone: _phone.text,
          email: _email.text.isEmpty ? null : _email.text,
          locationId: _locationId,
        );
    if (!mounted) return;
    if (result case Failure()) {
      setState(() {
        _error = 'No pudimos crear tu perfil. Intenta nuevamente.';
        _busy = false;
      });
      return;
    }

    try {
      ref.invalidate(currentProfileProvider);
      final confirmed = await ref.read(currentProfileProvider.future);
      if (!mounted) return;
      if (confirmed.fullName?.trim() != _name.text.trim() ||
          confirmed.phone?.trim() != _phone.text.trim()) {
        throw StateError('Visitor contact details were not confirmed.');
      }

      final selected = ref
          .read(locationsProvider)
          .valueOrNull
          ?.where((location) => location.id == _locationId)
          .firstOrNull;
      ref.read(selectedLocationProvider.notifier).state = selected;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil creado correctamente')),
      );
      context.go(_safeNext(widget.nextRoute) ?? '/explore');
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'No pudimos crear tu perfil. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continueWithoutProfile() async {
    if (_busy) return;
    final activeUser = ref.read(authRepositoryProvider).currentUser() ??
        ref.read(authStateProvider).valueOrNull;
    if (activeUser?.isAnonymous == true) {
      setState(() {
        _busy = true;
        _error = null;
      });
      final result = await ref.read(authRepositoryProvider).signOut();
      if (!mounted) return;
      if (result case Failure()) {
        setState(() {
          _error = 'No pudimos continuar como visitante. Intenta nuevamente.';
          _busy = false;
        });
        return;
      }
      ref.invalidate(currentProfileProvider);
    }
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    if (auth.isLoading && !auth.hasValue) {
      return const _AccessSkeleton();
    }
    final profileAsync = auth.valueOrNull?.isAnonymous == true
        ? ref.watch(currentProfileProvider)
        : null;
    if (!_busy &&
        profileAsync != null &&
        profileAsync.isLoading &&
        !profileAsync.hasValue) {
      return const _AccessSkeleton();
    }
    if (!_busy &&
        profileAsync != null &&
        profileAsync.hasError &&
        !profileAsync.hasValue) {
      return _AccessLayout(
        child: _AccessError(
          message: 'No pudimos cargar tu perfil.',
          onRetry: () => ref.invalidate(currentProfileProvider),
        ),
      );
    }
    final profile = profileAsync?.valueOrNull;
    if (!_initialized && profile != null) {
      _name.text = profile.fullName ?? '';
      _phone.text = profile.phone ?? '';
      final metadata =
          ref.read(supabaseClientProvider)?.auth.currentUser?.userMetadata;
      _email.text = metadata?['visitor_email']?.toString() ?? '';
      final savedLocation = metadata?['visitor_location_id']?.toString();
      _locationId = savedLocation?.isNotEmpty == true ? savedLocation : null;
      _initialized = true;
    } else if (!_initialized && auth.valueOrNull == null) {
      _initialized = true;
    }
    final locations = ref.watch(locationsProvider).valueOrNull ?? <Location>[];
    return _AccessLayout(
      child: Form(
        key: _formKey,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy
                  ? null
                  : () {
                      final next = _safeNext(widget.nextRoute);
                      context.go(Uri(path: '/sign-in', queryParameters: {
                        'choose': '1',
                        if (next != null) 'next': next,
                      }).toString());
                    },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Volver'),
              style: TextButton.styleFrom(
                foregroundColor: RancoColors.primaryDark,
                minimumSize: const Size(44, 44),
              ),
            ),
          ),
          const _AccessBrand(width: 204, height: 88),
          const Text('TU EXPERIENCIA EN RANCO',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RancoColors.primaryDark,
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          const Text('Crea tu perfil visitante',
              style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 23,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text(
            'Solo necesitamos tus datos para que los negocios puedan responderte.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RancoColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline)),
            validator: (value) => value == null || value.trim().length < 3
                ? 'Ingresa tu nombre completo.'
                : null,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+56 9 XXXX XXXX',
                prefixIcon: Icon(Icons.phone_outlined)),
            validator: validateVisitorWhatsapp,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Correo opcional',
                prefixIcon: Icon(Icons.mail_outline)),
            validator: (value) => value != null &&
                    value.trim().isNotEmpty &&
                    !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(value.trim())
                ? 'Ingresa un correo válido.'
                : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: locations.any((item) => item.id == _locationId)
                ? _locationId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Localidad opcional',
                prefixIcon: Icon(Icons.place_outlined)),
            items: [
              for (final location in locations)
                DropdownMenuItem(
                    value: location.id, child: Text(location.name)),
            ],
            onChanged: (value) => setState(() => _locationId = value),
          ),
          const SizedBox(height: 8),
          ConsentFields(
            terms: _acceptedTerms,
            privacy: _acceptedPrivacy,
            dataProcessing: _acceptedDataProcessing,
            onTerms: (value) => setState(() => _acceptedTerms = value),
            onPrivacy: (value) => setState(() => _acceptedPrivacy = value),
            onDataProcessing: (value) =>
                setState(() => _acceptedDataProcessing = value),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            _AccessError(message: _error!, onRetry: _busy ? null : _save),
          ],
          const SizedBox(height: 13),
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: RancoColors.primaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(_busy ? 'Guardando...' : 'Continuar'),
            ),
          ),
          const SizedBox(height: 5),
          TextButton(
            onPressed: _busy ? null : _continueWithoutProfile,
            style: TextButton.styleFrom(
              foregroundColor: RancoColors.primaryDark,
              minimumSize: const Size(44, 44),
            ),
            child: const Text('Explorar primero'),
          ),
          const SizedBox(height: 6),
          const Text(
              'Si guardas tu perfil, compartiremos tu nombre y teléfono al solicitar un servicio.',
              textAlign: TextAlign.center,
              style: TextStyle(color: RancoColors.textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _AccessSkeleton extends StatelessWidget {
  const _AccessSkeleton();

  @override
  Widget build(BuildContext context) => const _AccessLayout(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SkeletonBar(width: 104, height: 64),
            SizedBox(height: 16),
            Text('Preparando tu experiencia...',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: RancoColors.forest,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            SizedBox(height: 12),
            _SkeletonBar(width: double.infinity, height: 15),
            SizedBox(height: 20),
            _SkeletonBar(width: double.infinity, height: 78),
            SizedBox(height: 10),
            _SkeletonBar(width: double.infinity, height: 78),
          ],
        ),
      );
}

class _SkeletonBar extends StatelessWidget {
  const _SkeletonBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0EB),
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _AccessError extends StatelessWidget {
  const _AccessError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline, color: Color(0xFFAA3D32), size: 19),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Color(0xFF943C32), fontSize: 12)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ]),
      );
}

class _WelcomeLayout extends StatelessWidget {
  const _WelcomeLayout({
    required this.contactIntent,
    required this.onVisitor,
    required this.onProvider,
    required this.error,
    required this.onRetry,
  });

  final bool contactIntent;
  final VoidCallback onVisitor;
  final VoidCallback onProvider;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F7F2),
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 768;
            final outerPadding = desktop ? 24.0 : 12.0;
            final content = _WelcomeContent(
              contactIntent: contactIntent,
              onVisitor: onVisitor,
              onProvider: onProvider,
              error: error,
              onRetry: onRetry,
            );
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: desktop ? 24 : 16,
                vertical: outerPadding,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: desktop ? 1120 : 560,
                    minHeight: (constraints.maxHeight - outerPadding * 2)
                        .clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: Material(
                      color: Colors.white,
                      elevation: 8,
                      shadowColor: const Color(0x29194532),
                      borderRadius: BorderRadius.circular(26),
                      clipBehavior: Clip.antiAlias,
                      child: desktop
                          ? IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Expanded(
                                    flex: 46,
                                    child: _WelcomeHero(desktop: true),
                                  ),
                                  Expanded(
                                    flex: 54,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 36, vertical: 30),
                                      child: Center(child: content),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 22, 20, 24),
                              child: content,
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero({required this.desktop});

  final bool desktop;

  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/branding/fondo-hero.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
            semanticLabel: 'Lago, bosques y montañas de Ranco',
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x000A2B22), Color(0xBA0A2B22)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: desktop ? 28 : 18,
            right: desktop ? 28 : 18,
            bottom: desktop ? 30 : 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LAGO RANCO · CHILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: desktop ? 12 : 5),
                Text(
                  'Lago Ranco, un lugar para quedarse, explorar y conectar.',
                  maxLines: desktop ? 3 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: desktop ? 31 : 19,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(color: Color(0x66000000), blurRadius: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _WelcomeContent extends StatelessWidget {
  const _WelcomeContent({
    required this.contactIntent,
    required this.onVisitor,
    required this.onProvider,
    required this.error,
    required this.onRetry,
  });

  final bool contactIntent;
  final VoidCallback onVisitor;
  final VoidCallback onProvider;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AccessBrand(width: 280, height: 112),
          const SizedBox(height: 1),
          const Text('DESCUBRE LA CUENCA DEL RANCO',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RancoColors.primaryDark,
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Bienvenido a Ranco Conecta',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: MediaQuery.sizeOf(context).width >= 768 ? 28 : 23,
                  height: 1.1,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text(
              'Explora alojamientos, servicios y experiencias locales. Comparte tus datos solo cuando quieras reservar o contactar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: RancoColors.textSecondary,
                  fontSize: 13.5,
                  height: 1.4)),
          const SizedBox(height: 15),
          _AccessOption(
            icon: Icons.explore_outlined,
            title: 'Explorar Ranco',
            description: contactIntent
                ? 'Completa tus datos para que el negocio pueda responderte'
                : 'Descubre alojamientos, gastronomía, servicios y experiencias sin crear una cuenta.',
            action: 'Empezar a explorar',
            primary: true,
            onPressed: onVisitor,
          ),
          const SizedBox(height: 9),
          _AccessOption(
            icon: Icons.storefront_outlined,
            title: 'Tengo un negocio',
            description: 'Publica tus servicios y conecta con visitantes.',
            action: 'Continuar como prestador',
            primary: false,
            onPressed: onProvider,
          ),
          if (error != null) ...[
            const SizedBox(height: 9),
            _AccessError(message: error!, onRetry: onRetry),
          ],
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, spacing: 4, children: [
            TextButton(
                onPressed: () => context.push('/terminos'),
                child: const Text('Términos')),
            TextButton(
                onPressed: () => context.push('/politica-privacidad'),
                child: const Text('Privacidad')),
            TextButton(
                onPressed: () => context.push('/contacto'),
                child: const Text('Contacto')),
          ]),
        ],
      );
}

class _AccessLayout extends StatelessWidget {
  const _AccessLayout({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF5F7F2),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final contentWidth = width >= 1024
                  ? 520.0
                  : width >= 600
                      ? width * .9
                      : width - 32;
              return Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: SizedBox(
                    width: contentWidth,
                    child: Card(
                      color: Colors.white,
                      elevation: 6,
                      shadowColor: const Color(0x24194532),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                        side: const BorderSide(color: RancoColors.border),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: child,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

class _AccessBrand extends StatelessWidget {
  const _AccessBrand({this.width = 184, this.height = 82});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/branding/ranco_logo_login.png',
        width: width,
        height: height,
        fit: BoxFit.contain,
      );
}

class _AccessOption extends StatelessWidget {
  const _AccessOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.action,
    required this.primary,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final String action;
  final bool primary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: primary ? const Color(0xFFF0F7F2) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: primary ? const Color(0xFFB7D9C5) : RancoColors.border,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          excludeFromSemantics: true,
          hoverColor: const Color(0x142F7D57),
          splashColor: const Color(0x302F7D57),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary
                          ? const Color(0xFFDCEDE3)
                          : const Color(0xFFF0F4F1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: RancoColors.primaryDark, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            color: RancoColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 6),
                Text(description,
                    style: const TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 13,
                        height: 1.35)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: primary
                      ? FilledButton.icon(
                          onPressed: onPressed,
                          style: FilledButton.styleFrom(
                            backgroundColor: RancoColors.primaryDark,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 17),
                          label: Text(action),
                        )
                      : OutlinedButton(
                          onPressed: onPressed,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: RancoColors.primaryDark,
                            side: const BorderSide(
                                color: RancoColors.primaryDark),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(action),
                        ),
                ),
              ],
            ),
          ),
        ),
      );
}

String? _safeNext(String? value, {bool allowProtected = false}) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      !uri.path.startsWith('/') ||
      uri.path.startsWith('//') ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.path == '/sign-in' ||
      uri.path == '/visitor/profile' ||
      uri.path == '/sign-up' ||
      (!allowProtected && uri.path.startsWith('/admin')) ||
      (!allowProtected && uri.path.startsWith('/provider'))) {
    return null;
  }
  return uri.toString();
}
