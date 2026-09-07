import 'package:flutter/material.dart';

import '../../../core/widgets/ranco_empty_state.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RancoEmptyState(
      icon: Icons.bookmark_border,
      title: 'Guardados',
      message: 'Tus favoritos vivirán aquí cuando el backend esté conectado.',
    );
  }
}
