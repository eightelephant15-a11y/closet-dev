import 'package:flutter/material.dart';
import 'package:stylist/features/auth/domain/app_user.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/closet/domain/taxonomy_labels.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/theme/tokens.dart';

/// One tappable option (>=48dp). State is shown by icon + border as well as colour, and announced.
class OptionChip extends StatelessWidget {
  const OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      selected: selected,
      enabled: onTap != null,
      label: selected
          ? l10n.optionSelected(label)
          : l10n.optionNotSelected(label),
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected
            ? scheme.primary.withValues(alpha: 0.10)
            : scheme.surfaceContainerLow,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Spacing.minTouchTarget,
              minWidth: Spacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.md,
                vertical: Spacing.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: Spacing.sm),
                  ],
                  if (selected) ...[
                    ExcludeSemantics(
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 18,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? scheme.primary : scheme.onSurface,
                      ),
                    ),
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

/// A titled group of options. Fields the AI was unsure about get a visible "Please check" marker.
class FieldSection extends StatelessWidget {
  const FieldSection({
    required this.title,
    required this.children,
    this.flagged = false,
    this.caption,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final bool flagged;

  /// Small muted note on the right of the title ("Pick any").
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context).textTheme;
    return Semantics(
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: Spacing.md),
        padding: flagged ? const EdgeInsets.all(Spacing.md) : EdgeInsets.zero,
        decoration: flagged
            ? BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(RadiusTokens.lg),
                border: Border.all(color: scheme.primary, width: 1.5),
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: Spacing.sm,
                runSpacing: Spacing.xs,
                children: [
                  Text(title, style: theme.titleMedium),
                  if (flagged)
                    Semantics(
                      label: l10n.reviewLowConfidence(title),
                      child: ExcludeSemantics(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(
                              RadiusTokens.pill,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: Spacing.sm + 2,
                              vertical: 3,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.flag_outlined,
                                  size: 14,
                                  color: scheme.onPrimary,
                                ),
                                const SizedBox(width: Spacing.xs),
                                Flexible(
                                  child: Text(
                                    l10n.reviewCheck,
                                    style: theme.labelMedium?.copyWith(
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (caption != null)
                    Text(
                      caption!,
                      style: theme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: children,
            ),
          ],
        ),
      ),
    );
  }
}

/// All editable taxonomy fields as one-tap chips. [values] uses API field names.
///
/// Used by the review screen and the item detail screen, so correcting a field is the same
/// interaction everywhere: one tap on the right chip.
class GarmentFieldsEditor extends StatelessWidget {
  const GarmentFieldsEditor({
    required this.values,
    required this.onChanged,
    this.lowConfidence = const {},
    this.department,
    super.key,
  });

  final Map<String, Object?> values;
  final Set<String> lowConfidence;
  final ClothingDepartment? department;

  /// Called with the API field(s) that changed, e.g. `{'category': 'top', 'subcategory': null}`.
  final void Function(Map<String, Object?> changes) onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tax = Taxonomy.instance;
    final category = values['category'] as String?;
    final sub = values['subcategory'] as String?;
    final primary = values['primary_color'] as String?;
    final secondary = values['secondary_color'] as String?;
    final pattern = values['pattern'] as String?;
    final formality = values['formality'] as int?;
    final seasons = ((values['seasons'] as List?) ?? const []).cast<String>();
    final fit = values['fit'] as String?;
    final material = values['material'] as String?;
    bool flag(String f) => lowConfidence.contains(f);

    Widget none({required bool selected, required String field}) => OptionChip(
      label: l10n.reviewFieldNone,
      selected: selected,
      onTap: () => onChanged({field: null}),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldSection(
          title: l10n.fieldCategory,
          flagged: flag('category'),
          children: [
            for (final c in tax.visibleCategories(department))
              OptionChip(
                label: l10n.taxCategory(c.id),
                selected: category == c.id,
                onTap: () => onChanged({
                  'category': c.id,
                  if (sub != null && tax.categoryOf(sub) != c.id)
                    'subcategory': null,
                }),
              ),
          ],
        ),
        if (category != null)
          FieldSection(
            title: l10n.fieldSubcategory,
            flagged: flag('subcategory'),
            children: [
              for (final s in tax.visibleSubcategories(category, department))
                OptionChip(
                  label: l10n.taxSubcategory(s.id),
                  selected: sub == s.id,
                  onTap: () => onChanged({'subcategory': s.id}),
                ),
            ],
          ),
        FieldSection(
          title: l10n.fieldPrimaryColor,
          flagged: flag('primary_color'),
          children: [
            for (final c in tax.palette)
              OptionChip(
                label: l10n.taxColor(c.id),
                selected: primary == c.id,
                leading: ColourDot(c.id),
                onTap: () => onChanged({'primary_color': c.id}),
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldSecondaryColor,
          flagged: flag('secondary_color'),
          children: [
            none(selected: secondary == null, field: 'secondary_color'),
            for (final c in tax.palette)
              OptionChip(
                label: l10n.taxColor(c.id),
                selected: secondary == c.id,
                leading: ColourDot(c.id),
                onTap: () => onChanged({'secondary_color': c.id}),
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldPattern,
          flagged: flag('pattern'),
          children: [
            for (final p in tax.patterns)
              OptionChip(
                label: l10n.taxPattern(p),
                selected: pattern == p,
                onTap: () => onChanged({'pattern': p}),
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldFormality,
          flagged: flag('formality'),
          children: [
            for (final f in tax.formality)
              OptionChip(
                label: '$f ${l10n.taxFormalityLabel(f)}',
                selected: formality == f,
                onTap: () => onChanged({'formality': f}),
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldSeasons,
          caption: l10n.fieldSeasonsHint,
          flagged: flag('seasons'),
          children: [
            for (final s in tax.seasons)
              OptionChip(
                label: l10n.taxSeason(s),
                selected: seasons.contains(s),
                onTap: () {
                  final next = [
                    for (final x in tax.seasons)
                      if (x == s ? !seasons.contains(s) : seasons.contains(x))
                        x,
                  ];
                  onChanged({'seasons': next});
                },
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldFit,
          flagged: flag('fit'),
          children: [
            none(selected: fit == null, field: 'fit'),
            for (final f in tax.fits)
              OptionChip(
                label: l10n.taxFit(f),
                selected: fit == f,
                onTap: () => onChanged({'fit': f}),
              ),
          ],
        ),
        FieldSection(
          title: l10n.fieldMaterial,
          flagged: flag('material'),
          children: [
            none(selected: material == null, field: 'material'),
            for (final m in tax.materials)
              OptionChip(
                label: l10n.taxMaterial(m),
                selected: material == m,
                onTap: () => onChanged({'material': m}),
              ),
          ],
        ),
      ],
    );
  }
}

/// API-field map for a [Garment] (what the editor edits).
Map<String, Object?> editableValues(Garment g) => {
  'category': g.category,
  'subcategory': g.subcategory,
  'primary_color': g.primaryColor,
  'secondary_color': g.secondaryColor,
  'pattern': g.pattern,
  'formality': g.formality,
  'seasons': g.seasons,
  'fit': g.fit,
  'material': g.material,
};
