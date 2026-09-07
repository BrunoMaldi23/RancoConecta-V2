import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../config/app_config.dart';
import '../../../core/widgets/ranco_app_bar.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const RancoAppBar(title: 'Cuenta'),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ingresa a Ranco Conecta', style: textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                  config.hasSupabaseConfig
                      ? 'La estructura de autenticación está lista para conectar los formularios reales.'
                      : 'Backend no configurado. Define SUPABASE_URL y SUPABASE_ANON_KEY para habilitar autenticación.',
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Acceso seguro próximamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
