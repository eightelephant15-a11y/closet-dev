import 'package:flutter/material.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/theme/tokens.dart';

/// Accessible selectable option (>=56 tall). State is conveyed by a thicker border, a tint and a check
/// (never colour alone) and announced by the screen reader.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    super.key,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: selected
          ? l10n.optionSelected(label)
          : l10n.optionNotSelected(label),
      hint: subtitle,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(RadiusTokens.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.minTouchTarget + 8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.sm + 2,
              ),
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Spacing.sm + 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: text.bodyLarge?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? scheme.primary : scheme.onSurface,
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
                  const SizedBox(width: Spacing.sm),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? scheme.primary
                          : scheme.surfaceContainerHigh,
                    ),
                    child: selected
                        ? Icon(Icons.check, size: 16, color: scheme.onPrimary)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
