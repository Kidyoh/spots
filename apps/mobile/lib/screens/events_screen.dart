import 'package:flutter/material.dart';

import '../logic/happenings.dart';
import '../models/happening.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/account_sheet.dart';
import '../widgets/common.dart';
import '../widgets/segmented_tabs.dart';
import 'discover_screen.dart' show navClearance;
import 'spot_detail_screen.dart' show openUrl;

/// What's on: published events, grouped by Addis day, soonest first.
class EventsScreen extends StatelessWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final events = state.filteredEvents;

    // group consecutive events by Addis day
    final groups = <(String, List<Happening>)>[];
    for (final e in events) {
      final label = dayLabel(e.startsAt);
      if (groups.isNotEmpty && groups.last.$1 == label) {
        groups.last.$2.add(e);
      } else {
        groups.add((label, [e]));
      }
    }

    final slivers = <Widget>[];
    if (state.happenings == null && state.eventsError == null) {
      slivers.add(
        SliverList.separated(
          itemCount: 4,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Skeleton(height: 118, radius: Radii.lg),
          ),
        ),
      );
    } else if (state.eventsError != null) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: EmptyState(
            emoji: '📡',
            title: "Couldn't load events",
            body: 'Check your connection and try again.',
            action: 'Try again',
            onAction: state.refreshEvents,
          ),
        ),
      );
    } else if (events.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: state.eventFiltersOn
              ? EmptyState(
                  emoji: '🗓️',
                  title: 'Nothing matches',
                  body: 'No events match these filters.',
                  action: 'Clear filters',
                  onAction: state.clearEventFilters,
                )
              : const EmptyState(
                  emoji: '🌙',
                  title: 'Nothing on the calendar yet',
                  body: 'We list events as the city announces them — most land only a few days ahead.',
                ),
        ),
      );
    } else {
      for (final (label, list) in groups) {
        slivers.add(
          SliverToBoxAdapter(
            child: _DayHeader(label: label, count: list.length),
          ),
        );
        slivers.add(
          SliverList.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: EventTile(happening: list[i]),
            ),
          ),
        );
      }
    }

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: Palette.green,
        backgroundColor: Palette.card,
        onRefresh: state.refreshEvents,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            SliverToBoxAdapter(child: _EventsHeader(count: state.happenings?.length)),
            SliverPersistentHeader(pinned: true, delegate: _FiltersHeader()),
            ...slivers,
            SliverToBoxAdapter(child: SizedBox(height: navClearance(context) + 12)),
          ],
        ),
      ),
    );
  }
}

class _EventsHeader extends StatelessWidget {
  const _EventsHeader({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("What's on", style: Theme.of(context).textTheme.headlineMedium),
                Text(
                  count == null ? 'Events around Addis' : '$count upcoming around Addis',
                  style: const TextStyle(fontSize: 13, color: Palette.muted, fontStyle: FontStyle.italic),
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

/// The When tabs + kind chips, pinned so they float over the list as it
/// scrolls beneath.
class _FiltersHeader extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => 118;
  @override
  double get maxExtent => 118;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final state = AppScope.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Palette.bg,
        boxShadow: overlapsContent || shrinkOffset > 0
            ? [BoxShadow(color: Palette.shadow.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 6))]
            : null,
      ),
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SegmentedTabs(
              labels: const ['Anytime', 'Today', 'Weekend', 'Month'],
              index: state.eventWhen.index,
              onChanged: (i) => state.setEventWhen(EventWhen.values[i]),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                FilterChipPill(
                  label: 'Free',
                  leading: '🎟️',
                  selected: state.eventFreeOnly,
                  onTap: state.toggleFreeOnly,
                ),
                for (final (key, label, emoji, _) in eventKinds) ...[
                  const SizedBox(width: 8),
                  FilterChipPill(
                    label: label,
                    leading: emoji,
                    selected: state.eventKindsOn.contains(key),
                    onTap: () => state.toggleEventKind(key),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.count});

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final soon = label == 'Today' || label == 'Tomorrow';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      child: Row(
        children: [
          if (soon)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(color: Palette.terracotta, shape: BoxShape.circle),
            ),
          Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
          const SizedBox(width: 8),
          Text(
            '$count ${count == 1 ? 'event' : 'events'}',
            style: const TextStyle(color: Palette.muted, fontSize: 12.5),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

/// One event in the list: a flyer-coloured date stamp, then what/where/when.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.happening});

  final Happening happening;

  @override
  Widget build(BuildContext context) {
    final h = happening;
    final head = heading(h);
    final stamp = dateStamp(h.startsAt);
    final time = timeLabel(h.startsAt);
    final price = eventPriceLabel(h);
    final span = spanLabel(h.startsAt, h.endsAt);
    final cd = countdown(h.startsAt);

    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => showEventSheet(context, h),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: Palette.lineSoft),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                height: 104,
                child: Cover(
                  gradientKey: h.id,
                  url: h.imageUrl,
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    color: Palette.greenDeep.withValues(alpha: h.imageUrl == null ? 0 : 0.35),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          stamp.weekday.toUpperCase(),
                          style: const TextStyle(
                            color: Palette.card,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        Text(
                          stamp.day,
                          style: const TextStyle(
                            color: Palette.card,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            height: 1.05,
                          ),
                        ),
                        Text(
                          stamp.month.toUpperCase(),
                          style: const TextStyle(
                            color: Palette.card,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Pill(text: span ?? cd, hot: cd == 'Today' || cd == 'On now'),
                        if (price != null) ...[const SizedBox(width: 6), _Pill(text: price, free: price == 'Free')],
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      head.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [if (!head.venueUsed && h.venueName != null) h.venueName!, ?time].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Palette.inkSoft),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Palette.divider),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.hot = false, this.free = false});

  final String text;
  final bool hot;
  final bool free;

  @override
  Widget build(BuildContext context) {
    final bg = hot
        ? Palette.terracotta
        : free
        ? Palette.press
        : Palette.accentWash;
    final fg = hot
        ? Palette.card
        : free
        ? Palette.green
        : Palette.accentText;
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.pill)),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

Future<void> showEventSheet(BuildContext context, Happening h) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scroll) => _EventSheet(happening: h, scroll: scroll),
    ),
  );
}

class _EventSheet extends StatelessWidget {
  const _EventSheet({required this.happening, required this.scroll});

  final Happening happening;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    final h = happening;
    final head = heading(h);
    final stamp = dateStamp(h.startsAt);
    final time = timeLabel(h.startsAt);
    final price = eventPriceLabel(h);
    final span = spanLabel(h.startsAt, h.endsAt);

    return Container(
      decoration: const BoxDecoration(
        color: Palette.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: 260,
            child: Cover(
              gradientKey: h.id,
              url: h.imageUrl,
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Palette.card.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(Radii.pill),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    bottom: 18,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Palette.card,
                        borderRadius: BorderRadius.circular(Radii.md),
                        boxShadow: Shadows.floating,
                      ),
                      child: Column(
                        children: [
                          Text(
                            stamp.weekday.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Palette.accentText,
                              letterSpacing: 1.2,
                            ),
                          ),
                          Text(
                            stamp.day,
                            style: const TextStyle(fontSize: 28, height: 1.1, fontWeight: FontWeight.w700),
                          ),
                          Text(
                            stamp.month.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Palette.muted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(head.title, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                _InfoRow(
                  icon: Icons.schedule_rounded,
                  text: [span ?? dayLabel(h.startsAt), ?time].join(' · '),
                  // "in 5 days" under "Sunday 18 Oct"; nothing under "Today"
                  sub: countdown(h.startsAt) == (span ?? dayLabel(h.startsAt)) ? null : countdown(h.startsAt),
                ),
                if (!head.venueUsed && h.venueName != null) _InfoRow(icon: Icons.place_outlined, text: h.venueName!),
                if (head.venueUsed) _InfoRow(icon: Icons.place_outlined, text: h.venueName!),
                if (price != null) _InfoRow(icon: Icons.confirmation_number_outlined, text: price),
                if (h.summary != null) ...[
                  const SizedBox(height: 12),
                  Text(h.summary!, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Palette.inkSoft)),
                ],
                if (h.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in h.tags)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Palette.card,
                            borderRadius: BorderRadius.circular(Radii.pill),
                            border: Border.all(color: Palette.lineSoft),
                          ),
                          child: Text(
                            '#$t',
                            style: const TextStyle(fontSize: 12, color: Palette.inkSoft, fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: () => openUrl(calendarUri(h)),
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Add to calendar', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (h.ticketUrl != null)
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Palette.accentWash,
                              foregroundColor: Palette.accentText,
                            ),
                            onPressed: () => openUrl(Uri.parse(h.ticketUrl!)),
                            icon: const Icon(Icons.local_activity_outlined),
                            label: const Text('Tickets'),
                          ),
                        ),
                      ),
                    if (h.ticketUrl != null && h.sourceUrl.isNotEmpty) const SizedBox(width: 10),
                    if (h.sourceUrl.isNotEmpty)
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => openUrl(Uri.parse(h.sourceUrl)),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18),
                            label: const Text('Original post'),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.sub});

  final IconData icon;
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: Palette.press, borderRadius: BorderRadius.circular(Radii.sm)),
            child: Icon(icon, size: 20, color: Palette.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink, fontSize: 15),
                ),
                if (sub != null) Text(sub!, style: const TextStyle(fontSize: 12.5, color: Palette.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
