import 'package:flutter/material.dart';

import '../../../core/widgets/ranco_empty_state.dart';

class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RancoEmptyState(
      icon: Icons.assignment_outlined,
      title: 'Solicitudes',
      message:
          'La base del dominio ya está modelada para cotizaciones y seguimiento.',
    );
  }
}
