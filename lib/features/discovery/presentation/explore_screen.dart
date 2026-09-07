import 'package:flutter/material.dart';

import '../../../core/widgets/ranco_empty_state.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RancoEmptyState(
      icon: Icons.travel_explore,
      title: 'Explora el territorio',
      message:
          'Pronto podrás comparar negocios, servicios y experiencias por localidad.',
    );
  }
}
