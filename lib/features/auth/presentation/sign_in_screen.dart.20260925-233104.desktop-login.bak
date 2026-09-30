import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';

import '../../../core/widgets/ranco_app_bar.dart';

import '../../../theme/ranco_colors.dart';

import '../data/supabase_auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({
    this.nextRoute,
    super.key,
  });

  final String? nextRoute;

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

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;

            final isNarrow = width < 370;
            final isShort = height < 720;

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
                          onTogglePassword: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                          onForgotPassword: () {
                            final next = _safeNextRoute(widget.nextRoute);
                            final uri = Uri(
                              path: '/forgot-password',
                              queryParameters:
                                  next == null ? null : {'next': next},
                            );
                            context.go(uri.toString());
                          },
                          onSubmit: _loading ? null : _submit,
                          onGuest: () {
                            context.go('/');
                          },
                          providerFlow: _safeNextRoute(widget.nextRoute) ==
                              '/provider/register',
                          onProvider: () {
                            context.go('/provider/join');
                          },
                          onCreateProviderAccess: () {
                            final uri = Uri(
                              path: '/sign-up',
                              queryParameters: const {
                                'next': '/provider/register',
                              },
                            );
                            context.go(uri.toString());
                          },
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
                            message:
                                'Modo desarrollo: falta configurar Supabase para iniciar sesión.',
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

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.compact,
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
      padding: EdgeInsets.all(
        compact ? 17 : 20,
      ),
      decoration: BoxDecoration(
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
              height: 48,
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
                    borderRadius: BorderRadius.circular(13),
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
      if (user != null) {
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
        path: '/sign-in',
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

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                isNarrow ? 16 : 20,
                14,
                isNarrow ? 16 : 20,
                24,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
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
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          17,
                        ),
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
                                fontSize: 23,
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
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _JoinStep(
                        number: '01',
                        title: 'Identifícate',
                        subtitle:
                            'Inicia sesión o crea tu acceso para gestionar la publicación.',
                      ),
                      const _JoinStep(
                        number: '02',
                        title: 'Completa tu negocio',
                        subtitle:
                            'Agrega nombre, tipo, categoría, contacto e información principal.',
                      ),
                      const _JoinStep(
                        number: '03',
                        title: 'Define dónde operas',
                        subtitle:
                            'Selecciona la ubicación y las localidades donde atiendes.',
                      ),
                      const _JoinStep(
                        number: '04',
                        title: 'Envía a revisión',
                        subtitle:
                            'Revisaremos la información antes de publicar el negocio.',
                        isLast: true,
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        height: 48,
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
                              fontSize: 13.5,
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
                              fontSize: 12.5,
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
                          fontSize: 11.5,
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
                      fontSize: 10.5,
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
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 12,
                      height: 1.35,
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    providerFlow ? 'Crea tu acceso' : 'Crear cuenta',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    providerFlow
                        ? 'Necesitas un acceso para guardar tu publicación y administrar tu negocio.'
                        : 'Crea tu acceso para guardar favoritos, gestionar solicitudes y usar las funciones de Ranco Conecta.',
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
                    child: const Text('Volver'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
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
