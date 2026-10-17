import 'package:flutter/material.dart';
import 'package:stylist/theme/tokens.dart';

/// Small all-caps label above a headline ("AGE CHECK"). Decorative context, so keep the text short.
class Eyebrow extends StatelessWidget {
  const Eyebrow(
    this.text, {
    this.color,
    this.align = TextAlign.start,
    super.key,
  });
  final String text;
  final Color? color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    textAlign: align,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color ?? Theme.of(context).colorScheme.primary,
    ),
  );
}

/// A quiet rounded panel with an icon and a line of explanation (privacy notes, hints, tips).
class NoteCard extends StatelessWidget {
  const NoteCard({
    required this.icon,
    required this.child,
    this.title,
    super.key,
  });
  final IconData icon;
  final Widget child;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, color: scheme.primary)),
          const SizedBox(width: Spacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Eyebrow(title!),
                  const SizedBox(height: Spacing.xs),
                ],
                DefaultTextStyle.merge(
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  child: child,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A round icon badge with an optional small pill under it ("16+").
class BadgeIcon extends StatelessWidget {
  const BadgeIcon({required this.icon, this.pill, super.key});
  final IconData icon;
  final String? pill;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 72,
          height: 72,
          margin: EdgeInsets.only(bottom: pill == null ? 0 : Spacing.sm),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.outlineVariant, width: 2),
          ),
          child: ExcludeSemantics(
            child: Icon(icon, size: 36, color: scheme.primary),
          ),
        ),
        if (pill != null)
          Positioned(
            bottom: -4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(RadiusTokens.pill),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm + 2,
                  vertical: 2,
                ),
                child: Text(
                  pill!,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
