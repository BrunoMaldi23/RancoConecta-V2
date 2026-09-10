import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_app_bar.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../application/profile_providers.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({
    super.key,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(
      currentProfileProvider,
    );

    final authAsync = ref.watch(
      authStateProvider,
    );

    return Scaffold(
      backgroundColor: const Color(
        0xFFEAF4F0,
      ),
      appBar: const RancoAppBar(
        title: 'Editar perfil',
        fallbackRoute: '/account',
      ),
      body: authAsync.when(
        data: (user) {
          return profileAsync.when(
            data: (profile) {
              if (!_initialized) {
                _nameController.text = profile.fullName ?? '';

                _phoneController.text = profile.phone ?? '';

                _initialized = true;
              }

              final rawName = profile.fullName?.trim() ?? '';

              final displayName = rawName.isNotEmpty ? rawName : 'Usuario';

              final initial = displayName
                  .substring(
                    0,
                    1,
                  )
                  .toUpperCase();

              final email = user?.email ?? 'Correo no disponible';

              return SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    22,
                    18,
                    40,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 540,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ProfileHeader(
                            initial: initial,
                            name: displayName,
                            role: profile.role.label,
                            email: email,
                          ),
                          const SizedBox(
                            height: 28,
                          ),
                          const _SectionTitle(
                            title: 'DATOS PERSONALES',
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          _ProfileCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Información personal',
                                    style: TextStyle(
                                      color: Color(
                                        0xFF263A31,
                                      ),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 4,
                                  ),
                                  const Text(
                                    'Mantén tus datos actualizados para una mejor comunicación.',
                                    style: TextStyle(
                                      color: Color(
                                        0xFF71827A,
                                      ),
                                      fontSize: 13,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 22,
                                  ),
                                  TextFormField(
                                    controller: _nameController,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: const InputDecoration(
                                      labelText: 'Nombre completo',
                                      prefixIcon: Icon(
                                        Icons.person_outline_rounded,
                                      ),
                                    ),
                                    validator: (
                                      value,
                                    ) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Ingresa tu nombre.';
                                      }

                                      return null;
                                    },
                                  ),
                                  const SizedBox(
                                    height: 14,
                                  ),
                                  TextFormField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    decoration: const InputDecoration(
                                      labelText: 'Teléfono',
                                      hintText: '+56 9 1234 5678',
                                      prefixIcon: Icon(
                                        Icons.phone_outlined,
                                      ),
                                    ),
                                    validator: (
                                      value,
                                    ) {
                                      final phone = value?.trim() ?? '';

                                      if (phone.isEmpty) {
                                        return null;
                                      }

                                      final digits = phone.replaceAll(
                                        RegExp(
                                          r'[^0-9]',
                                        ),
                                        '',
                                      );

                                      if (digits.length < 8) {
                                        return 'Ingresa un teléfono válido.';
                                      }

                                      return null;
                                    },
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(
                                      height: 14,
                                    ),
                                    _ErrorMessage(
                                      message: _error!,
                                    ),
                                  ],
                                  const SizedBox(
                                    height: 22,
                                  ),
                                  SizedBox(
                                    height: 52,
                                    child: FilledButton.icon(
                                      onPressed: _saving ? null : _save,
                                      icon: _saving
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons
                                                  .check_circle_outline_rounded,
                                            ),
                                      label: Text(
                                        _saving
                                            ? 'Guardando...'
                                            : 'Guardar cambios',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: RancoColors.forest,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(
                            height: 24,
                          ),
                          const _SectionTitle(
                            title: 'SEGURIDAD Y CUENTA',
                          ),
                          const SizedBox(
                            height: 9,
                          ),
                          _ProfileCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: [
                                _AccountRow(
                                  icon: Icons.mail_outline_rounded,
                                  title: 'Correo',
                                  value: email,
                                ),
                                const Divider(
                                  height: 1,
                                  indent: 68,
                                ),
                                _PasswordRow(
                                  onTap: () {
                                    context.push(
                                      '/forgot-password',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 18,
                          ),
                          const _PrivacyHint(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (
              error,
              stackTrace,
            ) =>
                Center(
              child: Padding(
                padding: const EdgeInsets.all(
                  24,
                ),
                child: Text(
                  profileFailureMessage(
                    error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (
          error,
          stackTrace,
        ) =>
            const Center(
          child: Text(
            'No pudimos cargar tu sesión.',
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final result = await ref
        .read(
          profileRepositoryProvider,
        )
        .updateCurrentProfile(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    result.when(
      success: (_) {
        ref.invalidate(
          currentProfileProvider,
        );

        setState(() {
          _saving = false;
          _error = null;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(
            content: Text(
              'Perfil actualizado correctamente.',
            ),
          ),
        );
      },
      failure: (failure) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initial,
    required this.name,
    required this.role,
    required this.email,
  });

  final String initial;
  final String name;
  final String role;
  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(
            color: Color(
              0xFFA7F3CF,
            ),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              color: Color(
                0xFF174A35,
              ),
              fontSize: 34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(
          height: 14,
        ),
        Text(
          name,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(
              0xFF202C26,
            ),
            fontSize: 23,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 4,
        ),
        Text(
          email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(
              0xFF718078,
            ),
            fontSize: 13,
          ),
        ),
        const SizedBox(
          height: 9,
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xFFDDF3E8,
            ),
            borderRadius: BorderRadius.circular(
              30,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: RancoColors.forest,
              ),
              const SizedBox(
                width: 5,
              ),
              Text(
                role,
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(
          0xFF718078,
        ),
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.7,
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.child,
    this.padding = const EdgeInsets.all(
      20,
    ),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: const Color(
            0xFFD2E1DA,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(
              0x0A000000,
            ),
            blurRadius: 18,
            offset: Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      child: Row(
        children: [
          _SmallIcon(
            icon: icon,
          ),
          const SizedBox(
            width: 13,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(
                      0xFF263A31,
                    ),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(
                      0xFF718078,
                    ),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordRow extends StatelessWidget {
  const _PasswordRow({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(
          22,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        child: Row(
          children: [
            _SmallIcon(
              icon: Icons.lock_outline_rounded,
            ),
            SizedBox(
              width: 13,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contraseña',
                    style: TextStyle(
                      color: Color(
                        0xFF263A31,
                      ),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Cambiar contraseña',
                    style: TextStyle(
                      color: RancoColors.forest,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Color(
                0xFF718078,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallIcon extends StatelessWidget {
  const _SmallIcon({
    required this.icon,
  });

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(
          0xFFE4F1EB,
        ),
        borderRadius: BorderRadius.circular(
          12,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: 20,
        color: RancoColors.forest,
      ),
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        13,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFE9E6,
        ),
        borderRadius: BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(
              0xFFB53A2D,
            ),
            size: 19,
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(
                  0xFF8E3026,
                ),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.shield_outlined,
          color: Color(
            0xFF718078,
          ),
          size: 17,
        ),
        SizedBox(
          width: 8,
        ),
        Expanded(
          child: Text(
            'Tu información personal se utiliza únicamente para tu cuenta y la operación de Ranco Conecta.',
            style: TextStyle(
              color: Color(
                0xFF718078,
              ),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
