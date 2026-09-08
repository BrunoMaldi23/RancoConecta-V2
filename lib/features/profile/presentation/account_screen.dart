import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
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
        0xFFF5F8F6,
      ),
      child: auth.when(
        data: (user) {
          if (user == null) {
            return const _GuestAccount();
          }

          final profile = ref.watch(
            currentProfileProvider,
          );

          return profile.when(
            data: (profile) {
              final isProvider =
                  profile.role.label.toLowerCase() == 'prestador';

              return ListView(
                padding: const EdgeInsets.fromLTRB(
                  18,
                  20,
                  18,
                  30,
                ),
                children: [
                  const Text(
                    'Cuenta',
                    style: TextStyle(
                      color: Color(
                        0xFF202C26,
                      ),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: const Color(
                          0xFFA7F3CF,
                        ),
                        child: Text(
                          (profile.fullName ?? 'R')
                              .characters
                              .first
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Color(
                              0xFF123D2B,
                            ),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
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
                              profile.fullName ?? 'Sin nombre',
                              style: const TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              user.email ?? '',
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
                            Text(
                              profile.role.label,
                              style: const TextStyle(
                                color: RancoColors.forest,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Editar perfil',
                        onPressed: () {
                          context.go(
                            '/account/edit',
                          );
                        },
                        icon: const Icon(
                          Icons.edit_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 22,
                  ),
                  const _SectionTitle(
                    title: 'MI CUENTA',
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _AccountSection(
                    children: [
                      _AccountTile(
                        icon: Icons.person_outline_rounded,
                        title: 'Mi perfil',
                        subtitle: profile.phone?.isNotEmpty == true
                            ? profile.phone!
                            : 'Completa tus datos personales',
                        onTap: () {
                          context.go(
                            '/account/edit',
                          );
                        },
                      ),
                      _AccountTile(
                        icon: Icons.assignment_outlined,
                        title: 'Mis solicitudes',
                        subtitle: 'Revisa tus solicitudes enviadas',
                        onTap: () {
                          context.go(
                            '/requests',
                          );
                        },
                      ),
                      _AccountTile(
                        icon: Icons.bookmark_border_rounded,
                        title: 'Mis guardados',
                        subtitle: 'Prestadores y negocios favoritos',
                        onTap: () {
                          context.go(
                            '/saved',
                          );
                        },
                      ),
                    ],
                  ),
                  if (isProvider) ...[
                    const SizedBox(
                      height: 22,
                    ),
                    const _SectionTitle(
                      title: 'MI NEGOCIO',
                    ),
                    const SizedBox(
                      height: 8,
                    ),
                    ref
                        .watch(
                          myProviderBusinessProvider,
                        )
                        .when(
                          data: (business) {
                            if (business == null) {
                              return Container(
                                padding: const EdgeInsets.all(
                                  16,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFFF4E4,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    18,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Cuenta de prestador activa',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    const Text(
                                      'Todavia no encontramos un negocio asociado a esta cuenta.',
                                    ),
                                    const SizedBox(
                                      height: 12,
                                    ),
                                    FilledButton(
                                      onPressed: () {
                                        context.go(
                                          '/provider/register',
                                        );
                                      },
                                      child: const Text(
                                        'Completar publicacion',
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return Container(
                              padding: const EdgeInsets.all(
                                16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFE4F3EC,
                                ),
                                borderRadius: BorderRadius.circular(
                                  18,
                                ),
                                border: Border.all(
                                  color: const Color(
                                    0xFFC9DFD4,
                                  ),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        child: Icon(
                                          business.isLodging
                                              ? Icons.holiday_village_outlined
                                              : Icons.storefront_outlined,
                                          color: RancoColors.forest,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 12,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              business.name,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 4,
                                            ),
                                            Row(
                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Color(
                                                      0xFF28865B,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(
                                                  width: 5,
                                                ),
                                                Text(
                                                  business.publicationStatus ==
                                                          'published'
                                                      ? 'Publicado'
                                                      : business
                                                          .publicationStatus,
                                                  style: const TextStyle(
                                                    color: Color(
                                                      0xFF39715A,
                                                    ),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
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
                                    height: 14,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        context.go(
                                          '/provider/dashboard',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.dashboard_outlined,
                                      ),
                                      label: Text(
                                        business.isLodging
                                            ? 'Administrar alojamiento'
                                            : 'Administrar negocio',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: RancoColors.forest,
                                        minimumSize: const Size.fromHeight(
                                          48,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 5,
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: TextButton.icon(
                                      onPressed: () {
                                        context.go(
                                          '/business/${business.id}',
                                        );
                                      },
                                      icon: const Icon(
                                        Icons.visibility_outlined,
                                      ),
                                      label: const Text(
                                        'Ver publicacion',
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
                              Container(
                            padding: const EdgeInsets.all(
                              16,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFFECE8,
                              ),
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                            child: const Text(
                              'No pudimos cargar tu negocio.',
                            ),
                          ),
                        ),
                  ],
                  if (!isProvider) ...[
                    const SizedBox(
                      height: 18,
                    ),
                    Container(
                      padding: const EdgeInsets.all(
                        16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFDDF7E9,
                        ),
                        borderRadius: BorderRadius.circular(
                          18,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.storefront_outlined,
                            color: RancoColors.forest,
                          ),
                          const SizedBox(
                            width: 12,
                          ),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quieres ofrecer servicios?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  'Publica tu negocio en Ranco Conecta.',
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              context.go(
                                '/provider/join',
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_forward_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(
                    height: 22,
                  ),
                  const _SectionTitle(
                    title: 'CUENTA Y SOPORTE',
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _AccountSection(
                    children: [
                      _AccountTile(
                        icon: Icons.verified_user_outlined,
                        title: 'Estado de la cuenta',
                        subtitle: _statusLabel(
                          profile.accountStatus,
                        ),
                      ),
                      const _AccountTile(
                        icon: Icons.help_outline_rounded,
                        title: 'Ayuda y soporte',
                        subtitle: 'Preguntas frecuentes y contacto',
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 18,
                  ),
                  OutlinedButton.icon(
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
                      'Cerrar sesion',
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (
              error,
              stackTrace,
            ) =>
                RancoErrorState(
              message: profileFailureMessage(
                error,
              ),
              onRetry: () {
                ref.invalidate(
                  currentProfileProvider,
                );
              },
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
            const RancoErrorState(
          message: 'No pudimos leer la sesion.',
        ),
      ),
    );
  }

  static String _statusLabel(
    String status,
  ) {
    return switch (status) {
      'active' => 'Activa',
      'pending' => 'Pendiente',
      'suspended' => 'Suspendida',
      'blocked' => 'Bloqueada',
      'deleted' => 'Eliminada',
      _ => status,
    };
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
  });

  final String title;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(
          0xFF718078,
        ),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .8,
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          17,
        ),
        border: Border.all(
          color: const Color(
            0xFFD5E2DC,
          ),
        ),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(
                height: 1,
                indent: 52,
              ),
          ],
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 3,
      ),
      leading: Icon(
        icon,
        color: RancoColors.forest,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 12,
              ),
            ),
      trailing: onTap == null
          ? null
          : const Icon(
              Icons.chevron_right_rounded,
            ),
      onTap: onTap,
    );
  }
}

class _GuestAccount extends StatelessWidget {
  const _GuestAccount();

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListView(
      padding: const EdgeInsets.all(
        24,
      ),
      children: [
        const Text(
          'Tu cuenta',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(
          height: 18,
        ),
        FilledButton(
          onPressed: () {
            context.go(
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
