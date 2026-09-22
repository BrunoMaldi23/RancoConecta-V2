import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../theme/ranco_colors.dart';
import '../../../theme/ranco_decoration.dart';
import '../../../shared/models/profile.dart';
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

    return Container(
      decoration: const BoxDecoration(
        gradient: RancoDecoration.pageGlow,
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

              final isProvider = profile.role == ProfileRole.provider;

              return SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: [
                    const Text(
                      'Cuenta',
                      style: TextStyle(
                        color: Color(
                          0xFF22332B,
                        ),
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                      const SizedBox(height: 20),
                      const _SectionTitle(
                        title: 'Mi negocio',
                      ),
                      const SizedBox(height: 7),
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
                      const SizedBox(height: 20),
                      _BecomeProviderCard(
                        onTap: () {
                          context.push(
                            '/provider/join',
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 20),
                    const _SectionTitle(
                      title: 'Cuenta y soporte',
                    ),
                    const SizedBox(height: 7),
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
                      height: 44,
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
      padding: const EdgeInsets.all(14),
      decoration: RancoDecoration.card(radius: 20),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  RancoColors.primarySoft,
                  Color(0xFFD8EFE4),
                ],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: RancoColors.forest.withValues(alpha: .15),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Color(
                  0xFF174A35,
                ),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(
            width: 12,
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
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(
                  height: 2,
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
                  height: 5,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
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
                      color: RancoColors.pine,
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
            visualDensity: VisualDensity.compact,
            icon: const Icon(
              Icons.edit_outlined,
              size: 20,
              color: RancoColors.primaryDark,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            RancoColors.primarySoft,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RancoDecoration.strongBorder),
        boxShadow: RancoDecoration.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    14,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  lodging
                      ? Icons.holiday_village_outlined
                      : Icons.storefront_outlined,
                  color: RancoColors.pine,
                  size: 23,
                ),
              ),
              const SizedBox(
                width: 11,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: published
                                ? RancoColors.success
                                : RancoColors.warning,
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
            height: 12,
          ),
          const Text(
            'Gestión rápida',
            style: TextStyle(
              color: Color(
                0xFF6D8178,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(
            height: 7,
          ),
          if (lodging) ...[
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
                  width: 8,
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
              height: 10,
            ),
          ],
          SizedBox(
            height: 44,
            child: FilledButton.icon(
              onPressed: onManage,
              icon: const Icon(
                Icons.dashboard_outlined,
              ),
              label: Text(
                lodging ? 'Administrar alojamiento' : 'Administrar negocio',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: RancoColors.pine,
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
            height: 2,
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
              foregroundColor: RancoColors.pine,
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
            horizontal: 9,
            vertical: 9,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: RancoColors.forest,
                size: 18,
              ),
              const SizedBox(
                width: 6,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: RancoColors.primarySoft,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(color: RancoDecoration.softBorder),
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
          const SizedBox(height: 4),
          const Text(
            'Tu cuenta de prestador está activa, pero aún falta asociar o completar tu negocio.',
            style: TextStyle(
              color: RancoColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
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
        color: const Color(0xFFFFEDEC),
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(color: const Color(0xFFF2C7C2)),
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
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: RancoDecoration.softGreenGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: RancoDecoration.softBorder),
            boxShadow: RancoDecoration.softShadow,
          ),
          child: const Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: RancoColors.primaryDark,
                size: 24,
              ),
              SizedBox(
                width: 10,
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
                color: RancoColors.pine,
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
      decoration: RancoDecoration.card(radius: 20),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: RancoColors.primarySoft,
              borderRadius: BorderRadius.circular(
                13,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: RancoColors.primaryDark,
              size: 19,
            ),
          ),
          const SizedBox(
            width: 11,
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
        letterSpacing: 0,
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
    case 'pending_review':
      return 'Pendiente';

    case 'changes_requested':
      return 'Cambios solicitados';

    case 'suspended':
      return 'Suspendido';

    case 'published':
      return 'Publicado';

    case 'rejected':
      return 'Rechazado';

    default:
      return status;
  }
}
