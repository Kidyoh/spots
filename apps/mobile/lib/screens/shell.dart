import 'dart:async';

import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/tokens.dart';
import '../widgets/floating_nav_bar.dart';
import 'discover_screen.dart';
import 'events_screen.dart';
import 'near_screen.dart';
import 'saved_screen.dart';

/// Four tabs under one floating pill bar. Every tab stays mounted (the deck
/// keeps its place, the map keeps its camera); switching cross-fades with a
/// small lift so it feels like one surface rather than separate pages.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  StreamSubscription<String>? _toasts;
  final _visited = <int>{0};

  static const _tabs = [DiscoverScreen(), EventsScreen(), NearScreen(), SavedScreen()];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _toasts ??= AppScope.read(context).toasts.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            duration: const Duration(milliseconds: 1800),
            // clear the tab bar, unless a pushed page (no tab bar) is on top
            margin: EdgeInsets.fromLTRB(
              24,
              0,
              24,
              ModalRoute.of(context)?.isCurrent ?? true ? navClearance(context) : 24,
            ),
          ),
        );
    });
  }

  @override
  void dispose() {
    _toasts?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final tab = state.tab;
    _visited.add(tab);
    final upcoming = state.happenings?.length ?? 0;

    return PopScope(
      // back from another tab returns to Discover before leaving the app
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) state.setTab(0);
      },
      child: Scaffold(
        backgroundColor: Palette.bg,
        extendBody: true,
        body: Stack(
          children: [
            for (var i = 0; i < _tabs.length; i++)
              // lazily build a tab the first time it's opened (the map and
              // its tiles shouldn't load until someone asks for them)
              if (_visited.contains(i)) _TabLayer(key: ValueKey(i), active: i == tab, child: _tabs[i]),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 14,
              child: Center(
                child: FloatingNavBar(
                  index: tab,
                  onTap: state.setTab,
                  items: [
                    const NavItem(Icons.style_outlined, Icons.style_rounded, 'Discover'),
                    NavItem(Icons.event_outlined, Icons.event_rounded, 'Events', badge: upcoming),
                    const NavItem(Icons.near_me_outlined, Icons.near_me_rounded, 'Near me'),
                    NavItem(
                      Icons.favorite_border_rounded,
                      Icons.favorite_rounded,
                      'Saved',
                      badge: state.savedIds.length,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLayer extends StatelessWidget {
  const _TabLayer({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // TickerMode sits inside the fade so the fade itself still runs out.
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.015),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          child: TickerMode(
            enabled: active,
            child: HeroMode(
              enabled: active,
              child: ExcludeSemantics(excluding: !active, child: child),
            ),
          ),
        ),
      ),
    );
  }
}
