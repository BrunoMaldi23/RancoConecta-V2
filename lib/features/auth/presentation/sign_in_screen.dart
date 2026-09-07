import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../config/app_config.dart';
import '../../../core/widgets/ranco_app_bar.dart';
import '../../../theme/ranco_colors.dart';
import '../data/supabase_auth_repository.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

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
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.width < 390;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 16 : 22,
              vertical: 20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  Image.asset(
                    'assets/branding/ranco_logo_login.png',
                    width: isCompact ? 215 : 245,
                    fit: BoxFit.contain,
                  ),

                  const SizedBox(height: 22),

                  Container(
                    padding: EdgeInsets.all(isCompact ? 18 : 22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFD4E2DC),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x12000000),
                          blurRadius: 18,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _FieldLabel('Correo'),
                          const SizedBox(height: 7),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.email,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'tu correo electrónico',
                              prefixIcon: Icon(
                                Icons.mail_outline_rounded,
                              ),
                            ),
                            validator: validateEmail,
                          ),

                          const SizedBox(height: 14),

                          const _FieldLabel('Contraseña'),
                          const SizedBox(height: 7),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [
                              AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              hintText: 'tu contraseña',
                              prefixIcon: const Icon(
                                Icons.lock_outline_rounded,
                              ),
                              suffixIcon: IconButton(
                                tooltip: _obscurePassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword =
                                        !_obscurePassword;
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
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contraseña.';
                              }

                              return null;
                            },
                          ),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                context.go('/forgot-password');
                              },
                              child: const Text(
                                'Olvidé mi contraseña',
                              ),
                            ),
                          ),

                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .errorContainer,
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onErrorContainer,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          FilledButton(
                            onPressed:
                                _loading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize:
                                  const Size.fromHeight(54),
                              backgroundColor:
                                  RancoColors.forest,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox.square(
                                    dimension: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Entrar',
                                        style: TextStyle(
                                          fontWeight:
                                              FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(
                                        Icons
                                            .arrow_forward_rounded,
                                      ),
                                    ],
                                  ),
                          ),

                          const SizedBox(height: 10),

                          TextButton.icon(
                            onPressed: () {
                              context.go('/');
                            },
                            icon: const Icon(
                              Icons.explore_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Continuar como visitante',
                            ),
                          ),

                          const SizedBox(height: 4),

                          Row(
                            children: [
                              const Expanded(
                                child: Divider(),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  'o',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ),
                              const Expanded(
                                child: Divider(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          _ProviderCta(
                            onTap: () {
                              context.go('/provider/join');
                            },
                          ),

                          if (!config.hasSupabaseConfig &&
                              config.environment ==
                                  AppEnvironment
                                      .development) ...[
                            const SizedBox(height: 12),
                            const _InfoBanner(
                              message:
                                  'Modo desarrollo: falta configurar Supabase para iniciar sesión.',
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'Conectando personas y servicios locales',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color:
                              const Color(0xFF6F8179),
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final result =
        await ref.read(authRepositoryProvider).signIn(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

    if (!mounted) return;

    result.when(
      success: (_) {
        context.go('/account');
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style:
          Theme.of(context).textTheme.labelLarge?.copyWith(
                color: RancoColors.forest,
                fontWeight: FontWeight.w800,
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
      color: const Color(0xFFE1F0EA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: RancoColors.forest,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Quieres ofrecer un servicio?',
                      style: TextStyle(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Registra tu servicio en Ranco Conecta',
                      style: TextStyle(
                        color: Color(0xFF687A72),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: RancoColors.forest,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

///
/// Pantalla introductoria antes de comenzar el registro.
///
class ProviderJoinScreen extends StatelessWidget {
  const ProviderJoinScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF4F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF4F0),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () {
            context.go('/sign-in');
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
        title: const Text(
          'Publicar mi servicio',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDEFE7),
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.storefront_outlined,
                    color: RancoColors.forest,
                    size: 30,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  'Haz visible tu servicio',
                  style: Theme.of(context)
                      .textTheme
                      .headlineMedium
                      ?.copyWith(
                        color: RancoColors.forest,
                        fontWeight: FontWeight.w800,
                      ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Crea tu cuenta, completa tu publicación y elige una membresía para aparecer en Ranco Conecta.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                ),

                const SizedBox(height: 26),

                const _JoinStep(
                  number: '1',
                  title: 'Registra tu cuenta',
                  subtitle:
                      'Usaremos tus datos para administrar tu publicación.',
                ),

                const _JoinStep(
                  number: '2',
                  title: 'Describe tu servicio',
                  subtitle:
                      'Agrega nombre, categoría, ubicación y contacto.',
                ),

                const _JoinStep(
                  number: '3',
                  title: 'Elige tu cobertura',
                  subtitle:
                      'Selecciona las localidades donde prestas servicios.',
                ),

                const _JoinStep(
                  number: '4',
                  title: 'Selecciona tu membresía',
                  subtitle:
                      'Los prestadores publicados utilizan una membresía anual.',
                ),

                const SizedBox(height: 20),

                FilledButton.icon(
                  onPressed: () {
                    context.go('/provider/register');
                  },
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                  ),
                  label: const Text(
                    'Comenzar inscripción',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize:
                        const Size.fromHeight(54),
                    backgroundColor:
                        RancoColors.forest,
                    foregroundColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 8),

                OutlinedButton(
                  onPressed: () {
                    context.go('/sign-in');
                  },
                  child: const Text(
                    'Ya tengo cuenta',
                  ),
                ),
              ],
            ),
          ),
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
  });

  final String number;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD7E4DE),
          ),
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: RancoColors.forest,
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color:
                          RancoColors.forest,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

///
/// Se conserva por compatibilidad.
/// Ya no aparece como opción en el login.
///
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({
    super.key,
  });

  @override
  ConsumerState<SignUpScreen> createState() =>
      _SignUpScreenState();
}

class _SignUpScreenState
    extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController =
      TextEditingController();
  final _emailController =
      TextEditingController();
  final _passwordController =
      TextEditingController();
  final _confirmPasswordController =
      TextEditingController();

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
    return Scaffold(
      appBar:
          const RancoAppBar(title: 'Crear cuenta'),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Crear cuenta',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall,
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Esta pantalla queda disponible para compatibilidad del proyecto.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                        ),
                  ),

                  const SizedBox(height: 22),

                  TextFormField(
                    controller: _nameController,
                    textCapitalization:
                        TextCapitalization.words,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Nombre completo',
                      prefixIcon: Icon(
                        Icons
                            .person_outline_rounded,
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'Ingresa tu nombre.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(
                      labelText: 'Correo',
                      prefixIcon: Icon(
                        Icons.mail_outline_rounded,
                      ),
                    ),
                    validator: validateEmail,
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                        _passwordController,
                    obscureText:
                        _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(
                        Icons
                            .lock_outline_rounded,
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword =
                                !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons
                                  .visibility_outlined
                              : Icons
                                  .visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.length < 8) {
                        return 'Usa al menos 8 caracteres.';
                      }

                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  TextFormField(
                    controller:
                        _confirmPasswordController,
                    obscureText:
                        _obscurePassword,
                    decoration:
                        const InputDecoration(
                      labelText:
                          'Confirmar contraseña',
                      prefixIcon: Icon(
                        Icons
                            .lock_reset_outlined,
                      ),
                    ),
                    validator: (value) {
                      if (value !=
                          _passwordController.text) {
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
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed:
                        _loading ? null : _signUp,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.person_add_outlined,
                          ),
                    label:
                        const Text('Crear cuenta'),
                  ),

                  TextButton(
                    onPressed: () {
                      context.go('/sign-in');
                    },
                    child:
                        const Text('Volver'),
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

    final result =
        await ref.read(authRepositoryProvider).signUp(
              fullName:
                  _nameController.text.trim(),
              email:
                  _emailController.text.trim(),
              password:
                  _passwordController.text,
            );

    if (!mounted) return;

    result.when(
      success: (user) {
        setState(() {
          _message =
              user == null ||
                      !user.emailConfirmed
                  ? 'Cuenta creada. Revisa tu correo para confirmar el acceso si Supabase lo solicita.'
                  : 'Cuenta creada correctamente.';
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

class ForgotPasswordScreen
    extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({
    super.key,
  });

  @override
  ConsumerState<ForgotPasswordScreen>
      createState() =>
          _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController =
      TextEditingController();

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
      appBar: const RancoAppBar(
        title: 'Recuperar contraseña',
      ),
      body: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Te enviaremos un correo de recuperación si la cuenta existe.',
                  ),

                  const SizedBox(height: 20),

                  TextFormField(
                    controller:
                        _emailController,
                    keyboardType:
                        TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(
                      labelText: 'Correo',
                    ),
                    validator: validateEmail,
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
                        color: Theme.of(context)
                            .colorScheme
                            .error,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  FilledButton.icon(
                    onPressed:
                        _loading ? null : _submitReset,
                    icon: const Icon(
                      Icons
                          .mark_email_read_outlined,
                    ),
                    label: const Text(
                      'Enviar correo',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
      _error = null;
    });

    final result = await ref
        .read(authRepositoryProvider)
        .sendPasswordResetEmail(
          _emailController.text.trim(),
        );

    if (!mounted) return;

    result.when(
      success: (_) {
        setState(() {
          _message =
              'Correo de recuperación enviado.';
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