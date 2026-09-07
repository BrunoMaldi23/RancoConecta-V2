import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_error_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/supabase_auth_repository.dart';
import '../application/profile_providers.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    return auth.when(
      data: (user) {
        if (user == null) {
          return const _GuestAccount();
        }

        final profile = ref.watch(currentProfileProvider);
        return profile.when(
          data: (profile) => ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
            children: [
              Text('Cuenta', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 18),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    child: Text(
                      (profile.fullName ?? user.email ?? 'R')
                          .characters
                          .first
                          .toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName ?? 'Sin nombre',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email ?? 'Sin email',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          profile.role.label,
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Editar perfil',
                    onPressed: () => context.go('/account/edit'),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _AccountSection(
                children: [
                  _AccountTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Mi perfil',
                    subtitle: profile.phone?.isNotEmpty == true
                        ? profile.phone!
                        : 'Completa tus datos personales',
                    onTap: () => context.go('/account/edit'),
                  ),
                  _AccountTile(
                    icon: Icons.assignment_outlined,
                    title: 'Mis solicitudes',
                    onTap: () => context.go('/requests'),
                  ),
                  _AccountTile(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Mis guardados',
                    onTap: () => context.go('/saved'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ProviderCard(
                onPressed: () => context.go('/explore'),
              ),
              const SizedBox(height: 16),
              _AccountSection(
                children: [
                  _AccountTile(
                    icon: Icons.verified_user_outlined,
                    title: 'Estado de la cuenta',
                    subtitle: _statusLabel(profile.accountStatus),
                  ),
                  const _AccountTile(
                    icon: Icons.help_outline_rounded,
                    title: 'Ayuda y soporte',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(currentProfileProvider);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Cerrar sesión'),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => RancoErrorState(
            message: profileFailureMessage(error),
            onRetry: () => ref.invalidate(currentProfileProvider),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => const RancoErrorState(
        message: 'No pudimos leer la sesión.',
      ),
    );
  }

  static String _statusLabel(String status) {
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

class _GuestAccount extends StatelessWidget {
  const _GuestAccount();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
      children: [
        Text('Tu cuenta', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Accede a todas las funciones de Ranco Conecta.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: const Column(
            children: [
              _Benefit(icon: Icons.bookmark_border_rounded, text: 'Guardar prestadores y negocios'),
              _Benefit(icon: Icons.assignment_outlined, text: 'Solicitar y revisar servicios'),
              _Benefit(icon: Icons.star_border_rounded, text: 'Calificar tus experiencias'),
              _Benefit(icon: Icons.storefront_outlined, text: 'Preparar tu perfil como prestador'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.go('/sign-in'),
          icon: const Icon(Icons.login_rounded),
          label: const Text('Ingresar'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => context.go('/sign-up'),
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Crear cuenta'),
        ),
      ],
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const Divider(indent: 52),
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
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: .58),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.storefront_outlined, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¿Quieres ofrecer servicios?',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'La administración del perfil de prestador se habilitará en el siguiente sprint.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onPressed,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: const Text('Conocer la plataforma'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
