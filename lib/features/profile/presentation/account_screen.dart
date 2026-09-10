import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../application/profile_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({
    super.key,
  });

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final auth = ref.watch(
      authStateProvider,
    );

    return ColoredBox(
      color: const Color(
        0xFFEAF4F0,
      ),
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestAccount();
          }

          final profileAsync = ref.watch(
            currentProfileProvider,
          );

          return profileAsync.when(
            data: (profile) {
              final rawName = profile.fullName?.trim() ?? '';

              final displayName = rawName.isNotEmpty ? rawName : 'Usuario';

              final initial = displayName
                  .substring(
                    0,
                    1,
                  )
                  .toUpperCase();

              final email = user.email ?? 'Correo no disponible';

              final isProvider =
                  profile.role.label.toLowerCase() == 'prestador';

              return SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    18,
                    22,
                    18,
                    38,
                  ),
                  children: [
                    const Text(
                      'Cuenta',
                      style: TextStyle(
                        color: Color(
                          0xFF22332B,
                        ),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(
                      height: 20,
                    ),
                    _AccountHeader(
                      initial: initial,
                      name: displayName,
                      email: email,
                      role: profile.role.label,
                      onEdit: () {
                        context.push(
                          '/account/edit',
                        );
                      },
                    ),
                    if (isProvider) ...[
                      const SizedBox(
                        height: 26,
                      ),
                      const _SectionTitle(
                        title: 'MI NEGOCIO',
                      ),
                      const SizedBox(
                        height: 9,
                      ),
                      ref
                          .watch(
                            myProviderBusinessProvider,
                          )
                          .when(
                            data: (business) {
                              if (business == null) {
                                return _MissingBusinessCard(
                                  onTap: () {
                                    context.push(
                                      '/provider/register',
                                    );
                                  },
                                );
                              }

                              return _BusinessCard(
                                name: business.name,
                                published:
                                    business.publicationStatus == 'published',
                                status: business.publicationStatus,
                                lodging: business.isLodging,
                                onManage: () {
                                  context.push(
                                    '/provider/dashboard',
                                  );
                                },
                                onBookings: () {
                                  context.push(
                                    '/provider/bookings',
                                  );
                                },
                                onCalendar: () {
                                  context.push(
                                    '/provider/calendar',
                                  );
                                },
                                onView: () {
                                  context.push(
                                    '/business/${business.id}',
                                  );
                                },
                              );
                            },
                            loading: () => const _BusinessLoading(),
                            error: (
                              error,
                              stackTrace,
                            ) =>
                                const _BusinessError(),
                          ),
                    ],
                    if (!isProvider) ...[
                      const SizedBox(
                        height: 26,
                      ),
                      _BecomeProviderCard(
                        onTap: () {
                          context.push(
                            '/provider/join',
                          );
                        },
                      ),
                    ],
                    const SizedBox(
                      height: 26,
                    ),
                    const _SectionTitle(
                      title: 'CUENTA Y SOPORTE',
                    ),
                    const SizedBox(
                      height: 9,
                    ),
                    _WhiteCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _SettingsRow(
                            icon: Icons.verified_user_outlined,
                            title: 'Estado de la cuenta',
                            subtitle: _accountStatusLabel(
                              profile.accountStatus,
                            ),
                          ),
                          const Divider(
                            height: 1,
                            indent: 70,
                          ),
                          const _SettingsRow(
                            icon: Icons.help_outline_rounded,
                            title: 'Ayuda y soporte',
                            subtitle: 'Preguntas frecuentes y contacto',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(
                      height: 18,
                    ),
                    SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await ref
                              .read(
                                authRepositoryProvider,
                              )
                              .signOut();

                          ref.invalidate(
                            currentProfileProvider,
                          );

                          ref.invalidate(
                            myProviderBusinessProvider,
                          );
                        },
                        icon: const Icon(
                          Icons.logout_rounded,
                        ),
                        label: const Text(
                          'Cerrar sesión',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: RancoColors.forest,
                          side: const BorderSide(
                            color: Color(
                              0xFF7C9087,
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
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
                'No pudimos cargar tu perfil.',
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
}

class _AccountHeader extends StatelessWidget {
  const _AccountHeader({
    required this.initial,
    required this.name,
    required this.email,
    required this.role,
    required this.onEdit,
  });

  final String initial;
  final String name;
  final String email;
  final String role;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
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
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
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
                fontSize: 27,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(
            width: 15,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(
                      0xFF22332B,
                    ),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(
                      0xFF718078,
                    ),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(
                  height: 7,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFE1F4EA,
                    ),
                    borderRadius: BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: RancoColors.forest,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Editar perfil',
            onPressed: onEdit,
            icon: const Icon(
              Icons.edit_outlined,
              color: RancoColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessCard extends StatelessWidget {
  const _BusinessCard({
    required this.name,
    required this.published,
    required this.status,
    required this.lodging,
    required this.onManage,
    required this.onBookings,
    required this.onCalendar,
    required this.onView,
  });

  final String name;
  final bool published;
  final String status;
  final bool lodging;

  final VoidCallback onManage;
  final VoidCallback onBookings;
  final VoidCallback onCalendar;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFDFF1E9,
        ),
        borderRadius: BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: const Color(
            0xFFC3DDD0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    16,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  lodging
                      ? Icons.holiday_village_outlined
                      : Icons.storefront_outlined,
                  color: RancoColors.forest,
                  size: 27,
                ),
              ),
              const SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(
                          0xFF22332B,
                        ),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: published
                                ? const Color(
                                    0xFF279566,
                                  )
                                : const Color(
                                    0xFFD59B35,
                                  ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          published
                              ? 'Publicado'
                              : _publicationLabel(
                                  status,
                                ),
                          style: TextStyle(
                            color: published
                                ? const Color(
                                    0xFF39715A,
                                  )
                                : const Color(
                                    0xFF8B671F,
                                  ),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 18,
          ),
          const Text(
            'GESTIÓN RÁPIDA',
            style: TextStyle(
              color: Color(
                0xFF6D8178,
              ),
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(
            height: 9,
          ),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.event_available_outlined,
                  label: 'Reservas',
                  onTap: onBookings,
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _QuickAction(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendario',
                  onTap: onCalendar,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 14,
          ),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(
                Icons.dashboard_outlined,
              ),
              label: Text(
                lodging ? 'Administrar alojamiento' : 'Administrar negocio',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: RancoColors.forest,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          TextButton.icon(
            onPressed: onView,
            icon: const Icon(
              Icons.visibility_outlined,
            ),
            label: const Text(
              'Ver publicación',
            ),
            style: TextButton.styleFrom(
              foregroundColor: RancoColors.forest,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(
        14,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          14,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 13,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: RancoColors.forest,
                size: 22,
              ),
              const SizedBox(
                height: 6,
              ),
              Text(
                label,
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MissingBusinessCard extends StatelessWidget {
  const _MissingBusinessCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFF3DC,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Completa tu publicación',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          const Text(
            'Tu cuenta de prestador está activa, pero aún falta asociar o completar tu negocio.',
            style: TextStyle(
              color: Color(
                0xFF705F42,
              ),
              height: 1.4,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          FilledButton(
            onPressed: onTap,
            child: const Text(
              'Completar publicación',
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessLoading extends StatelessWidget {
  const _BusinessLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 170,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class _BusinessError extends StatelessWidget {
  const _BusinessError();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFE9E6,
        ),
        borderRadius: BorderRadius.circular(
          18,
        ),
      ),
      child: const Text(
        'No pudimos cargar tu negocio.',
      ),
    );
  }
}

class _BecomeProviderCard extends StatelessWidget {
  const _BecomeProviderCard({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(
        0xFFDFF1E9,
      ),
      borderRadius: BorderRadius.circular(
        20,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(
          20,
        ),
        child: const Padding(
          padding: EdgeInsets.all(
            18,
          ),
          child: Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: RancoColors.forest,
                size: 28,
              ),
              SizedBox(
                width: 13,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Ofreces un servicio local?',
                      style: TextStyle(
                        color: Color(
                          0xFF22332B,
                        ),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Publica tu negocio en Ranco Conecta.',
                      style: TextStyle(
                        color: Color(
                          0xFF65786F,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
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

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({
    required this.child,
    this.padding = EdgeInsets.zero,
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
          20,
        ),
        border: Border.all(
          color: const Color(
            0xFFD2E1DA,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  }) : onTap = null;

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 16,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(
                0xFFE5F2EC,
              ),
              borderRadius: BorderRadius.circular(
                13,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: RancoColors.forest,
              size: 21,
            ),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(
                      0xFF718078,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(
                0xFF718078,
              ),
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        20,
      ),
      child: content,
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

class _GuestAccount extends StatelessWidget {
  const _GuestAccount();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(
        22,
      ),
      children: [
        const SizedBox(
          height: 20,
        ),
        const Text(
          'Cuenta',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 20,
        ),
        const Text(
          'Inicia sesión para administrar tu perfil y tus servicios.',
          style: TextStyle(
            color: Color(
              0xFF718078,
            ),
          ),
        ),
        const SizedBox(
          height: 18,
        ),
        FilledButton(
          onPressed: () {
            context.push(
              '/sign-in',
            );
          },
          child: const Text(
            'Ingresar',
          ),
        ),
      ],
    );
  }
}

String _accountStatusLabel(
  Object? status,
) {
  final value = status.toString().split('.').last.toLowerCase();

  switch (value) {
    case 'active':
    case 'activo':
    case 'activa':
      return 'Activa';

    case 'pending':
    case 'pendiente':
      return 'Pendiente';

    case 'suspended':
    case 'suspendido':
    case 'suspendida':
      return 'Suspendida';

    default:
      return value.isEmpty ? 'Sin información' : value;
  }
}

String _publicationLabel(
  String status,
) {
  switch (status.toLowerCase()) {
    case 'draft':
      return 'Borrador';

    case 'pending':
      return 'Pendiente';

    case 'published':
      return 'Publicado';

    case 'rejected':
      return 'Rechazado';

    default:
      return status;
  }
}
