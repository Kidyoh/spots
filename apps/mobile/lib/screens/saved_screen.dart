import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/format.dart';
import '../models/spot.dart';
import '../models/visit.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/account_sheet.dart';
import '../widgets/common.dart';
import '../widgets/segmented_tabs.dart';
import 'discover_screen.dart' show navClearance;
import 'spot_detail_screen.dart';

/// Our lists: "Want to go" (bookmarks) and "Places we've been" (the rated log).
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    Widget body;
    if (!state.canPersonalize) {
      body = EmptyState(
        emoji: '💌',
        title: 'Your lists live here',
        body: 'Sign in with Google to save spots you want to try and keep a rated log of the places you\'ve been.',
        action: 'Sign in',
        onAction: () => showAccountSheet(context),
      );
    } else if (_tab == 0) {
      body = _WantToGo(spots: state.savedSpots);
    } else {
      body = _BeenHere(visits: state.visits);
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Our places', style: Theme.of(context).textTheme.headlineMedium),
                      Text(
                        state.canPersonalize
                            ? '${state.savedIds.length} to try · ${state.visits.length} been'
                            : 'Saved spots and our visit log',
                        style: const TextStyle(fontSize: 13, color: Palette.muted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const AccountButton(),
              ],
            ),
          ),
          if (state.canPersonalize)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SegmentedTabs(
                labels: const ['Want to go', 'Been here'],
                counts: [state.savedIds.length, state.visits.length],
                index: _tab,
                onChanged: (i) => setState(() => _tab = i),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (c, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
                  child: c,
                ),
              ),
              child: KeyedSubtree(key: ValueKey('${state.canPersonalize}-$_tab'), child: body),
            ),
          ),
        ],
      ),
    );
  }
}

class _WantToGo extends StatelessWidget {
  const _WantToGo({required this.spots});

  final List<Spot> spots;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (spots.isEmpty) {
      return EmptyState(
        emoji: '🔖',
        title: 'Nothing saved yet',
        body: 'Tap the bookmark on any spot and it lands here — your shortlist for the next date.',
        action: 'Start browsing',
        onAction: () => state.setTab(0),
      );
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20, 8, 20, navClearance(context) + 12),
      itemCount: spots.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final s = spots[i];
        return Dismissible(
          key: ValueKey('saved-${s.placeId}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(color: Palette.accentWash, borderRadius: BorderRadius.circular(Radii.lg)),
            child: const Icon(Icons.bookmark_remove_rounded, color: Palette.accentText),
          ),
          onDismissed: (_) => state.toggleSaved(s),
          child: _SpotRow(spot: s, heroPrefix: 'saved'),
        );
      },
    );
  }
}

class _SpotRow extends StatelessWidget {
  const _SpotRow({required this.spot, required this.heroPrefix, this.trailing, this.footer});

  final Spot spot;
  final String heroPrefix;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final price = spot.priceLevel != null ? priceLabels[spot.priceLevel] : null;
    final tag = '$heroPrefix-${spot.placeId}';
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => openSpot(context, spot, heroTag: tag),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: Palette.lineSoft),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Hero(
                  tag: tag,
                  child: Cover(
                    gradientKey: spot.placeId,
                    url: spot.coverImageUrl,
                    borderRadius: BorderRadius.circular(Radii.md),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15.5,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${spot.area}${price != null ? ' · $price' : ''} · ★ ${spot.stars.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 12.5, color: Palette.muted),
                    ),
                    ?footer,
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: Palette.divider),
            ],
          ),
        ),
      ),
    );
  }
}

class _BeenHere extends StatelessWidget {
  const _BeenHere({required this.visits});

  final List<Visit> visits;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (visits.isEmpty) {
      return EmptyState(
        emoji: '🥂',
        title: 'No dates logged yet',
        body: 'Mark a spot as "Been here" to start our log — then rate it and jot down what to order next time.',
        action: 'Find a spot',
        onAction: () => state.setTab(0),
      );
    }
    final rated = visits.where((v) => v.rating > 0).toList();
    final avg = rated.isEmpty ? null : rated.map((v) => v.rating).reduce((a, b) => a + b) / rated.length;

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 8, 20, navClearance(context) + 12),
      children: [
        if (avg != null)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Palette.green, Palette.greenDeep]),
              borderRadius: BorderRadius.circular(Radii.lg),
              boxShadow: Shadows.card,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${visits.length} places, together',
                      style: const TextStyle(color: Palette.bg, fontWeight: FontWeight.w700, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'our average rating',
                      style: TextStyle(color: Palette.bg.withValues(alpha: 0.7), fontSize: 12.5),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  avg.toStringAsFixed(1),
                  style: const TextStyle(color: Palette.gold, fontSize: 30, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star_rounded, color: Palette.gold, size: 26),
              ],
            ),
          ),
        for (final v in visits)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VisitRow(visit: v, spot: state.spotById(v.placeId)),
          ),
      ],
    );
  }
}

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit, required this.spot});

  final Visit visit;
  final Spot? spot;

  @override
  Widget build(BuildContext context) {
    final date = MaterialLocalizations.of(context).formatMediumDate(visit.visitedAt);
    final footer = Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarMeter(value: visit.rating.toDouble(), size: 15),
              const SizedBox(width: 6),
              Text(
                visit.rating == 0 ? 'Not rated · $date' : date,
                style: const TextStyle(fontSize: 12, color: Palette.muted),
              ),
            ],
          ),
          if (visit.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '“${visit.notes}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontStyle: FontStyle.italic, color: Palette.inkSoft),
              ),
            ),
        ],
      ),
    );
    final edit = IconButton(
      tooltip: 'Rate & notes',
      onPressed: () => showVisitEditor(context, visit),
      icon: const Icon(Icons.edit_note_rounded, color: Palette.green),
    );

    if (spot != null) {
      return _SpotRow(spot: spot!, heroPrefix: 'visit', footer: footer, trailing: edit);
    }
    // the spot was removed from the catalog; keep the memory anyway
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: Palette.lineSoft),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.name,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Palette.ink),
                ),
                footer,
              ],
            ),
          ),
          edit,
        ],
      ),
    );
  }
}

/// Rate a visit: stars, our five dimension sliders, and notes. Five stars
/// earns a burst of confetti, like the web.
Future<void> showVisitEditor(BuildContext context, Visit visit) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _VisitEditor(visit: visit),
  );
}

class _VisitEditor extends StatefulWidget {
  const _VisitEditor({required this.visit});

  final Visit visit;

  @override
  State<_VisitEditor> createState() => _VisitEditorState();
}

class _VisitEditorState extends State<_VisitEditor> {
  late Visit _v = widget.visit;
  late final _notes = TextEditingController(text: widget.visit.notes);
  final _confetti = ConfettiController(duration: const Duration(milliseconds: 800));

  static const _labels = {
    'aesthetic': 'Aesthetic',
    'vibe': 'Vibe',
    'food': 'Food',
    'portions': 'Portions',
    'service': 'Service',
  };

  @override
  void dispose() {
    _notes.dispose();
    _confetti.dispose();
    super.dispose();
  }

  void _save() {
    AppScope.read(context).updateVisit(_v.copyWith(notes: _notes.text.trim()));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Stack(
        children: [
          SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_v.name, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    'Visited ${MaterialLocalizations.of(context).formatMediumDate(_v.visitedAt)}',
                    style: const TextStyle(color: Palette.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: EditableStars(
                      value: _v.rating,
                      size: 38,
                      onChanged: (r) {
                        if (r == 5) {
                          _confetti.play();
                          HapticFeedback.heavyImpact();
                        }
                        setState(() => _v = _v.copyWith(rating: r));
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final key in Visit.dims)
                    Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(
                            _labels[key]!,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Palette.inkSoft),
                          ),
                        ),
                        Expanded(
                          child: Slider(
                            value: _v.dim(key) ?? 0,
                            min: 0,
                            max: 5,
                            divisions: 10,
                            label: (_v.dim(key) ?? 0).toStringAsFixed(1),
                            onChanged: (x) => setState(() => _v = _v.copyWith(dims: {key: x})),
                          ),
                        ),
                        SizedBox(
                          width: 30,
                          child: Text(
                            _v.dim(key) == null ? '–' : _v.dim(key)!.toStringAsFixed(1),
                            textAlign: TextAlign.right,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    minLines: 2,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(hintText: 'Our notes — what to order, which table…'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              gravity: 0.3,
              colors: const [Palette.terracotta, Palette.amber, Palette.gold, Palette.sage, Palette.green],
            ),
          ),
        ],
      ),
    );
  }
}
