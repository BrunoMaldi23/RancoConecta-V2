import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/ranco_empty_state.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: RancoEmptyState(
            icon: Icons.person_outline,
            title: 'Cuenta',
            message:
                'Perfil, membresías y seguridad se conectarán sobre Supabase Auth.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton.icon(
            onPressed: () => context.go('/sign-in'),
            icon: const Icon(Icons.login),
            label: const Text('Ingresar'),
          ),
        ),
      ],
    );
  }
}
