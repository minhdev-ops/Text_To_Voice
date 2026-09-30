import 'package:flutter/material.dart';

/// The product's one way of saying "there is nothing here yet".
///
/// DESIGN.md: Literata headline, one plain body line, at most one primary and
/// one secondary action. Left-aligned and measure-constrained rather than
/// centered, so it sits in the same editorial column the reader uses and every
/// empty screen reads as the same product.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.primaryAction,
    this.secondaryAction,
  });

  final String title;
  final String message;
  final Widget? primaryAction;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.headlineLarge),
              const SizedBox(height: 12),
              Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              if (primaryAction != null || secondaryAction != null) ...[
                const SizedBox(height: 32),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [?primaryAction, ?secondaryAction],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
