import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/categories.dart';
import '../logic/format.dart';
import '../logic/geo.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/account_sheet.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';
import '../widgets/dice_button.dart';
import '../widgets/spot_card.dart';
import '../widgets/swipe_deck.dart';
import 'spot_detail_screen.dart';

/// Height reserved at the bottom of every tab for the floating nav bar.
double navClearance(BuildContext context) => 66 + 14 + MediaQuery.paddingOf(context).bottom + 8;

/// The "surprise me" discovery deck — the web's `/` carousel.
class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final spots = state.filteredSpots;

    Widget body;
    if (state.spots == null && state.spotsError == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Skeleton(radius: Radii.xl),
      );
    } else if (state.spotsError != null) {
      body = EmptyState(
        icon: Icons.wifi_off_rounded,
        title: "Couldn't load spots",
        body: "We couldn't reach the server. Check your connection and try again.",
        action: 'Try again',
        onAction: state.retry,
      );
    } else if (spots.isEmpty) {
      final q = state.query.trim();
      final hidden = state.searchOnlyMatches;
      if (q.isNotEmpty && hidden > 0) {
        // the search found spots, but a chip/area/price filter is hiding them
        final narrowing = [
          for (final c in categories)
            if (state.selectedCategories.contains(c.key)) c.label,
          ?state.area,
          if (state.price != null) priceLabels[state.price]!,
        ].join(', ');
        body = EmptyState(
          icon: Icons.filter_alt_off_rounded,
          title: 'No “$q” in $narrowing',
          body: '$hidden ${hidden == 1 ? 'spot matches' : 'spots match'} “$q” outside these filters.',
          action: 'Show ${hidden == 1 ? 'it' : 'all $hidden'}',
          onAction: state.searchEverywhere,
        );
      } else if (q.isNotEmpty) {
        body = EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Nothing found for “$q”',
          body: 'Try a shorter word, a dish, or an area like Bole or Piassa.',
          action: 'Clear search',
          onAction: () => state.setQuery(''),
        );
      } else {
        body = EmptyState(
          icon: Icons.explore_off_rounded,
          title: 'Nothing matches',
          body: 'No spots match these filters — try widening the area or price.',
          action: 'Clear filters',
          onAction: state.clearFilters,
        );
      }
    } else {
      final i = state.deckIndex % spots.length;
      body = Padding(
        // bottom room for the cards stacked beneath to peek out
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 34),
        child: SwipeDeck(
          itemCount: spots.length,
          index: i,
          keyOf: (j) => spots[j].placeId,
          // like the web: left → next, right → previous
          onSwiped: (dir) => state.step(dir == AxisDirection.left ? 1 : -1),
          itemBuilder: (context, j) {
            final s = spots[j];
            return SpotCard(
              spot: s,
              saved: state.isSaved(s.placeId),
              visited: state.isVisited(s.placeId),
              showHint: state.showSwipeHint && j == i,
              distance: state.coords != null && !state.farFromAddis ? formatRoadEstimate(state.roadKmTo(s)) : null,
              onOpen: () => openSpot(context, s, heroTag: 'cover-${s.placeId}'),
            );
          },
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          const _Header(),
          const _SearchBar(),
          const _CategoryChips(),
          Expanded(child: body),
          if (spots.isNotEmpty) const _DeckControls(),
          SizedBox(height: navClearance(context)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final count = state.spots?.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
      child: Row(
        children: [
          const BrandMark(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('spots', style: Theme.of(context).textTheme.headlineSmall?.copyWith(height: 1.1)),
                const SizedBox(height: 2),
                Text(
                  count == null ? 'Date spots around Addis' : '$count places · from the people who actually went',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: Palette.muted, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),
          const AccountButton(),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final active = state.activeFilterCount;
    final summary = [
      if (state.query.trim().isNotEmpty) '“${state.query.trim()}”',
      if (state.area != null) state.area!,
      if (state.price != null) priceLabels[state.price]!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Material(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.pill),
          onTap: () => showFilterSheet(context),
          child: Container(
            height: 50,
            padding: const EdgeInsets.only(left: 18, right: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.pill),
              border: Border.all(color: Palette.line),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Palette.inkSoft, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary.isEmpty ? 'rooftop coffee, quiet date…' : summary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: summary.isEmpty ? Palette.muted : Palette.ink,
                      fontWeight: summary.isEmpty ? FontWeight.w500 : FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active > 0 ? Palette.green : Palette.press,
                    borderRadius: BorderRadius.circular(Radii.pill),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 18, color: active > 0 ? Palette.bg : Palette.green),
                      if (active > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '$active',
                          style: const TextStyle(color: Palette.bg, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cats = categories.where((c) => c.key != 'new' || state.hasNewSpots).toList();
    return SizedBox(
      height: 44,
      child: ShaderMask(
        // fade the chip row out at both edges so it reads as scrollable
        shaderCallback: (r) => const LinearGradient(
          colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, 0.05, 0.92, 1],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: cats.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final c = cats[i];
            return Center(
              child: FilterChipPill(
                label: c.label,
                leading: c.icon,
                selected: state.selectedCategories.contains(c.key),
                onTap: () => state.toggleCategory(c.key),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DeckControls extends StatelessWidget {
  const _DeckControls();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final n = state.filteredSpots.length;
    final current = state.currentSpot!;
    final saved = state.isSaved(current.placeId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: LayoutBuilder(
        builder: (context, box) => Row(
          children: [
            RoundIconButton(icon: Icons.undo_rounded, tooltip: 'Previous', size: 48, onPressed: () => state.step(-1)),
            const SizedBox(width: 8),
            // takes all the free space in the row and, on a very narrow phone,
            // shrinks the text rather than cutting off the total
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: Text.rich(
                    key: ValueKey(state.deckIndex),
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${state.deckIndex % n + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink),
                        ),
                        const TextSpan(
                          text: ' of ',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        ),
                        TextSpan(text: '$n'),
                      ],
                    ),
                    maxLines: 1,
                    style: const TextStyle(color: Palette.muted, fontSize: 14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: saved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              tooltip: saved ? 'Remove from Want to go' : 'Save to Want to go',
              size: 48,
              active: saved,
              onPressed: () async {
                HapticFeedback.mediumImpact();
                final ok = await state.toggleSaved(current);
                if (!ok && context.mounted) {
                  await showAccountSheet(context, reason: 'Sign in to save spots to your "Want to go" list.');
                }
              },
            ),
            const SizedBox(width: 8),
            // narrow phones keep the die and drop the label, so the counter
            // always has room for its total
            DiceButton(onRoll: state.surprise, compact: box.maxWidth < 320),
          ],
        ),
      ),
    );
  }
}

/// Search, area, price and sort — the web's "Search & filters" panel, as a
/// sheet that slides up over the deck.
Future<void> showFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _FilterSheet(),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet();

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _search = TextEditingController(text: AppScope.read(context).query);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final n = state.filteredSpots.length;
    final label = Theme.of(context).textTheme.titleSmall?.copyWith(color: Palette.muted, letterSpacing: 0.6);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 12, 8),
                child: Row(
                  children: [
                    Text('Search & filters', style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        _search.clear();
                        state.clearFilters();
                      },
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                  children: [
                    TextField(
                      controller: _search,
                      onChanged: state.setQuery,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => Navigator.pop(context),
                      decoration: InputDecoration(
                        hintText: 'rooftop coffee, quiet date…',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _search.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () {
                                  _search.clear();
                                  state.setQuery('');
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('AREA', style: label),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChipPill(
                          label: 'All areas',
                          selected: state.area == null,
                          onTap: () => state.setArea(null),
                        ),
                        for (final a in state.areas)
                          FilterChipPill(
                            label: a,
                            selected: state.area == a,
                            onTap: () => state.setArea(state.area == a ? null : a),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('PRICE', style: label),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilterChipPill(
                          label: 'Any price',
                          selected: state.price == null,
                          onTap: () => state.setPrice(null),
                        ),
                        for (final lvl in [1, 2, 3, 4])
                          FilterChipPill(
                            label: '${priceLabels[lvl]} · ${priceRangeText[lvl]}',
                            selected: state.price == lvl,
                            onTap: () => state.setPrice(state.price == lvl ? null : lvl),
                          ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    Text('SORT BY', style: label),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in SortMode.values)
                          FilterChipPill(label: m.label, selected: state.sort == m, onTap: () => state.setSort(m)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      n == 0 ? 'No spots match' : 'Show $n ${n == 1 ? 'spot' : 'spots'}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
