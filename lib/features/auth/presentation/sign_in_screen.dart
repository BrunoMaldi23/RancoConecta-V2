import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';

import '../../../core/widgets/ranco_app_bar.dart';

import '../../../theme/ranco_colors.dart';
import '../../legal/presentation/consent_fields.dart';

import '../data/supabase_auth_repository.dart';

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

            final providerFlow =
                _safeNextRoute(widget.nextRoute) == '/provider/register';

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
                  'next': '/provider/register',
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
                          'Ranco Conecta ? Lago Ranco',
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
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                color: Colors.white,
                elevation: 6,
                shadowColor: const Color(0x24194532),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: RancoColors.border),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(22),
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
                          const SizedBox(height: 6),
                          Center(
                            child: Image.asset(
                              'assets/branding/ranco_logo_login.png',
                              width: 252,
                              height: 104,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const Text('PORTAL PARA NEGOCIOS LOCALES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.primaryDark,
                                  fontSize: 10,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          const Text('Acceso proveedor',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textPrimary,
                                  fontSize: 25,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          const Text('Gestiona tu negocio en Ranco.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: RancoColors.textSecondary,
                                  fontSize: 13)),
                          const SizedBox(height: 15),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline_rounded),
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 11),
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
                              border: const OutlineInputBorder(),
                              isDense: true,
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
                            Text(_error!,
                                style:
                                    const TextStyle(color: Color(0xFFAA3D32))),
                          const SizedBox(height: 7),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                backgroundColor: RancoColors.primaryDark,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child:
                                  Text(_loading ? 'Ingresando...' : 'Ingresar'),
                            ),
                          ),
                          const SizedBox(height: 5),
                          TextButton(
                            onPressed: () => context.go('/provider/join'),
                            child:
                                const Text('¿Aún no tienes acceso proveedor?'),
                          ),
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

    result.when(
      success: (_) {
        context.go(
          _safeNextRoute(widget.nextRoute) ?? '/account',
        );
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

    void startPublication() {
      if (user != null && !user.isAnonymous) {
        context.go('/provider/register');
        return;
      }

      final uri = Uri(
        path: '/sign-up',
        queryParameters: const {
          'next': '/provider/register',
        },
      );
      context.go(uri.toString());
    }

    void signInToContinue() {
      final uri = Uri(
        path: '/provider/sign-in',
        queryParameters: const {
          'next': '/provider/register',
        },
      );
      context.go(uri.toString());
    }

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 370;
            final wide = constraints.maxWidth >= 720;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 20,
                wide ? 40 : 14,
                isNarrow ? 16 : 20,
                wide ? 40 : 24,
              ),
              child: Center(
                // Desktop: columna de lectura de ~600px, no un formulario
                // diminuto en el centro de la pantalla.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 580,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/sign-in');
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 40,
                                height: 40,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD4E2DC),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.arrow_back_rounded,
                                  size: 20,
                                  color: RancoColors.forest,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Publicar mi negocio',
                              style: TextStyle(
                                color: RancoColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: wide ? 32 : 28),
                      Container(
                        padding: EdgeInsets.all(wide ? 24 : 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6FAF8),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFD1E2DA),
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 42,
                              height: 42,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: Color(0xFFE4F2EC),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: RancoColors.forest,
                                  size: 21,
                                ),
                              ),
                            ),
                            SizedBox(height: 15),
                            Text(
                              'Haz visible tu negocio',
                              style: TextStyle(
                                color: RancoColors.forest,
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                                height: 1.05,
                              ),
                            ),
                            SizedBox(height: 7),
                            Text(
                              'Crea tu perfil, completa la información y envíalo a revisión. Publicar inicialmente es gratis.',
                              style: TextStyle(
                                color: RancoColors.textSecondary,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Pasos agrupados en una superficie; el CTA queda
                      // inmediatamente debajo, como cierre del recorrido.
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFDDE7E2)),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _JoinStep(
                              number: '01',
                              title: 'Identifícate',
                              subtitle:
                                  'Inicia sesión o crea tu acceso para gestionar la publicación.',
                            ),
                            _JoinStep(
                              number: '02',
                              title: 'Completa tu negocio',
                              subtitle:
                                  'Agrega nombre, tipo, categoría, contacto e información principal.',
                            ),
                            _JoinStep(
                              number: '03',
                              title: 'Define dónde operas',
                              subtitle:
                                  'Selecciona la ubicación y las localidades donde atiendes.',
                            ),
                            _JoinStep(
                              number: '04',
                              title: 'Envía a revisión',
                              subtitle:
                                  'Revisaremos la información antes de publicar el negocio.',
                              isLast: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: startPublication,
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                          ),
                          label: Text(
                            user == null
                                ? 'Comenzar publicación'
                                : 'Continuar publicación',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: RancoColors.forest,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(13),
                            ),
                          ),
                        ),
                      ),
                      if (user == null) ...[
                        const SizedBox(height: 7),
                        TextButton(
                          onPressed: signInToContinue,
                          style: TextButton.styleFrom(
                            foregroundColor: RancoColors.forest,
                          ),
                          child: const Text(
                            'Ya tengo una cuenta',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Puedes guardar el progreso y continuar más tarde.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors.textSecondary,
                          fontSize: 12.5,
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
}

class _JoinStep extends StatelessWidget {
  const _JoinStep({
    required this.number,
    required this.title,
    required this.subtitle,
    this.isLast = false,
  });

  final String number;
  final String title;
  final String subtitle;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 42,
            child: Column(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4F2EC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFC8DDD3),
                    ),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      margin: const EdgeInsets.symmetric(
                        vertical: 5,
                      ),
                      color: const Color(0xFFD3E2DB),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: 3,
                bottom: isLast ? 0 : 17,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
    final providerFlow =
        _safeNextRoute(widget.nextRoute) == '/provider/register';

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
              Center(
                child: Image.asset(
                  'assets/branding/ranco_logo_login.png',
                  height: 56,
                  fit: BoxFit.contain,
                  semanticLabel: 'Ranco Conecta',
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 14),
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
                    ? 'Necesitas un acceso para guardar tu publicación y administrar tu negocio.'
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
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: RancoColors.forest,
                  foregroundColor: Colors.white,
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
                    path: '/sign-in',
                    queryParameters: next == null ? null : {'next': next},
                  );
                  context.go(uri.toString());
                },
                child: const Text('Ya tengo una cuenta · Ingresar'),
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
              constraints: const BoxConstraints(maxWidth: 480),
              child: wide
                  ? Container(
                      padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: RancoColors.border),
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
          _message =
              'Acceso creado. Revisa tu correo para confirmar la cuenta y luego inicia sesión para continuar.';
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
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 370;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 20,
                14,
                isNarrow ? 16 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 410,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ForgotPasswordHeader(
                        onBack: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            final next = _safeNextRoute(widget.nextRoute);
                            final uri = Uri(
                              path: '/sign-in',
                              queryParameters:
                                  next == null ? null : {'next': next},
                            );
                            context.go(uri.toString());
                          }
                        },
                      ),
                      const SizedBox(height: 34),
                      Center(
                        child: Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2EB),
                            borderRadius: BorderRadius.circular(17),
                          ),
                          child: const Icon(
                            Icons.lock_reset_rounded,
                            size: 28,
                            color: RancoColors.forest,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Center(
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RancoColors.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                            height: 1.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10,
                        ),
                        child: Text(
                          'Ingresa el correo asociado a tu cuenta y te enviaremos las instrucciones para recuperar el acceso.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: RancoColors.textSecondary,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: EdgeInsets.all(
                          isNarrow ? 17 : 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: const Color(0xFFD4E2DC),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: RancoColors.forest.withValues(
                                alpha: .045,
                              ),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Correo',
                                style: TextStyle(
                                  color: RancoColors.forest,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [
                                  AutofillHints.email,
                                ],
                                onFieldSubmitted: (_) {
                                  if (!_loading) {
                                    _submitReset();
                                  }
                                },
                                decoration: InputDecoration(
                                  hintText: 'tu correo electrónico',
                                  hintStyle: const TextStyle(
                                    fontSize: 13.5,
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.mail_outline_rounded,
                                    size: 19,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 13,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFD1E0D9),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: RancoColors.primary,
                                      width: 1.3,
                                    ),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: BorderSide(
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: BorderSide(
                                      color: Colors.red.shade400,
                                      width: 1.3,
                                    ),
                                  ),
                                ),
                                validator: validateEmail,
                              ),
                              if (_message != null) ...[
                                const SizedBox(height: 12),
                                _ResetMessage(
                                  message: _message!,
                                  success: true,
                                ),
                              ],
                              if (_error != null) ...[
                                const SizedBox(height: 12),
                                _ResetMessage(
                                  message: _error!,
                                  success: false,
                                ),
                              ],
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 48,
                                child: FilledButton.icon(
                                  onPressed: _loading ? null : _submitReset,
                                  icon: _loading
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.mark_email_read_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _loading
                                        ? 'Enviando...'
                                        : 'Enviar instrucciones',
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: RancoColors.forest,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor:
                                        RancoColors.forest.withValues(
                                      alpha: .6,
                                    ),
                                    disabledForegroundColor: Colors.white,
                                    textStyle: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            final next = _safeNextRoute(widget.nextRoute);
                            final uri = Uri(
                              path: '/sign-in',
                              queryParameters:
                                  next == null ? null : {'next': next},
                            );
                            context.go(uri.toString());
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            size: 17,
                          ),
                          label: const Text(
                            'Volver a iniciar sesión',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: RancoColors.forest,
                            textStyle: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Ranco Conecta · Lago Ranco',
                          style: TextStyle(
                            color: RancoColors.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
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

  Future<void> _submitReset() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });

    final result =
        await ref.read(authRepositoryProvider).sendPasswordResetEmail(
              _emailController.text.trim(),
            );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        setState(() {
          _message =
              'Te enviamos las instrucciones de recuperación. Revisa tu correo y la carpeta de spam.';
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

class _ForgotPasswordHeader extends StatelessWidget {
  const _ForgotPasswordHeader({
    required this.onBack,
  });

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onBack,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFD4E2DC),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: RancoColors.forest,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Text(
            'Recuperar contraseña',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: RancoColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
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
