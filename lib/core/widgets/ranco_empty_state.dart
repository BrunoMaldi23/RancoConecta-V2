import 'package:flutter/material.dart';

class RancoEmptyState extends StatelessWidget {
  const RancoEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 42, color: colorScheme.primary),
              const SizedBox(height: 16),
              Text(title,
                  style: textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
