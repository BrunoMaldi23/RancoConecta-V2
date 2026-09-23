import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/profile.dart';
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
    final auth = ref.watch(authStateProvider);

    return ColoredBox(
      color: RancoColors.canvas,
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

              final displayName =
                  rawName.isNotEmpty ? rawName : 'Usuario';

              final initial = displayName
                  .substring(
                    0,
                    1,
                  )
                  .toUpperCase();

              final email =
                  user.email ?? 'Correo no disponible';

              final isProvider =
                  profile.role == ProfileRole.provider;

              return SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 720,
                    ),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        18,
                        18,
                        18,
                        30,
                      ),
                      children: [
                        const _PageHeader(),

                        const SizedBox(height: 14),

                        _AccountProfile(
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
                          const SizedBox(height: 18),

                          const _SectionLabel(
                            text: 'Mi negocio',
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

                                  return _ProviderBusinessCard(
                                    name: business.name,
                                    published:
                                        business.publicationStatus ==
                                            'published',
                                    status:
                                        business.publicationStatus,
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
                                loading: () =>
                                    const _BusinessLoading(),
                                error: (_, __) =>
                                    const _BusinessError(),
                              ),
                        ],

                        if (!isProvider) ...[
                          const SizedBox(height: 18),

                          _BecomeProviderCard(
                            onTap: () {
                              context.push(
                                '/provider/join',
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 20),

                        const _SectionLabel(
                          text: 'Cuenta y soporte',
                        ),

                        const SizedBox(height: 7),

                        _SettingsCard(
                          children: [
                            _SettingsRow(
                              icon:
                                  Icons.verified_user_outlined,
                              title:
                                  'Estado de la cuenta',
                              subtitle:
                                  _accountStatusLabel(
                                profile.accountStatus,
                              ),
                            ),

                            const _SettingsDivider(),

                            _SettingsRow(
                              icon:
                                  Icons.help_outline_rounded,
                              title:
                                  'Ayuda y soporte',
                              subtitle:
                                  'Preguntas frecuentes y contacto',
                              onTap: () {
                                // Ruta futura de ayuda.
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        _LogoutButton(
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
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
            loading: () {
              return const Center(
                child: CircularProgressIndicator(),
              );
            },
            error: (_, __) {
              return const Center(
                child: Text(
                  'No pudimos cargar tu perfil.',
                ),
              );
            },
          );
        },
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (_, __) {
          return const Center(
            child: Text(
              'No pudimos cargar tu sesión.',
            ),
          );
        },
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cuenta',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                color: RancoColors.textPrimary,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                height: 1,
              ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Gestiona tu perfil y los accesos de tu cuenta.',
          style: TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _AccountProfile extends StatelessWidget {
  const _AccountProfile({
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4E2DC),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE4F2EC),
                shape: BoxShape.circle,
              ),
              child: Text(
                initial,
                style: const TextStyle(
                  color: RancoColors.forest,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
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
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color:
                          RancoColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFE1F4EA),
                      borderRadius:
                          BorderRadius.circular(20),
                    ),
                    child: Text(
                      role,
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            IconButton(
              tooltip: 'Editar perfil',
              onPressed: onEdit,
              visualDensity:
                  VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
                color: RancoColors.forest,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderBusinessCard extends StatelessWidget {
  const _ProviderBusinessCard({
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: const Color(0xFFC7DDD3),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5F1EC),
                  borderRadius:
                      BorderRadius.circular(11),
                ),
                child: Icon(
                  lodging
                      ? Icons.holiday_village_outlined
                      : Icons.storefront_outlined,
                  color: RancoColors.forest,
                  size: 20,
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color:
                            RancoColors.textPrimary,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 3),

                    _BusinessStatus(
                      published: published,
                      status: status,
                    ),
                  ],
                ),
              ),

              IconButton(
                tooltip: 'Ver publicación',
                onPressed: onView,
                visualDensity:
                    VisualDensity.compact,
                icon: const Icon(
                  Icons.visibility_outlined,
                  size: 19,
                  color: RancoColors.forest,
                ),
              ),
            ],
          ),

          if (lodging) ...[
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon:
                        Icons.event_available_outlined,
                    label: 'Reservas',
                    onTap: onBookings,
                  ),
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: _QuickAction(
                    icon:
                        Icons.calendar_month_outlined,
                    label: 'Calendario',
                    onTap: onCalendar,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 10),

          FilledButton.icon(
            onPressed: onManage,
            icon: const Icon(
              Icons.dashboard_outlined,
              size: 18,
            ),
            label: Text(
              lodging
                  ? 'Gestionar alojamiento'
                  : 'Gestionar negocio',
            ),
            style: FilledButton.styleFrom(
              minimumSize:
                  const Size.fromHeight(43),
              backgroundColor:
                  RancoColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessStatus extends StatelessWidget {
  const _BusinessStatus({
    required this.published,
    required this.status,
  });

  final bool published;
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = published
        ? const Color(0xFF2E8B62)
        : const Color(0xFF9A721E);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 5),

        Text(
          published
              ? 'Publicado'
              : _publicationLabel(status),
          style: TextStyle(
            color: color,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(
            minHeight: 40,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: const Color(0xFFD6E4DE),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: RancoColors.forest,
              ),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.forest,
                    fontSize: 11.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
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
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FBF9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4E2DC),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE5F1EC),
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.storefront_outlined,
              size: 20,
              color: RancoColors.forest,
            ),
          ),

          const SizedBox(width: 10),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Completa tu publicación',
                  style: TextStyle(
                    color:
                        RancoColors.textPrimary,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Aún falta completar o asociar tu negocio.',
                  style: TextStyle(
                    color:
                        RancoColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: onTap,
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: RancoColors.forest,
            ),
          ),
        ],
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
      color: const Color(0xFFF1F8F5),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD0E2DA),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.storefront_outlined,
                color: RancoColors.forest,
                size: 21,
              ),

              SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Tienes un negocio?',
                      style: TextStyle(
                        color:
                            RancoColors.textPrimary,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Publícalo gratis en Ranco Conecta.',
                      style: TextStyle(
                        color:
                            RancoColors.textSecondary,
                        fontSize: 12,
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: RancoColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFD4E2DC),
          ),
        ),
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2ED),
              borderRadius:
                  BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: RancoColors.forest,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color:
                        RancoColors.textPrimary,
                    fontSize: 13.5,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  subtitle,
                  style: const TextStyle(
                    color:
                        RancoColors.textSecondary,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),

          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color:
                  RancoColors.textSecondary,
            ),
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: content,
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 56,
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 43,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(
          Icons.logout_rounded,
          size: 18,
        ),
        label: const Text(
          'Cerrar sesión',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor:
              RancoColors.forest,
          side: const BorderSide(
            color: Color(0xFFA8BBB2),
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _BusinessLoading extends StatelessWidget {
  const _BusinessLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 130,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFF1D0CC),
        ),
      ),
      child: const Text(
        'No pudimos cargar tu negocio.',
        style: TextStyle(
          color: RancoColors.textPrimary,
        ),
      ),
    );
  }
}

class _GuestAccount extends StatelessWidget {
  const _GuestAccount();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 520,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              24,
              30,
              24,
              90,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.start,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cuenta',
                  style: TextStyle(
                    color:
                        RancoColors.textPrimary,
                    fontSize: 28,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 5),

                const Text(
                  'Gestiona tu perfil y tus preferencias.',
                  style: TextStyle(
                    color:
                        RancoColors.textSecondary,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 42),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFDDF3E8,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          size: 25,
                          color:
                              RancoColors.forest,
                        ),
                      ),

                      const SizedBox(height: 16),

                      const Text(
                        'Inicia sesión en tu cuenta',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors
                              .textPrimary,
                          fontSize: 19,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 7),

                      const Text(
                        'Accede a tus guardados, solicitudes y opciones de negocio.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: RancoColors
                              .textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 20),

                      SizedBox(
                        width: 210,
                        child: FilledButton.icon(
                          onPressed: () {
                            context.push(
                              '/sign-in',
                            );
                          },
                          icon: const Icon(
                            Icons.login_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Iniciar sesión',
                          ),
                          style:
                              FilledButton.styleFrom(
                            minimumSize:
                                const Size.fromHeight(
                              46,
                            ),
                            backgroundColor:
                                RancoColors.forest,
                            foregroundColor:
                                Colors.white,
                          ),
                        ),
                      ),
                    ],
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

String _accountStatusLabel(
  Object? status,
) {
  final value = status
      .toString()
      .split('.')
      .last
      .toLowerCase();

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
      return value.isEmpty
          ? 'Sin información'
          : value;
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