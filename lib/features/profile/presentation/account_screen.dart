import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_states.dart';
import '../../../core/widgets/ranco_error_state.dart';
import '../../../core/widgets/ranco_site_footer.dart';
import '../../../router/session_actions.dart';
import '../../../shared/models/profile.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../../locations/application/location_providers.dart';
import '../../provider_dashboard/application/provider_dashboard_providers.dart';
import '../application/profile_providers.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../shared/models/business.dart';
import '../../provider_dashboard/presentation/provider_hub.dart';

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

              final displayName = rawName.isNotEmpty ? rawName : 'Usuario';

              final initial = displayName
                  .substring(
                    0,
                    1,
                  )
                  .toUpperCase();

              final isVisitor = user.isAnonymous;
              if (isVisitor) {
                final savedLocationId = ref
                    .read(supabaseClientProvider)
                    ?.auth
                    .currentUser
                    ?.userMetadata?['visitor_location_id']
                    ?.toString();
                final locations = ref.watch(locationsProvider).valueOrNull;
                final location = locations
                    ?.where((item) => item.id == savedLocationId)
                    .firstOrNull;
                return _VisitorAccountView(
                  initial: initial,
                  name: displayName,
                  phone: profile.phone,
                  locality: location?.name ??
                      ref.watch(selectedLocationProvider)?.name,
                  onEdit: () => context.push('/visitor/profile?next=/account'),
                  onRequests: () => context.go('/requests'),
                  onSignOut: () async {
                    await signOutAndGoToSignIn(context, ref);
                  },
                );
              }
              final email = user.email ??
                  (isVisitor ? 'Correo opcional' : 'Correo no disponible');

              final isAdmin = profile.role.canAccessAdmin;
              final businessAsync =
                  isAdmin ? null : ref.watch(activeProviderBusinessProvider);
              if (businessAsync != null &&
                  businessAsync.isLoading &&
                  !businessAsync.hasValue) {
                return const _AccountSkeleton();
              }
              if (businessAsync?.hasError == true) {
                return RancoErrorState(
                  message: 'No pudimos cargar tu negocio.',
                  onRetry: () => ref.invalidate(activeProviderBusinessProvider),
                );
              }
              final activeBusiness = businessAsync?.valueOrNull;
              final isProvider = profile.role == ProfileRole.provider ||
                  activeBusiness != null;

              return SafeArea(
                top: false,
                child: RancoFooterScrollView(
                  padding: const EdgeInsets.only(top: 18),
                  children: [
                    RancoContentContainer(
                      width: RancoContainerWidth.form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PageHeader(visitor: isVisitor),
                          const SizedBox(height: 22),
                          _AccountProfile(
                            initial: initial,
                            name: displayName,
                            email: email,
                            role: isVisitor ? 'Visitante' : profile.role.label,
                            // Solo se muestra si la cuenta no está activa.
                            statusWarning: _accountStatusLabel(
                                        profile.accountStatus) ==
                                    'Activa'
                                ? null
                                : _accountStatusLabel(profile.accountStatus),
                            avatarUrl: profile.avatarUrl,
                            onEdit: () {
                              context.push(isVisitor
                                  ? '/visitor/profile?next=/account'
                                  : '/account/edit');
                            },
                          ),
                          if (isProvider) ...[
                            const SizedBox(height: 18),
                            const _SectionLabel(
                              text: 'Negocio',
                            ),
                            const SizedBox(height: 7),
                            ref
                                .watch(
                                  activeProviderBusinessProvider,
                                )
                                .when(
                                  data: (business) {
                                    if (business == null) {
                                      return _MissingBusinessCard(
                                        onTap: () {
                                          context.push(
                                            '/provider/business',
                                          );
                                        },
                                      );
                                    }

                                    return _ProviderBusinessCard(
                                      name: business.name,
                                      published: business.publicationStatus ==
                                          'published',
                                      status: business.publicationStatus,
                                      typeLabel: business.businessType.label,
                                      lodging: business.isLodging,
                                      onManage: () {
                                        context.push(
                                          '/provider/business',
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
                                  error: (_, __) => const _BusinessError(),
                                ),
                          ],
                          if (isAdmin) ...[
                            const SizedBox(height: 18),
                            const _SectionLabel(text: 'Administración'),
                            const SizedBox(height: 7),
                            _AdminPanelCard(onOpen: () => context.go('/admin')),
                          ],
                          if (!isProvider && !isAdmin && !isVisitor) ...[
                            const SizedBox(height: 18),
                            _BecomeProviderCard(
                              onTap: () {
                                context.push(
                                  '/provider/join',
                                );
                              },
                            ),
                          ],
                          // Guardados, Solicitudes, Mensajes y Notificaciones
                          // viven en la navegación principal; Ayuda en el
                          // footer. Cuenta solo concentra perfil y acceso.
                          if (!isVisitor) ...[
                            const SizedBox(height: 20),
                            const _SectionLabel(text: 'Seguridad y acceso'),
                            const SizedBox(height: 7),
                            _SettingsCard(
                              children: [
                                _SettingsRow(
                                  icon: Icons.lock_outline,
                                  title: 'Contraseña y sesión actual',
                                  subtitle:
                                      'Cambia tu contraseña o cierra esta sesión',
                                  onTap: () =>
                                      context.push('/account/security'),
                                ),
                              ],
                            ),
                          ],
                          if (isVisitor) ...[
                            const SizedBox(height: 14),
                            const Card(
                              color: Color(0xFFF1F7F3),
                              child: Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'Tu sesión visitante se conserva en este dispositivo. Si cierras sesión o borras los datos del navegador, perderás acceso a tus solicitudes.',
                                  style: TextStyle(
                                      color: RancoColors.textSecondary),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          _LogoutButton(
                            onPressed: () async {
                              await signOutAndGoToSignIn(context, ref);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () {
              return user.isAnonymous
                  ? const _VisitorAccountSkeleton()
                  : const _AccountSkeleton();
            },
            error: (error, __) {
              return RancoErrorState(
                message: profileFailureMessage(error),
                onRetry: () => ref.invalidate(currentProfileProvider),
              );
            },
          );
        },
        loading: () {
          return const _AccountSkeleton();
        },
        error: (_, __) {
          return RancoErrorState(
            message: 'No pudimos cargar tu sesión.',
            onRetry: () => ref.invalidate(authStateProvider),
          );
        },
      ),
    );
  }
}

class _VisitorAccountSkeleton extends StatelessWidget {
  const _VisitorAccountSkeleton();

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final height in [32.0, 16.0, 166.0, 150.0]) ...[
                  Container(
                    width: double.infinity,
                    height: height,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0EB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class _VisitorAccountView extends StatelessWidget {
  const _VisitorAccountView({
    required this.initial,
    required this.name,
    required this.phone,
    required this.locality,
    required this.onEdit,
    required this.onRequests,
    required this.onSignOut,
  });

  final String initial;
  final String name;
  final String? phone;
  final String? locality;
  final VoidCallback onEdit;
  final VoidCallback onRequests;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: RancoFooterScrollView(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Mi perfil',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: RancoColors.textPrimary,
                                fontWeight: FontWeight.w900,
                              )),
                      const SizedBox(height: 5),
                      const Text(
                          'Tus datos de contacto para los negocios de Ranco.',
                          maxLines: 2,
                          style: TextStyle(
                              color: RancoColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD4E2DC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              CircleAvatar(
                                radius: 27,
                                backgroundColor: const Color(0xFFE4F2EC),
                                child: Text(initial,
                                    style: const TextStyle(
                                        color: RancoColors.forest,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: RancoColors.textPrimary,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800)),
                                    const Text('Visitante',
                                        style: TextStyle(
                                            color: RancoColors.forest,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ]),
                            const SizedBox(height: 17),
                            _VisitorDetail(
                                icon: Icons.phone_outlined,
                                label: 'WhatsApp',
                                value: phone?.trim().isNotEmpty == true
                                    ? phone!.trim()
                                    : 'Sin indicar'),
                            const SizedBox(height: 11),
                            _VisitorDetail(
                                icon: Icons.place_outlined,
                                label: 'Localidad',
                                value: locality ?? 'Sin indicar'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.white,
                        margin: EdgeInsets.zero,
                        child: Column(children: [
                          ListTile(
                            leading: const Icon(Icons.edit_outlined,
                                color: RancoColors.forest),
                            title: const Text('Editar datos',
                                style: TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onEdit,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.assignment_outlined,
                                color: RancoColors.forest),
                            title: const Text('Mis solicitudes',
                                style: TextStyle(fontSize: 14)),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: onRequests,
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.logout_rounded,
                                color: RancoColors.forest),
                            title: const Text('Cerrar sesión',
                                style: TextStyle(fontSize: 14)),
                            onTap: onSignOut,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'La sesión visitante se guarda en este dispositivo. Si cierras sesión o borras sus datos, perderás acceso a tus solicitudes.',
                        maxLines: 3,
                        style: TextStyle(
                            color: RancoColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}

class _VisitorDetail extends StatelessWidget {
  const _VisitorDetail(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 19, color: RancoColors.forest),
        const SizedBox(width: 10),
        SizedBox(
            width: 76,
            child: Text(label,
                style: const TextStyle(
                    color: RancoColors.textSecondary, fontSize: 12))),
        Expanded(
          child: Text(value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: RancoColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({this.visitor = false});

  final bool visitor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visitor ? 'Perfil visitante' : 'Cuenta',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: RancoColors.textPrimary,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                height: 1.1,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          visitor
              ? 'Tus datos permiten que los prestadores respondan a tus solicitudes.'
              : 'Gestiona tu perfil y los accesos de tu cuenta.',
          style: const TextStyle(
            color: RancoColors.textSecondary,
            fontSize: 14.5,
            height: 1.4,
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
    required this.avatarUrl,
    required this.onEdit,
    this.statusWarning,
  });

  final String initial;
  final String name;
  final String email;
  final String role;
  final String? statusWarning;
  final String? avatarUrl;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE0EAE5),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFE4F2EC),
                shape: BoxShape.circle,
              ),
              child: avatarUrl?.isNotEmpty == true
                  ? ClipOval(
                      child: Image.network(
                        avatarUrl!,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(initial),
                      ),
                    )
                  : Text(
                      initial,
                      style: const TextStyle(
                        color: RancoColors.forest,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    // Rol: badge neutro y discreto.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4F2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: Color(0xFF3F5249),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (statusWarning != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF1DC),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Cuenta: $statusWarning',
                          style: const TextStyle(
                            color: Color(0xFF8A5B12),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 17),
              label: const Text('Editar'),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
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
    this.typeLabel,
  });

  final String name;
  final bool published;
  final String status;
  final bool lodging;

  /// Tipo de negocio visible ("Servicio", "Alojamiento"...).
  final String? typeLabel;

  final VoidCallback onManage;
  final VoidCallback onBookings;
  final VoidCallback onCalendar;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final publication = BusinessPublicationStatus.parseOrDefault(status);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0EAE5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RancoColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  lodging
                      ? Icons.holiday_village_outlined
                      : Icons.storefront_outlined,
                  color: RancoColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (typeLabel != null)
                          Text(
                            typeLabel!,
                            style: const TextStyle(
                              color: RancoColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        _BusinessStatus(
                          published: published,
                          status: status,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (published)
                IconButton(
                  tooltip: 'Ver perfil público',
                  onPressed: onView,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  icon: const Icon(
                    Icons.open_in_new_rounded,
                    size: 19,
                    color: RancoColors.forest,
                  ),
                ),
            ],
          ),
          if (!published) ...[
            const SizedBox(height: 12),
            Text(
              _businessHint(publication),
              style: const TextStyle(
                color: RancoColors.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
          if (lodging && published) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.event_available_outlined,
                    label: 'Reservas',
                    onTap: onBookings,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.calendar_month_outlined,
                    label: 'Calendario',
                    onTap: onCalendar,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final button = FilledButton.icon(
                onPressed: onManage,
                icon: const Icon(
                  Icons.dashboard_outlined,
                  size: 18,
                ),
                label: const Text('Gestionar negocio'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
              );
              // Ancho natural en pantallas amplias; completo en móvil.
              if (constraints.maxWidth < 420) {
                return button;
              }
              return Align(alignment: Alignment.centerLeft, child: button);
            },
          ),
        ],
      ),
    );
  }

  static String _businessHint(BusinessPublicationStatus status) {
    return switch (status) {
      BusinessPublicationStatus.draft =>
        'Tu publicación aún no está visible. Continúa la configuración.',
      BusinessPublicationStatus.pendingReview =>
        'Estamos revisando tu publicación.',
      BusinessPublicationStatus.changesRequested =>
        'Revisa la observación del equipo y corrige la publicación.',
      BusinessPublicationStatus.rejected =>
        'Revisa el motivo indicado por administración.',
      BusinessPublicationStatus.suspended =>
        'El negocio no está visible mientras se resuelve la suspensión.',
      _ => 'El negocio no aparece públicamente en este momento.',
    };
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
    final publication = published
        ? BusinessPublicationStatus.published
        : BusinessPublicationStatus.parseOrDefault(status);
    return RancoStatusBadge(
      // Etiquetas canónicas: Borrador, En revisión, Publicado, Cambios
      // solicitados, Rechazado...
      label: publication.label,
      tone: providerPublicationTone(publication),
      dot: true,
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
            mainAxisAlignment: MainAxisAlignment.center,
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
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: RancoColors.forest,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0EAE5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: RancoColors.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.add_business_outlined,
                  size: 22,
                  color: RancoColors.primaryDark,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Configura tu negocio',
                      style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Aún no hay un negocio asociado a tu acceso.',
                      style: TextStyle(
                        color: RancoColors.textSecondary,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Comenzar configuración'),
            style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Tienes un negocio?',
                      style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Publícalo gratis en Ranco Conecta.',
                      style: TextStyle(
                        color: RancoColors.textSecondary,
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
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        text,
        style: const TextStyle(
          color: RancoColors.textSecondary,
          fontSize: 12.5,
          letterSpacing: .2,
          fontWeight: FontWeight.w800,
        ),
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
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE0EAE5),
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
        horizontal: 16,
        vertical: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F2ED),
              borderRadius: BorderRadius.circular(10),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: RancoColors.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: RancoColors.textSecondary,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(
              Icons.chevron_right_rounded,
              size: 19,
              color: RancoColors.textSecondary,
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

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onPressed,
          icon: const Icon(
            Icons.logout_rounded,
            size: 18,
          ),
          label: const Text(
            'Cerrar sesión',
          ),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF8F2D3A),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
        ),
      ],
    );
  }
}

class _BusinessLoading extends StatelessWidget {
  const _BusinessLoading();

  @override
  Widget build(BuildContext context) {
    return const _BusinessCardSkeleton();
  }
}

class _BusinessCardSkeleton extends StatelessWidget {
  const _BusinessCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const RancoSkeletonCard(
      children: [
        Row(
          children: [
            RancoSkeletonBox(width: 46, height: 46, radius: 13),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RancoSkeletonBox(width: 180, height: 14),
                  SizedBox(height: 10),
                  RancoSkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        RancoSkeletonBox(width: 180, height: 44, radius: 12),
      ],
    );
  }
}

/// Carga de Cuenta con la forma real: encabezado, tarjeta de perfil y
/// tarjeta de negocio (sin spinner centrado).
class _AccountSkeleton extends StatelessWidget {
  const _AccountSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando',
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 18),
        children: const [
          RancoContentContainer(
            width: RancoContainerWidth.form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RancoSkeletonBox(width: 140, height: 26),
                SizedBox(height: 10),
                RancoSkeletonBox(width: 260, height: 14),
                SizedBox(height: 22),
                RancoSkeletonCard(
                  padding: EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        RancoSkeletonBox(width: 60, height: 60, radius: 30),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RancoSkeletonBox(width: 180, height: 16),
                              SizedBox(height: 8),
                              RancoSkeletonBox(width: 200, height: 12),
                              SizedBox(height: 10),
                              RancoSkeletonBox(width: 80, height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 18),
                RancoSkeletonBox(width: 70, height: 12),
                SizedBox(height: 9),
                _BusinessCardSkeleton(),
              ],
            ),
          ),
        ],
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
      child: RancoFooterScrollView(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 520,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  24,
                  30,
                  24,
                  24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cuenta',
                      style: TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Gestiona tu perfil y tus preferencias.',
                      style: TextStyle(
                        color: RancoColors.textSecondary,
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
                              borderRadius: BorderRadius.circular(
                                16,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              size: 25,
                              color: RancoColors.forest,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Inicia sesión en tu cuenta',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: RancoColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 7),
                          const Text(
                            'Accede a tus guardados, solicitudes y opciones de negocio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: RancoColors.textSecondary,
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
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(
                                  46,
                                ),
                                backgroundColor: RancoColors.forest,
                                foregroundColor: Colors.white,
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
        ],
      ),
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

class _AdminPanelCard extends StatelessWidget {
  const _AdminPanelCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE6F3EC), Color(0xFFF4FAF6)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final button = FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text('Abrir panel'),
        );
        final info = Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.admin_panel_settings_outlined,
                color: RancoColors.forest,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Panel administrativo',
                    style: TextStyle(
                      color: RancoColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Gestiona negocios, usuarios, revisiones y configuración '
                    'de Ranco Conecta.',
                    style: TextStyle(
                      color: RancoColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        // Angosto: el botón baja bajo el texto en vez de comprimirlo.
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [info, const SizedBox(height: 14), button],
          );
        }
        return Row(children: [
          Expanded(child: info),
          const SizedBox(width: 12),
          button,
        ]);
      }),
    );
  }
}
