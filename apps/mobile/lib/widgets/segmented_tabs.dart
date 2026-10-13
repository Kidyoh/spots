import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/tokens.dart';

/// A floating segmented control: a cream capsule with a green thumb that
/// glides (with a little overshoot) to the selected segment.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({super.key, required this.labels, required this.index, required this.onChanged, this.counts});

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final List<int?>? counts;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: Palette.lineSoft),
        boxShadow: Shadows.card,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / labels.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutBack,
                left: w * index,
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    color: Palette.green,
                    borderRadius: BorderRadius.circular(Radii.pill),
                    boxShadow: [
                      BoxShadow(
                        color: Palette.green.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < labels.length; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (i != index) HapticFeedback.selectionClick();
                            onChanged(i);
                          },
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 220),
                              style: TextStyle(
                                fontFamily: 'Quicksand',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: i == index ? Palette.bg : Palette.inkSoft,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(labels[i], maxLines: 1, overflow: TextOverflow.fade, softWrap: false),
                                  ),
                                  if (counts?[i] case final c?) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      '$c',
                                      style: TextStyle(fontSize: 12, color: i == index ? Palette.gold : Palette.muted),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
