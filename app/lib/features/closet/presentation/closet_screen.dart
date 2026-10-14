import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stylist/core/analytics/analytics_event.dart';
import 'package:stylist/core/providers.dart';
import 'package:stylist/features/closet/application/closet_providers.dart';
import 'package:stylist/features/closet/domain/closet_meter.dart';
import 'package:stylist/features/closet/domain/closet_query.dart';
import 'package:stylist/features/closet/domain/garment.dart';
import 'package:stylist/features/closet/domain/taxonomy.dart';
import 'package:stylist/features/closet/domain/taxonomy_labels.dart';
import 'package:stylist/features/closet/presentation/closet_routes.dart';
import 'package:stylist/features/closet/presentation/closet_widgets.dart';
import 'package:stylist/features/closet/presentation/garment_fields_editor.dart';
import 'package:stylist/l10n/gen/app_localizations.dart';
import 'package:stylist/shared/widgets/state_views.dart';
import 'package:stylist/theme/tokens.dart';

String sortLabel(AppLocalizations l10n, ClosetSort s) => switch (s) {
  ClosetSort.newest => l10n.sortNewest,
  ClosetSort.oldest => l10n.sortOldest,
  ClosetSort.recentlyEdited => l10n.sortRecentlyEdited,
  ClosetSort.formalityLow => l10n.sortFormalityLow,
  ClosetSort.formalityHigh => l10n.sortFormalityHigh,
};

/// Browse the closet: thumbnails, quick category chips, search, filters, sort, infinite scroll.
class ClosetScreen extends ConsumerStatefulWidget {
  const ClosetScreen({super.key});

  @override
  ConsumerState<ClosetScreen> createState() => _ClosetScreenState();
}

class _ClosetScreenState extends ConsumerState<ClosetScreen> {
  final _scroll = ScrollController();
  final _searchCtl = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 600) {
        unawaited(ref.read(closetListProvider.notifier).loadMore());
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtl.dispose();
    super.dispose();
  }

  void _setQuery(ClosetQuery q, String kind) {
    ref.read(closetQueryProvider.notifier).state = q;
    ref.read(analyticsServiceProvider).track(AnalyticsEvent.closetFilterUsed, {
      'kind': kind,
    });
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final q = ref.read(closetQueryProvider);
      if (q.text != text) _setQuery(q.copyWith(text: text), 'search');
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final query = ref.watch(closetQueryProvider);
    final list = ref.watch(closetListProvider);
    final config = ref.watch(remoteConfigProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtl,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.closetSearch,
                  border: InputBorder.none,
                ),
                onChanged: _onSearch,
              )
            : Text(l10n.closetTitle),
        actions: [
          IconButton(
            tooltip: _searching ? l10n.closetSearchClear : l10n.closetSearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtl.clear();
                if (query.text.isNotEmpty) {
                  _setQuery(query.copyWith(text: ''), 'search');
                }
              }
            },
          ),
          PopupMenuButton<ClosetSort>(
            tooltip: l10n.closetSort,
            icon: const Icon(Icons.sort),
            initialValue: query.sort,
            onSelected: (s) => _setQuery(query.copyWith(sort: s), 'sort'),
            itemBuilder: (_) => [
              for (final s in ClosetSort.values)
                PopupMenuItem(value: s, child: Text(sortLabel(l10n, s))),
            ],
          ),
          IconButton(
            tooltip: query.activeFilterCount == 0
                ? l10n.closetFilters
                : l10n.closetFiltersActive(query.activeFilterCount),
            icon: Badge(
              isLabelVisible: query.activeFilterCount > 0,
              label: Text('${query.activeFilterCount}'),
              child: const Icon(Icons.tune),
            ),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => const FilterSheet(),
            ),
          ),
          if (config?.closetBulkAddEnabled ?? true)
            IconButton(
              tooltip: l10n.closetAddMany,
              icon: const Icon(Icons.collections_outlined),
              onPressed: () => context.push(ClosetRoutes.bulk),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(ClosetRoutes.add),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: Text(l10n.closetAdd),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(closetSummaryProvider);
            await ref.read(closetListProvider.notifier).refresh();
          },
          child: list.when(
            loading: () => const LoadingView(),
            error: (_, _) => ErrorView(
              message: l10n.closetLoadError,
              onRetry: () => ref.invalidate(closetListProvider),
            ),
            data: (state) => _Grid(
              state: state,
              query: query,
              controller: _scroll,
              onQuery: _setQuery,
            ),
          ),
        ),
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({
    required this.state,
    required this.query,
    required this.controller,
    required this.onQuery,
  });
  final ClosetListState state;
  final ClosetQuery query;
  final ScrollController controller;
  final void Function(ClosetQuery, String) onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900
        ? 5
        : width >= 600
        ? 4
        : width >= 360
        ? 3
        : 2;
    // Larger text means fewer, taller tiles.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final cols = scale > 1.4 ? (columns - 1).clamp(2, columns) : columns;
    final empty = state.items.isEmpty;

    return CustomScrollView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
          sliver: SliverToBoxAdapter(child: UploadBanner()),
        ),
        const SliverToBoxAdapter(child: _SummaryHeader()),
        SliverToBoxAdapter(
          child: _CategoryChips(query: query, onQuery: onQuery),
        ),
        if (empty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _Empty(filtered: !query.isDefault || query.text.isNotEmpty),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(Spacing.md),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: Spacing.sm,
                crossAxisSpacing: Spacing.sm,
                childAspectRatio: 0.82,
              ),
              itemCount: state.items.length,
              itemBuilder: (_, i) => _Tile(garment: state.items[i], cols: cols),
            ),
          ),
        if (state.loadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(Spacing.md),
              child: LinearProgressIndicator(),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
      semanticChildCount: state.items.length,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered});
  final bool filtered;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(
            child: Icon(
              filtered ? Icons.search_off : Icons.checkroom_outlined,
              size: 56,
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(
            filtered ? l10n.closetNoMatches : l10n.closetEmptyTitle,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (!filtered) ...[
            const SizedBox(height: Spacing.sm),
            Text(l10n.closetEmptyBody, textAlign: TextAlign.center),
          ],
          if (filtered)
            Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => ref.read(closetQueryProvider.notifier).state =
                    const ClosetQuery(),
                child: Text(l10n.filterClear),
              ),
            ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.garment, required this.cols});
  final GarmentSummary garment;
  final int cols;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final name = garmentName(
      l10n,
      category: garment.category,
      subcategory: garment.subcategory,
      color: garment.primaryColor,
    );
    final status = <String>[
      if (garment.analysisStatus.isWorking) l10n.closetItemAnalysing,
      if (garment.analysisStatus == AnalysisStatus.needsManual)
        l10n.closetItemNeedsManual,
      if (garment.lowConfidenceFields.isNotEmpty && !garment.reviewed)
        l10n.closetItemNeedsReview,
      if (garment.favorite) l10n.closetItemFavourite,
      if (garment.availability != Availability.available)
        availabilityLabel(l10n, garment.availability),
      if (garment.archived) l10n.closetItemArchived,
    ];
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cell =
        ((MediaQuery.sizeOf(context).width - Spacing.md * 2) / cols * dpr)
            .round();
    final unavailable =
        garment.availability != Availability.available || garment.archived;
    void open() => context.push(ClosetRoutes.item(garment.id));
    // The screen-reader node is the name band only (>= 48dp tall): a node that also covered the picture
    // could not be contrast-checked, and sighted users get the whole tile as the tap target anyway.
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(RadiusTokens.md),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              excludeFromSemantics: true,
              onTap: open,
              child: ExcludeSemantics(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(
                      opacity: unavailable ? 0.5 : 1,
                      child: GarmentThumb(garment: garment, cacheWidth: cell),
                    ),
                    if (garment.analysisStatus.isWorking)
                      const Positioned(
                        right: Spacing.xs,
                        top: Spacing.xs,
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Positioned(
                      left: Spacing.xs,
                      top: Spacing.xs,
                      child: Row(
                        children: [
                          if (garment.favorite) _Badge(Icons.favorite, scheme),
                          if (garment.availability != Availability.available)
                            _Badge(Icons.hourglass_bottom, scheme),
                          if (garment.archived)
                            _Badge(Icons.archive_outlined, scheme),
                          if (garment.lowConfidenceFields.isNotEmpty &&
                              !garment.reviewed)
                            _Badge(Icons.flag_outlined, scheme),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Semantics(
            button: true,
            label: status.isEmpty
                ? name
                : l10n.closetItemLabel(name, status.join(', ')),
            excludeSemantics: true,
            onTap: open,
            child: InkWell(
              excludeFromSemantics: true,
              onTap: open,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Spacing.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Spacing.sm,
                    vertical: Spacing.xs,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.icon, this.scheme);
  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 2),
    child: CircleAvatar(
      radius: 11,
      backgroundColor: scheme.surface,
      child: Icon(icon, size: 14, color: scheme.primary),
    ),
  );
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.query, required this.onQuery});
  final ClosetQuery query;
  final void Function(ClosetQuery, String) onQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        children: [
          OptionChip(
            label: l10n.filterAll,
            selected: query.category == null,
            onTap: () => onQuery(
              query.copyWith(category: null, subcategory: null),
              'category',
            ),
          ),
          for (final c in Taxonomy.instance.categoryIds)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.sm),
              child: OptionChip(
                label: l10n.taxCategory(c),
                selected: query.category == c,
                onTap: () => onQuery(
                  query.copyWith(category: c, subcategory: null),
                  'category',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryHeader extends ConsumerWidget {
  const _SummaryHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(closetSummaryProvider).valueOrNull;
    final meter = ref.watch(closetMeterProvider).valueOrNull;
    if (summary == null || meter == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.sm, Spacing.md, 0),
      child: ClosetMeterCard(summary: summary, meter: meter),
    );
  }
}

/// Item count against the plan limit, the outfit-potential bar and (only when useful) one suggestion.
class ClosetMeterCard extends ConsumerStatefulWidget {
  const ClosetMeterCard({
    required this.summary,
    required this.meter,
    super.key,
  });
  final ClosetSummary summary;
  final ClosetMeter meter;

  @override
  ConsumerState<ClosetMeterCard> createState() => _ClosetMeterCardState();
}

class _ClosetMeterCardState extends ConsumerState<ClosetMeterCard> {
  String? _reported;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final m = widget.meter;
    final nudge = m.nudge;
    if (nudge != null) {
      final key =
          '${nudge.category}:${nudge.outfitsBefore}:${nudge.outfitsAfter}';
      if (_reported != key) {
        _reported = key;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(analyticsServiceProvider).track(
            AnalyticsEvent.closetMeterNudgeShown,
            {
              'category': nudge.category,
              'outfits_before': nudge.outfitsBefore,
              'outfits_after': nudge.outfitsAfter,
            },
          );
        });
      }
    }
    final item = switch (nudge?.category) {
      'footwear' => l10n.meterNudgeFootwear,
      'top' => l10n.meterNudgeTop,
      'bottom' => l10n.meterNudgeBottom,
      'dress' => l10n.meterNudgeDress,
      _ => '',
    };
    final level = switch (m.level) {
      MeterLevel.empty => l10n.meterLevelEmpty,
      MeterLevel.starting => l10n.meterLevelStarting,
      MeterLevel.growing => l10n.meterLevelGrowing,
      MeterLevel.rich => l10n.meterLevelRich,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Spacing.md,
              runSpacing: Spacing.xs,
              children: [
                Text(
                  l10n.closetCount(widget.summary.used, widget.summary.limit),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  l10n.meterOutfits(m.outfits),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Semantics(
              label: l10n.meterProgressLabel((m.progress * 100).round()),
              child: ExcludeSemantics(
                child: LinearProgressIndicator(
                  value: m.progress,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              nudge != null ? l10n.meterNudge(item, nudge.gain) : level,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.summary.remaining == 0)
              Padding(
                padding: const EdgeInsets.only(top: Spacing.xs),
                child: Text(
                  l10n.upgradeTitle,
                  style: TextStyle(color: scheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// All filters in one sheet; changes apply as you tap and the grid behind updates.
class FilterSheet extends ConsumerWidget {
  const FilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final tax = Taxonomy.instance;
    final q = ref.watch(closetQueryProvider);
    final total = ref.watch(closetListProvider).valueOrNull?.total ?? 0;
    void set(ClosetQuery next, String kind) {
      ref.read(closetQueryProvider.notifier).state = next;
      ref.read(analyticsServiceProvider).track(
        AnalyticsEvent.closetFilterUsed,
        {'kind': kind},
      );
    }

    final lo = (q.formalityMin ?? 1).toDouble();
    final hi = (q.formalityMax ?? 5).toDouble();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            Spacing.md,
            0,
            Spacing.md,
            Spacing.md,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.closetFilters,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: Spacing.md),
            FieldSection(
              title: l10n.filterColour,
              children: [
                OptionChip(
                  label: l10n.filterAll,
                  selected: q.color == null,
                  onTap: () => set(q.copyWith(color: null), 'color'),
                ),
                for (final c in tax.palette)
                  OptionChip(
                    label: l10n.taxColor(c.id),
                    selected: q.color == c.id,
                    leading: ColourDot(c.id),
                    onTap: () => set(q.copyWith(color: c.id), 'color'),
                  ),
              ],
            ),
            FieldSection(
              title: l10n.filterSeason,
              children: [
                OptionChip(
                  label: l10n.filterAll,
                  selected: q.season == null,
                  onTap: () => set(q.copyWith(season: null), 'season'),
                ),
                for (final s in tax.seasons)
                  OptionChip(
                    label: l10n.taxSeason(s),
                    selected: q.season == s,
                    onTap: () => set(q.copyWith(season: s), 'season'),
                  ),
              ],
            ),
            Semantics(
              header: true,
              child: Text(
                l10n.filterFormality,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            RangeSlider(
              values: RangeValues(lo, hi),
              min: 1,
              max: 5,
              divisions: 4,
              labels: RangeLabels('${lo.round()}', '${hi.round()}'),
              semanticFormatterCallback: (v) =>
                  '${v.round()} ${l10n.taxFormalityLabel(v.round())}',
              onChanged: (r) => set(
                q.copyWith(
                  formalityMin: r.start.round() == 1 ? null : r.start.round(),
                  formalityMax: r.end.round() == 5 ? null : r.end.round(),
                ),
                'formality',
              ),
            ),
            FieldSection(
              title: l10n.filterAvailability,
              children: [
                OptionChip(
                  label: l10n.filterAll,
                  selected: q.availability == null,
                  onTap: () =>
                      set(q.copyWith(availability: null), 'availability'),
                ),
                for (final a in Availability.values)
                  OptionChip(
                    label: availabilityLabel(l10n, a),
                    selected: q.availability == a.name,
                    onTap: () =>
                        set(q.copyWith(availability: a.name), 'availability'),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.filterFavourites),
              value: q.favorite ?? false,
              onChanged: (v) =>
                  set(q.copyWith(favorite: v ? true : null), 'favorite'),
            ),
            FieldSection(
              title: l10n.filterArchived,
              children: [
                OptionChip(
                  label: l10n.availabilityAvailable,
                  selected: q.archived == ArchivedMode.exclude,
                  onTap: () => set(
                    q.copyWith(archived: ArchivedMode.exclude),
                    'archived',
                  ),
                ),
                OptionChip(
                  label: l10n.filterArchivedOnly,
                  selected: q.archived == ArchivedMode.only,
                  onTap: () =>
                      set(q.copyWith(archived: ArchivedMode.only), 'archived'),
                ),
                OptionChip(
                  label: l10n.filterAll,
                  selected: q.archived == ArchivedMode.include,
                  onTap: () => set(
                    q.copyWith(archived: ArchivedMode.include),
                    'archived',
                  ),
                ),
              ],
            ),
            Row(
              children: [
                TextButton(
                  onPressed:
                      q.activeFilterCount == 0 &&
                          q.archived == ArchivedMode.exclude
                      ? null
                      : () => ref.read(closetQueryProvider.notifier).state =
                            ClosetQuery(text: q.text, sort: q.sort),
                  child: Text(l10n.filterClear),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.filterApply(total)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
