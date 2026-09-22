import 'package:flutter/material.dart';

class RancoEmptyState extends StatelessWidget {
  const RancoEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondaryAction,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondaryAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 40 : 48,
                height: compact ? 40 : 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: compact ? 21 : 24,
                  color: colorScheme.primary,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                title,
                style: textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                SizedBox(height: compact ? 10 : 14),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.search_rounded),
                  label: Text(actionLabel!),
                ),
              ],
              if (secondaryLabel != null && onSecondaryAction != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onSecondaryAction,
                  child: Text(secondaryLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
