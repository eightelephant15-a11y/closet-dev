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

/// A rounded card holding a stack of [SettingsTile]s separated by hairlines.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(RadiusTokens.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: scheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One tappable row: a tinted icon square, a title, an optional subtitle and a trailing chevron.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.destructive = false,
    this.showChevron = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final color = destructive ? scheme.error : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: Spacing.minTouchTarget + 16,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.md,
            vertical: Spacing.sm + 2,
          ),
          child: Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: destructive
                        ? scheme.errorContainer
                        : scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(RadiusTokens.md),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: destructive ? scheme.error : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: Spacing.sm),
                trailing!,
              ] else if (onTap != null && showChevron) ...[
                const SizedBox(width: Spacing.sm),
                ExcludeSemantics(
                  child: Icon(
                    Icons.chevron_right,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A group title: small all-caps label, announced as a heading.
class GroupTitle extends StatelessWidget {
  const GroupTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.lg, 0, Spacing.sm),
      child: Eyebrow(
        text,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
