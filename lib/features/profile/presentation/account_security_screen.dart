import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/layout/ranco_responsive.dart';
import '../../../core/widgets/ranco_status_badge.dart';
import '../../../router/session_actions.dart';
import '../../../theme/ranco_colors.dart';
import '../../auth/data/supabase_auth_repository.dart';

class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);
    final session = client?.auth.currentSession;
    final expiry = session?.expiresAt;
    final expiryText = expiry == null
        ? null
        : _shortDate(
            DateTime.fromMillisecondsSinceEpoch(expiry * 1000).toLocal());

    return Scaffold(
      backgroundColor: RancoColors.canvas,
      appBar: AppBar(
        backgroundColor: RancoColors.canvas,
        title: const Text('Seguridad y acceso'),
        leading: BackButton(onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/account');
          }
        }),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            RancoContentContainer(
              width: RancoContainerWidth.narrow,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Gestiona tu contraseña y la sesión de este dispositivo.',
                    style: TextStyle(
                        color: RancoColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  _SecurityCard(
                    title: 'Cambiar contraseña',
                    icon: Icons.lock_outline,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _currentPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña actual',
                            helperText:
                                'Solo si tu cuenta ya tiene contraseña.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _newPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Nueva contraseña',
                            helperText: 'Mínimo 8 caracteres.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirmPassword,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(color: RancoColors.error)),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          children: [
                            FilledButton(
                              onPressed: _saving || session == null
                                  ? null
                                  : _changePassword,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 46),
                              ),
                              child: Text(_saving
                                  ? 'Guardando...'
                                  : 'Guardar nueva contraseña'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Solo la sesión de este dispositivo: el backend no ofrece
                  // gestión multisesión.
                  _SecurityCard(
                    title: 'Sesión actual',
                    icon: Icons.phonelink_lock_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SessionRow(
                          label: 'Cuenta',
                          value: session?.user.email ?? 'Sin sesión',
                        ),
                        _SessionRow(
                          label: 'Estado',
                          value: session == null ? 'Sin sesión' : 'Activa',
                          badge: session == null
                              ? RancoStatusTone.muted
                              : RancoStatusTone.success,
                        ),
                        if (expiryText != null)
                          _SessionRow(
                            label: 'Expira',
                            value: '$expiryText (se renueva sola)',
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Acción de salida separada: diferenciada sin alarmismo
                  // (rojo suave, no relleno).
                  _SecurityCard(
                    title: 'Cerrar sesión',
                    icon: Icons.logout_rounded,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      runSpacing: 12,
                      children: [
                        const Text(
                          'Saldrás de tu cuenta en este dispositivo.',
                          style: TextStyle(
                            color: RancoColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: session == null
                              ? null
                              : () => signOutAndGoToSignIn(context, ref),
                          icon: const Icon(Icons.logout_outlined, size: 18),
                          label: const Text('Cerrar esta sesión'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF8F2D3A),
                            side: const BorderSide(color: Color(0xFFE8C9D0)),
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ],
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

  Future<void> _changePassword() async {
    final password = _newPassword.text;
    if (password.length < 8) {
      setState(() => _error = 'Usa al menos 8 caracteres.');
      return;
    }
    if (password != _confirmPassword.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await client.auth.updateUser(UserAttributes(
        password: password,
        currentPassword:
            _currentPassword.text.isEmpty ? null : _currentPassword.text,
      ));
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contraseña actualizada.')),
        );
      }
    } catch (error) {
      if (mounted) {
        // Mensaje claro sin exponer detalles técnicos.
        final text = '$error'.toLowerCase();
        setState(() => _error =
            text.contains('password') && text.contains('current')
                ? 'La contraseña actual no es correcta.'
                : 'No pudimos cambiar la contraseña. Intenta nuevamente.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard(
      {required this.title, required this.icon, required this.child});

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0EAE5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: RancoColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: RancoColors.primaryDark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: RancoColors.textPrimary,
                      fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.label, required this.value, this.badge});

  final String label;
  final String value;
  final RancoStatusTone? badge;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: RancoColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: badge != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child:
                        RancoStatusBadge(label: value, tone: badge!, dot: true),
                  )
                : Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: RancoColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
