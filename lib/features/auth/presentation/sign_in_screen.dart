import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../core/widgets/ranco_brand.dart';

import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_tokens.dart';
import '../../legal/presentation/consent_fields.dart';
import '../../auth/application/auth_controller.dart';
import '../../profile/application/profile_providers.dart';

import '../data/supabase_auth_repository.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../router/session_actions.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    this.nextRoute,
    this.providerAccess = false,
    super.key,
  });

  final String? nextRoute;
  final bool providerAccess;

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    if (widget.providerAccess) return _buildProviderAccess(config);

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final isDesktop = width >= 1024;
            final isNarrow = width < 370;
            final isShort = height < 720;

            final providerFlow = _safeNextRoute(widget.nextRoute) == '/account';

            void forgotPassword() {
              final next = _safeNextRoute(widget.nextRoute);

              final uri = Uri(
                path: '/forgot-password',
                queryParameters: next == null ? null : {'next': next},
              );

              context.go(uri.toString());
            }

            void createProviderAccess() {
              final uri = Uri(
                path: '/sign-up',
                queryParameters: const {
                  'next': '/account',
                },
              );

              context.go(uri.toString());
            }

            // ==================================================
            // DESKTOP
            // ==================================================

            if (isDesktop) {
              final availableWidth = width - 64;
              final availableHeight = height - 48;

              final desktopWidth =
                  availableWidth > 1220 ? 1220.0 : availableWidth;

              final desktopHeight =
                  availableHeight > 700 ? 700.0 : availableHeight;

              return AutofillGroup(
                child: Center(
                  child: SizedBox(
                    width: desktopWidth,
                    height: desktopHeight,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color(0xFFD9E6E0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF173E31).withValues(alpha: .09),
                            blurRadius: 48,
                            offset: const Offset(0, 20),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // =====================================
                          // FOTO
                          // =====================================

                          const Expanded(
                            flex: 55,
                            child: _DesktopLoginVisualPanel(),
                          ),

                          // =====================================
                          // LOGIN
                          // =====================================

                          Expanded(
                            flex: 45,
                            child: Container(
                              color: const Color(0xFFFCFEFD),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 46,
                              ),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 430,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Center(
                                        child: Image.asset(
                                          'assets/branding/'
                                          'ranco_logo_login.png',
                                          width: 205,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      const Text(
                                        'Bienvenido',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: RancoColors.textPrimary,
                                          fontSize: 30,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -.65,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      const Text(
                                        'Ingresa a tu cuenta para '
                                        'continuar en Ranco Conecta.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: RancoColors.textSecondary,
                                          fontSize: 14,
                                          height: 1.4,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 30),
                                      _LoginCard(
                                        formKey: _formKey,
                                        emailController: _emailController,
                                        passwordController: _passwordController,
                                        obscurePassword: _obscurePassword,
                                        loading: _loading,
                                        error: _error,
                                        compact: false,
                                        desktop: true,
                                        onTogglePassword: () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                        onForgotPassword: forgotPassword,
                                        onSubmit: _loading ? null : _submit,
                                        onGuest: () {
                                          context.go('/');
                                        },
                                        providerFlow: providerFlow,
                                        onProvider: () {
                                          context.go(
                                            '/provider/join',
                                          );
                                        },
                                        onCreateProviderAccess:
                                            createProviderAccess,
                                      ),
                                      if (!config.hasSupabaseConfig &&
                                          config.environment ==
                                              AppEnvironment.development) ...[
                                        const SizedBox(height: 12),
                                        const _InfoBanner(
                                          message: 'Modo desarrollo: '
                                              'falta configurar '
                                              'Supabase para '
                                              'iniciar sesión.',
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            // ==================================================
            // MOBILE / TABLET
            // Se conserva el diseño compacto actual.
            // ==================================================

            final horizontalPadding = isNarrow ? 14.0 : 20.0;

            final verticalPadding = isShort ? 10.0 : 18.0;

            final logoWidth = isNarrow
                ? 195.0
                : isShort
                    ? 205.0
                    : 225.0;

            final availableHeight =
                constraints.maxHeight - (verticalPadding * 2);

            return AutofillGroup(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: 410,
                      minHeight: availableHeight > 0 ? availableHeight : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: isShort
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        if (isShort) const SizedBox(height: 2),
                        Image.asset(
                          'assets/branding/ranco_logo_login.png',
                          width: logoWidth,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(
                          height: isShort ? 12 : 20,
                        ),
                        _LoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          loading: _loading,
                          error: _error,
                          compact: isNarrow || isShort,
                          desktop: false,
                          onTogglePassword: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          onForgotPassword: forgotPassword,
                          onSubmit: _loading ? null : _submit,
                          onGuest: () {
                            context.go('/');
                          },
                          providerFlow: providerFlow,
                          onProvider: () {
                            context.go('/provider/join');
                          },
                          onCreateProviderAccess: createProviderAccess,
                        ),
                        const SizedBox(height: 13),
                        const Text(
                          'Ranco Conecta · Lago Ranco',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF718078),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (!config.hasSupabaseConfig &&
                            config.environment ==
                                AppEnvironment.development) ...[
                          const SizedBox(height: 12),
                          const _InfoBanner(
                            message: 'Modo desarrollo: falta configurar '
                                'Supabase para iniciar sesión.',
                          ),
                        ],
                        if (!isShort) const SizedBox(height: 8),
                      ],
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

  Widget _buildProviderAccess(AppConfig config) {
    final next = _safeNextRoute(widget.nextRoute);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                color: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: const BorderSide(color: Color(0xFFE1EBE6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => context.go(Uri(
                                path: '/sign-in',
                                queryParameters:
                                    next == null ? null : {'next': next},
                              ).toString()),
                              icon: const Icon(Icons.arrow_back_rounded,
                                  size: 18),
                              label: const Text('Volver'),
                              style: TextButton.styleFrom(
                                foregroundColor: RancoColors.primaryDark,
                                minimumSize: const Size(44, 44),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Image.asset(
                              'assets/branding/ranco_logo_login.png',
                              width: 196,
                              height: 80,
                              fit: BoxFit.contain,
                              semanticLabel: 'Ranco Conecta',
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('PORTAL PARA NEGOCIOS LOCALES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.primaryDark,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          const Text('Acceso proveedor',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textPrimary,
                                  fontSize: 26,
                                  letterSpacing: -.3,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          const Text('Gestiona tu negocio en Ranco.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textSecondary,
                                  fontSize: 14)),
                          const SizedBox(height: 22),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                            ),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) =>
                                _loading ? null : _submit(),
                            decoration: InputDecoration(
                              labelText: 'Contraseña',
                              prefixIcon:
                                  const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                              ),
                            ),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Ingresa tu contraseña.'
                                : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go(Uri(
                                path: '/forgot-password',
                                queryParameters:
                                    next == null ? null : {'next': next},
                              ).toString()),
                              child: const Text('Olvidé mi contraseña'),
                            ),
                          ),
                          if (_error != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Color(0xFFAA3D32))),
                            ),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              child:
                                  Text(_loading ? 'Ingresando...' : 'Ingresar'),
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1),
                          const SizedBox(height: 14),
                          // Onboarding: acción secundaria, no compite con
                          // "Ingresar".
                          const Text('¿Aún no tienes acceso proveedor?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textSecondary,
                                  fontSize: 14)),
                          const SizedBox(height: 8),
                          OutlinedButton(
                            onPressed: () => context.go('/provider/join'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                            ),
                            child: const Text('Ser parte de Ranco Conecta'),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                              'Crea tu acceso para gestionar tus servicios o negocio.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textSecondary,
                                  fontSize: 12.5)),
                          if (!config.hasSupabaseConfig &&
                              config.environment == AppEnvironment.development)
                            const _InfoBanner(
                                message:
                                    'Modo desarrollo: falta configurar Supabase para iniciar sesión.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref.read(authRepositoryProvider).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;

    await result.when(
      success: (signedInUser) async {
        // The Auth stream may still contain the previous account here. Wait for
        // this UID before reading its profile or entering the authenticated UI.
        final resolved = Completer<String?>();
        final subscription = ref.listenManual(
          authStateProvider,
          (_, state) {
            if (state.valueOrNull?.id == signedInUser.id &&
                !resolved.isCompleted) {
              resolved.complete(signedInUser.id);
            }
          },
          fireImmediately: true,
        );
        String? resolvedUserId;
        try {
          resolvedUserId = await resolved.future
              .timeout(const Duration(seconds: 10), onTimeout: () => null);
        } finally {
          subscription.close();
        }
        if (!mounted) return;
        if (resolvedUserId != signedInUser.id) {
          setState(() => _error = 'No pudimos preparar tu sesión. Reintenta.');
          return;
        }
        ref.invalidate(currentProfileProvider);
        try {
          await ref.read(currentProfileProvider.future);
          if (mounted) {
            context.go(widget.providerAccess
                ? '/account'
                : (_safeNextRoute(widget.nextRoute) ?? '/account'));
          }
        } catch (_) {
          if (mounted) {
            setState(() => _error = 'No pudimos cargar tu perfil. Reintenta.');
          }
        }
      },
      failure: (failure) async {
        setState(() => _error = failure.message);
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

class _DesktopLoginVisualPanel extends StatelessWidget {
  const _DesktopLoginVisualPanel();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // FOTO LIMPIA
        Image.asset(
          'assets/branding/fondo-hero.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),

        // SOMBRA SOLO ABAJO.
        // La parte superior conserva cielo y paisaje naturales.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x00112821),
                Color(0x33112821),
                Color(0xC9143027),
              ],
              stops: [
                0.0,
                .48,
                .68,
                1.0,
              ],
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            42,
            36,
            42,
            40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // UBICACION
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(
                    alpha: .94,
                  ),
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: .06,
                      ),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 17,
                      color: RancoColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Lago Ranco',
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // TITULO
              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 480,
                ),
                child: const Text(
                  'Todo lo local,\nen un solo lugar.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 43,
                    fontWeight: FontWeight.w900,
                    height: 1.01,
                    letterSpacing: -1.2,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // PEQUEÑA LINEA VISUAL
              Container(
                width: 44,
                height: 3,
                decoration: BoxDecoration(
                  color: const Color(0xFF59B68B),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),

              const SizedBox(height: 14),

              ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: Text(
                  'Encuentra servicios, comercios, '
                  'gastronomía, alojamientos y experiencias '
                  'de la comunidad.',
                  style: TextStyle(
                    color: Colors.white.withValues(
                      alpha: .94,
                    ),
                    fontSize: 14.5,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.compact,
    required this.desktop,
    required this.onTogglePassword,
    required this.onForgotPassword,
    required this.onSubmit,
    required this.onGuest,
    required this.onProvider,
    required this.providerFlow,
    required this.onCreateProviderAccess,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool loading;
  final bool compact;
  final bool desktop;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onForgotPassword;
  final VoidCallback? onSubmit;
  final VoidCallback onGuest;
  final VoidCallback onProvider;
  final bool providerFlow;
  final VoidCallback onCreateProviderAccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: desktop
          ? EdgeInsets.zero
          : EdgeInsets.all(
              compact ? 17 : 20,
            ),
      decoration: desktop
          ? null
          : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFD4E2DC),
              ),
              boxShadow: [
                BoxShadow(
                  color: RancoColors.forest.withValues(alpha: .055),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _FieldLabel('Correo'),
            const SizedBox(height: 6),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: _inputDecoration(
                hintText: 'tu correo electrónico',
                prefixIcon: Icons.mail_outline_rounded,
              ),
              validator: validateEmail,
            ),
            const SizedBox(height: 13),
            const _FieldLabel('Contraseña'),
            const SizedBox(height: 6),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onFieldSubmitted: (_) {
                onSubmit?.call();
              },
              decoration: _inputDecoration(
                hintText: 'tu contraseña',
                prefixIcon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: obscurePassword
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: onTogglePassword,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 19,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu contraseña.';
                }
                return null;
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onForgotPassword,
                style: TextButton.styleFrom(
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: RancoColors.forest,
                ),
                child: const Text(
                  'Olvidé mi contraseña',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 4),
            SizedBox(
              height: desktop ? 54 : 48,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.login_rounded,
                        size: 18,
                      ),
                label: Text(
                  loading ? 'Ingresando...' : 'Entrar',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      RancoColors.forest.withValues(alpha: .6),
                  disabledForegroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(desktop ? 14 : 13),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            TextButton.icon(
              onPressed: onGuest,
              icon: const Icon(
                Icons.explore_outlined,
                size: 17,
              ),
              label: const Text(
                'Continuar como visitante',
              ),
              style: TextButton.styleFrom(
                foregroundColor: RancoColors.forest,
                padding: const EdgeInsets.symmetric(vertical: 8),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            const _LoginDivider(),
            const SizedBox(height: 11),
            if (providerFlow)
              _CreateProviderAccessCta(
                onTap: onCreateProviderAccess,
              )
            else
              _ProviderCta(
                onTap: onProvider,
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: 13.5,
      ),
      prefixIcon: Icon(
        prefixIcon,
        size: 19,
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(
        horizontal: desktop ? 16 : 12,
        vertical: desktop ? 16 : 13,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(desktop ? 14 : 13),
        borderSide: const BorderSide(
          color: Color(0xFFD1E0D9),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(desktop ? 14 : 13),
        borderSide: const BorderSide(
          color: RancoColors.primary,
          width: 1.3,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(desktop ? 14 : 13),
        borderSide: BorderSide(
          color: Colors.red.shade300,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(desktop ? 14 : 13),
        borderSide: BorderSide(
          color: Colors.red.shade400,
          width: 1.3,
        ),
      ),
    );
  }
}

class _LoginDivider extends StatelessWidget {
  const _LoginDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            height: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
          ),
          child: Text(
            'o',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: RancoColors.textSecondary,
                  fontSize: 11,
                ),
          ),
        ),
        const Expanded(
          child: Divider(
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: RancoColors.forest,
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
      ),
    );
  }
}

class _ProviderCta extends StatelessWidget {
  const _ProviderCta({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE7F2ED),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 58,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: RancoColors.forest,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Tienes un negocio?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Publícalo gratis en Ranco Conecta',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF687A72),
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                color: RancoColors.forest,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CreateProviderAccessCta extends StatelessWidget {
  const _CreateProviderAccessCta({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE7F2ED),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.symmetric(
            horizontal: 11,
            vertical: 9,
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(
                      Radius.circular(10),
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_outlined,
                    color: RancoColors.forest,
                    size: 19,
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Primera vez en Ranco Conecta?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Crea tu acceso para publicar tu negocio',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFF687A72),
                        fontSize: 11.5,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_rounded,
                color: RancoColors.forest,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProviderJoinScreen extends ConsumerWidget {
  const ProviderJoinScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).currentUser();

    Future<void> startPublication() async {
      if (user != null && !user.isAnonymous) {
        final result =
            await ref.read(authRepositoryProvider).registerProviderIdentity();
        if (!context.mounted) return;
        result.when(
          success: (_) {
            ref.invalidate(currentProfileProvider);
            context.go('/account');
          },
          failure: (_) => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No pudimos registrar tu acceso proveedor.'),
            ),
          ),
        );
        return;
      }

      final uri = Uri(
        path: '/sign-up',
        queryParameters: const {
          'next': '/account',
        },
      );
      context.go(uri.toString());
    }

    // Con sesión iniciada el primer paso (crear acceso) ya está hecho.
    final signedIn = user != null && !user.isAnonymous;

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final gutter = constraints.maxWidth < 370 ? 16.0 : 20.0;

            void back() {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/sign-in');
              }
            }

            final cta = FilledButton.icon(
              onPressed: startPublication,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(
                signedIn ? 'Activar mi acceso prestador' : 'Crear mi acceso',
              ),
              style: FilledButton.styleFrom(
                minimumSize: Size(wide ? 220 : double.infinity, 52),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                gutter,
                wide ? 20 : 8,
                gutter,
                wide ? 48 : 28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Encabezado de página discreto (la marca vive en el
                      // hero, sin logo aislado arriba).
                      Row(
                        children: [
                          IconButton(
                            tooltip: 'Volver',
                            onPressed: back,
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              side: const BorderSide(color: RancoColors.border),
                              fixedSize: const Size(44, 44),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 20,
                              color: RancoColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Ser parte de Ranco Conecta',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: RancoColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: wide ? 24 : 16),
                      _JoinHero(wide: wide),
                      SizedBox(height: wide ? 32 : 24),
                      Semantics(
                        header: true,
                        child: const Text(
                          'Cómo funciona',
                          style: TextStyle(
                            color: RancoColors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Tablet y móvil: stepper vertical compacto.
                      _JoinStepper(
                        wide: constraints.maxWidth >= 900,
                        firstDone: signedIn,
                      ),
                      SizedBox(height: wide ? 28 : 24),
                      if (wide)
                        Row(
                          children: [
                            cta,
                            const SizedBox(width: 18),
                            const Expanded(child: _JoinFootnote()),
                          ],
                        )
                      else ...[
                        cta,
                        const SizedBox(height: 12),
                        const _JoinFootnote(),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Hero de incorporación: marca + propuesta a la izquierda y beneficios
/// reales a la derecha (apilados en móvil).
class _JoinHero extends StatelessWidget {
  const _JoinHero({required this.wide});

  final bool wide;

  static const _benefits = [
    (Icons.storefront_outlined, 'Presencia en el catálogo local'),
    (Icons.inbox_outlined, 'Solicitudes y reservas en un solo lugar'),
    (Icons.edit_outlined, 'Perfil editable desde tu cuenta'),
  ];

  @override
  Widget build(BuildContext context) {
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            RancoBrandMark(size: 36),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'PARA NEGOCIOS DE LAGO RANCO',
                style: TextStyle(
                  color: RancoColors.primaryDark,
                  fontSize: 11.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: wide ? 18 : 14),
        Text(
          'Haz visible tu negocio',
          style: TextStyle(
            color: RancoColors.primaryDark,
            fontSize: wide ? 32 : 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Crea tu perfil, muestra tus servicios y conecta con personas de la '
          'zona.',
          style: TextStyle(
            color: RancoColors.textPrimary.withValues(alpha: .78),
            fontSize: wide ? 16 : 15,
            height: 1.5,
          ),
        ),
      ],
    );

    final benefits = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _benefits.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_benefits[i].$1,
                    size: 18, color: RancoColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _benefits[i].$2,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        wide ? 32 : 20,
        wide ? 28 : 20,
        wide ? 32 : 20,
        wide ? 28 : 20,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F3EC), Color(0xFFF5FAF7)],
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: intro),
                const SizedBox(width: 32),
                Expanded(flex: 5, child: benefits),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                intro,
                const SizedBox(height: 18),
                benefits,
              ],
            ),
    );
  }
}

class _JoinFootnote extends StatelessWidget {
  const _JoinFootnote();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(
          Icons.bookmark_border_rounded,
          size: 16,
          color: RancoColors.textSecondary,
        ),
        SizedBox(width: 6),
        Flexible(
          child: Text(
            'Puedes guardar tu avance y continuar más tarde.',
            style: TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

/// Proceso en 4 pasos: horizontal en desktop, vertical compacto en móvil.
class _JoinStepper extends StatelessWidget {
  const _JoinStepper({required this.wide, required this.firstDone});

  final bool wide;

  /// Con sesión iniciada, "Crear acceso" se marca como hecho.
  final bool firstDone;

  static const _steps = [
    (
      Icons.person_add_alt_1_outlined,
      'Crear acceso',
      'Tu correo y una contraseña.'
    ),
    (
      Icons.storefront_outlined,
      'Completar negocio',
      'Tipo, información y categoría.'
    ),
    (
      Icons.place_outlined,
      'Definir cobertura',
      'Las localidades donde atiendes.'
    ),
    (
      Icons.fact_check_outlined,
      'Enviar a revisión',
      'Revisamos antes de publicar.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE3ECE7)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _steps.length; i++)
                Expanded(
                  child: _JoinStep(
                    number: i + 1,
                    icon: _steps[i].$1,
                    title: _steps[i].$2,
                    subtitle: _steps[i].$3,
                    done: i == 0 && firstDone,
                    isLast: i == _steps.length - 1,
                    horizontal: true,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < _steps.length; i++)
            _JoinStep(
              number: i + 1,
              icon: _steps[i].$1,
              title: _steps[i].$2,
              subtitle: _steps[i].$3,
              done: i == 0 && firstDone,
              isLast: i == _steps.length - 1,
              horizontal: false,
            ),
        ],
      ),
    );
  }
}

class _JoinStep extends StatelessWidget {
  const _JoinStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.done,
    required this.isLast,
    required this.horizontal,
  });

  final int number;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool done;
  final bool isLast;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: done ? RancoColors.forest : RancoColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
          : Text(
              number.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: RancoColors.primaryDark,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
    final connector = Container(
      color: const Color(0xFFDCE9E2),
      width: horizontal ? null : 2,
      height: horizontal ? 2 : null,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: const Color(0xFF7FA594)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
      ],
    );

    return Semantics(
      label: 'Paso $number de 4: $title${done ? ', completado' : ''}',
      excludeSemantics: true,
      child: horizontal
          ? Padding(
              padding: EdgeInsets.only(right: isLast ? 0 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    badge,
                    if (!isLast) ...[
                      const SizedBox(width: 10),
                      Expanded(child: connector),
                    ],
                  ]),
                  const SizedBox(height: 12),
                  text,
                ],
              ),
            )
          : IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        badge,
                        if (!isLast)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: connector,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: 6, bottom: isLast ? 0 : 16),
                      child: text,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    this.nextRoute,
    super.key,
  });

  final String? nextRoute;

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();

  bool _loading = false;

  bool _obscurePassword = true;

  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _acceptedDataProcessing = false;

  String? _message;

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();

    _emailController.dispose();

    _passwordController.dispose();

    _confirmPasswordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final providerFlow = _safeNextRoute(widget.nextRoute) == '/account';

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: RancoAppBar(
        title: providerFlow ? 'Crear acceso' : 'Crear cuenta',
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;
        final form = Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: RancoBrandMark(size: 52)),
              const SizedBox(height: 16),
              Text(
                providerFlow ? 'Crea tu acceso' : 'Crear cuenta',
                textAlign: wide ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: RancoColors.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                providerFlow
                    ? 'Únete a Ranco Conecta como prestador.'
                    : 'Crea tu acceso para guardar favoritos, gestionar solicitudes y usar las funciones de Ranco Conecta.',
                textAlign: wide ? TextAlign.center : TextAlign.start,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa tu nombre.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Correo',
                  prefixIcon: Icon(
                    Icons.mail_outline_rounded,
                  ),
                ),
                validator: validateEmail,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 8) {
                    return 'Usa al menos 8 caracteres.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscurePassword,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(
                    Icons.lock_reset_outlined,
                  ),
                ),
                validator: (value) {
                  if (value != _passwordController.text) {
                    return 'Las contraseñas no coinciden.';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 16),
              ConsentFields(
                terms: _acceptedTerms,
                privacy: _acceptedPrivacy,
                dataProcessing: _acceptedDataProcessing,
                onTerms: (value) => setState(() => _acceptedTerms = value),
                onPrivacy: (value) => setState(() => _acceptedPrivacy = value),
                onDataProcessing: (value) =>
                    setState(() => _acceptedDataProcessing = value),
              ),
              if (_message != null) ...[
                const SizedBox(height: 12),
                _InfoBanner(
                  message: _message!,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _loading ? null : _signUp,
                icon: _loading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.person_add_outlined,
                      ),
                label: Text(
                  providerFlow ? 'Crear acceso' : 'Crear cuenta',
                ),
              ),
              TextButton(
                onPressed: () {
                  final next = _safeNextRoute(widget.nextRoute);
                  final uri = Uri(
                    path: providerFlow ? '/provider/sign-in' : '/sign-in',
                    queryParameters: next == null ? null : {'next': next},
                  );
                  context.go(uri.toString());
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
                child: Text(providerFlow
                    ? '¿Ya tienes acceso? Ingresar'
                    : 'Ya tengo una cuenta · Ingresar'),
              ),
            ],
          ),
        );
        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: wide ? 32 : 16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: RancoWidths.auth),
              child: wide
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(36, 32, 36, 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: const Color(0xFFE1EBE6)),
                        boxShadow: [
                          BoxShadow(
                            color: RancoColors.ink.withValues(alpha: .05),
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: form,
                    )
                  : form,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_acceptedTerms || !_acceptedPrivacy || !_acceptedDataProcessing) {
      setState(() =>
          _error = 'Acepta los tres consentimientos para crear tu cuenta.');
      return;
    }

    setState(() {
      _loading = true;

      _error = null;

      _message = null;
    });

    final result = await ref.read(authRepositoryProvider).signUp(
          fullName: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          consentAccepted: true,
          providerRegistration: _safeNextRoute(widget.nextRoute) == '/account',
          emailRedirectPath: '/account',
        );

    if (!mounted) return;

    result.when(
      success: (user) {
        final next = _safeNextRoute(widget.nextRoute);

        if (user != null && user.emailConfirmed) {
          context.go(next ?? '/account');
          return;
        }

        setState(() {
          _message = 'Revisa tu correo para continuar';
        });
      },
      failure: (failure) {
        setState(() {
          _error = failure.message;
        });
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    this.nextRoute,
    super.key,
  });

  final String? nextRoute;

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _loading = false;
  bool _resending = false;

  /// Correo al que se pidió el enlace. Con valor, la vista muestra el estado
  /// "Revisa tu correo" en lugar del formulario.
  String? _sentTo;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _goToSignIn() {
    final next = _safeNextRoute(widget.nextRoute);
    final uri = Uri(
      path: '/sign-in',
      queryParameters: next == null ? null : {'next': next},
    );
    context.go(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final content = AnimatedSwitcher(
              duration: RancoDurations.normal,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: _sentTo == null
                  ? KeyedSubtree(
                      key: const ValueKey('form'),
                      child: _form(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('sent'),
                      child: _sent(_sentTo!),
                    ),
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, wide ? 24 : 8, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Volver',
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              _goToSignIn();
                            }
                          },
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: RancoColors.border),
                            fixedSize: const Size(44, 44),
                          ),
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: RancoColors.primaryDark,
                          ),
                        ),
                      ),
                      SizedBox(height: wide ? 24 : 12),
                      // Misma pieza que Crear acceso: tarjeta en pantallas
                      // amplias, superficie plana en móvil.
                      if (wide)
                        Container(
                          padding: const EdgeInsets.fromLTRB(36, 32, 36, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE1EBE6)),
                            boxShadow: [
                              BoxShadow(
                                color: RancoColors.ink.withValues(alpha: .05),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: content,
                        )
                      else
                        content,
                      const SizedBox(height: 20),
                      const Text(
                        'Ranco Conecta · Lago Ranco',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: RancoBrandMark(size: 52)),
          const SizedBox(height: 16),
          Semantics(
            header: true,
            child: const Text(
              'Recuperar contraseña',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: RancoColors.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa el correo asociado a tu cuenta.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onFieldSubmitted: (_) {
              if (!_loading) _submitReset();
            },
            decoration: const InputDecoration(
              labelText: 'Correo',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: validateEmail,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ResetMessage(message: _error!, success: false),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _loading ? null : _submitReset,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_outlined, size: 18),
            label: Text(_loading ? 'Enviando…' : 'Enviar instrucciones'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: _goToSignIn,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: const Text('Volver a iniciar sesión'),
          ),
        ],
      ),
    );
  }

  Widget _sent(String email) {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RancoColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 28,
                color: RancoColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Revisa tu correo',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          // Redacción neutra: no confirma si la cuenta existe.
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Si hay una cuenta asociada a '),
                TextSpan(
                  text: email,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: ', recibirás un enlace para crear una nueva '
                      'contraseña. Revisa también la carpeta de spam.',
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ResetMessage(message: _error!, success: false),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _goToSignIn,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
            child: const Text('Volver a iniciar sesión'),
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 4,
            children: [
              TextButton.icon(
                onPressed: _resending ? null : _resend,
                icon: _resending
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 18),
                label: Text(_resending ? 'Reenviando…' : 'Reenviar correo'),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _sentTo = null;
                  _error = null;
                }),
                style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
                child: const Text('Usar otro correo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitReset() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final result =
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _sentTo = email;
        });
      },
      failure: (failure) {
        setState(() {
          _error = failure.message;
        });
      },
    );

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  /// Reenvía con la misma llamada existente (sin lógica nueva de backend).
  Future<void> _resend() async {
    final email = _sentTo;
    if (email == null) return;
    setState(() {
      _resending = true;
      _error = null;
    });
    final result =
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
    if (!mounted) return;
    result.when(
      success: (_) => showRancoSuccess(context, 'Te reenviamos el correo.'),
      failure: (failure) => setState(() => _error = failure.message),
    );
    setState(() => _resending = false);
  }
}

/// The recovery link establishes a short lived Supabase session. This form
/// consumes it without asking for the old password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;
  bool _obscure = true;

  /// Contraseña guardada: la vista muestra "Contraseña actualizada" mientras
  /// corre el cierre de sesión existente (mismo flujo que antes).
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Requisito existente (mínimo 8) visible en vivo.
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(authRepositoryProvider)
        .updateRecoveredPassword(_password.text);
    if (!mounted) return;
    await result.when(
      success: (_) async {
        setState(() => _done = true);
        await _finish();
      },
      failure: (failure) async {
        setState(() => _error = failure.message);
      },
    );
    if (mounted) setState(() => _saving = false);
  }

  /// Cierre de sesión y salida al ingreso: misma llamada y destino que
  /// implementó Codex. El aviso queda visible en la pantalla de ingreso.
  Future<void> _finish() async {
    const destination = '/provider/sign-in';
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.maybeOf(context);
    await signOutAndGoToSignIn(
      context,
      ref,
      destination: destination,
    );
    // El helper solo navega si cerró la sesión: entonces el aviso queda
    // visible en el ingreso (messenger de la app, compartido entre rutas).
    final location = router?.routerDelegate.currentConfiguration.uri.path ?? '';
    if (location == destination) {
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
          content: Row(children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Contraseña actualizada. Ingresa con tu nueva contraseña.',
              ),
            ),
          ]),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    // Tras guardar, el cierre de sesión deja auth vacío: el éxito tiene
    // prioridad para que no aparezca el estado de enlace caducado.
    final Widget body;
    final String key;
    if (_done) {
      key = 'done';
      body = _success();
    } else if (auth.isLoading && !auth.hasValue) {
      key = 'loading';
      body = const _ResetSkeleton();
    } else if (auth.valueOrNull == null) {
      key = 'expired';
      body = _expired();
    } else {
      key = 'form';
      body = _form();
    }

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 600;
            final content = AnimatedSwitcher(
              duration: RancoDurations.normal,
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: child,
                ),
              ),
              child: KeyedSubtree(key: ValueKey(key), child: body),
            );
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(16, wide ? 56 : 24, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Misma pieza que Crear acceso y Recuperar contraseña.
                      if (wide)
                        Container(
                          padding: const EdgeInsets.fromLTRB(36, 32, 36, 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFE1EBE6)),
                            boxShadow: [
                              BoxShadow(
                                color: RancoColors.ink.withValues(alpha: .05),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: content,
                        )
                      else
                        content,
                      const SizedBox(height: 20),
                      const Text(
                        'Ranco Conecta · Lago Ranco',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: RancoBrandMark(size: 52)),
        const SizedBox(height: 16),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 14.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _form() {
    final long = _password.text.length >= 8;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heading(
            'Crear nueva contraseña',
            'Elige una contraseña para volver a ingresar a tu cuenta.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _password,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Nueva contraseña',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(_obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined),
              ),
            ),
            validator: (value) =>
                (value?.length ?? 0) < 8 ? 'Usa al menos 8 caracteres.' : null,
          ),
          const SizedBox(height: 8),
          Semantics(
            label: long
                ? 'Requisito cumplido: al menos 8 caracteres'
                : 'Requisito: al menos 8 caracteres',
            excludeSemantics: true,
            child: Row(children: [
              AnimatedSwitcher(
                duration: RancoDurations.quick,
                child: Icon(
                  long
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(long),
                  size: 16,
                  color: long ? RancoColors.forest : const Color(0xFFA9B8B1),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Al menos 8 caracteres',
                style: TextStyle(
                  color: long
                      ? RancoColors.textPrimary
                      : RancoColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _confirmation,
            obscureText: _obscure,
            autofillHints: const [AutofillHints.newPassword],
            onFieldSubmitted: (_) {
              if (!_saving) _save();
            },
            decoration: const InputDecoration(
              labelText: 'Confirmar contraseña',
              prefixIcon: Icon(Icons.lock_reset_outlined),
            ),
            validator: (value) => value != _password.text
                ? 'Las contraseñas no coinciden.'
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ResetMessage(message: _error!, success: false),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_saving ? 'Guardando…' : 'Guardar contraseña'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _success() {
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RancoColors.primarySoft,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                size: 28,
                color: RancoColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Contraseña actualizada',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Por seguridad cerramos esta sesión. Ingresa con tu nueva '
            'contraseña.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RancoColors.textSecondary,
              fontSize: 14.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 22),
          // Normalmente la navegación ocurre sola; el botón cubre el caso en
          // que el cierre de sesión no pudo completarse.
          FilledButton.icon(
            onPressed: _saving
                ? null
                : () async {
                    setState(() => _saving = true);
                    await _finish();
                    if (mounted) setState(() => _saving = false);
                  },
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded, size: 18),
            label: Text(_saving ? 'Cerrando sesión…' : 'Ir a iniciar sesión'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _expired() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.link_off_rounded,
              size: 28,
              color: Color(0xFF8A5B12),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'El enlace caducó o ya fue utilizado.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RancoColors.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Los enlaces de recuperación sirven una sola vez y por tiempo '
          'limitado. Solicita uno nuevo para continuar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 14.5,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: () => context.go('/forgot-password'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          child: const Text('Solicitar otro enlace'),
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () => context.go('/sign-in'),
          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(44)),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}

/// Carga de la sesión de recuperación con la forma del formulario.
class _ResetSkeleton extends StatelessWidget {
  const _ResetSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: const Column(
        children: [
          RancoSkeletonBox(width: 52, height: 52, radius: 26),
          SizedBox(height: 16),
          RancoSkeletonBox(width: 240, height: 22),
          SizedBox(height: 10),
          RancoSkeletonBox(width: 280, height: 12),
          SizedBox(height: 24),
          RancoSkeletonBox(height: 56, radius: 12),
          SizedBox(height: 14),
          RancoSkeletonBox(height: 56, radius: 12),
          SizedBox(height: 20),
          RancoSkeletonBox(height: 50, radius: 14),
        ],
      ),
    );
  }
}

class _ResetMessage extends StatelessWidget {
  const _ResetMessage({
    required this.message,
    required this.success,
  });

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final background = success
        ? const Color(0xFFE7F3ED)
        : Theme.of(context).colorScheme.errorContainer;

    final foreground = success
        ? RancoColors.forest
        : Theme.of(context).colorScheme.onErrorContainer;

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            success
                ? Icons.check_circle_outline_rounded
                : Icons.error_outline_rounded,
            size: 18,
            color: foreground,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: foreground,
                fontSize: 12.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFE8F0ED),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF486158),
          ),
        ),
      ),
    );
  }
}

String? _safeNextRoute(String? value) {
  final route = value?.trim();

  if (route == null || route.isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(route);

  if (uri == null ||
      uri.hasScheme ||
      uri.host.isNotEmpty ||
      !route.startsWith('/') ||
      route.startsWith('//')) {
    return null;
  }

  if (route == '/sign-in' ||
      route.startsWith('/sign-up') ||
      route.startsWith('/forgot-password')) {
    return null;
  }

  return route;
}

String? validateEmail(String? value) {
  final email = value?.trim() ?? '';

  if (email.isEmpty) {
    return 'Ingresa tu correo.';
  }

  if (!RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(email)) {
    return 'Ingresa un correo válido.';
  }

  return null;
}
