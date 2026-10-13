import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/super_trial_provider.dart';
import '../domain/super_trial_offer.dart';

/// Super free-trial interstitial after a Free user's ad (audit row 5,
/// Gummble sc_e4a392e0 · `refs/gap/earn_heart_08`).
///
/// The cleaned capture `gap-super-trial.png` paints the gradient, SUPER badge,
/// empty speech bubble and Duo; every string and both actions are native and
/// come from [SuperTrialRepository]. Geometry is the capture's, mapped through
/// the same cover transform as the art, so text lands inside the bubble on any
/// viewport. Pops `true` for TRY (caller opens the plan screen), `false` for
/// NO THANKS.
class SuperTrialScreen extends ConsumerWidget {
  const SuperTrialScreen({super.key});
  static const route = '/super/trial';

  // Capture size and measured rects (px in the 1179×2556 source).
  static const _source = Size(1179, 2556);
  static const _title = Rect.fromLTRB(200, 540, 979, 760);
  static const _bubble = Rect.fromLTRB(285, 860, 895, 1060);
  static const _footnote = Rect.fromLTRB(40, 1975, 1139, 2060);
  static const _button = Rect.fromLTRB(48, 2094, 1131, 2225);
  static const _decline = Rect.fromLTRB(40, 2262, 1139, 2416);

  // Palette (docs/design/qa/palette_from_refs.json): bubble highlight
  // (38,240,107) → #2EE79F; CTA label (1,4,55) → #0F1845; CTA edge
  // (160,143,185) → #A48DC4.
  static const _highlight = Color(0xFF2EE79F);
  static const _ctaInk = Color(0xFF0F1845);
  static const _ctaEdge = Color(0xFFA48DC4);

  Future<void> _answer(
    BuildContext context,
    WidgetRef ref,
    SuperTrialChoice choice,
  ) async {
    await ref.read(superTrialRepositoryProvider).record(choice);
    if (!context.mounted) return;
    final accepted = choice == SuperTrialChoice.accepted;
    if (context.canPop()) {
      context.pop(accepted);
    } else {
      context.go(accepted ? '/super' : '/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offer = ref.watch(superTrialOfferProvider);
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) {
          ref
              .read(superTrialRepositoryProvider)
              .record(SuperTrialChoice.declined);
        }
      },
      child: Scaffold(
        backgroundColor: _ctaInk,
        body: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            final s =
                (size.width / _source.width) > (size.height / _source.height)
                ? size.width / _source.width
                : size.height / _source.height;
            final crop = Offset(
              (_source.width - size.width / s) / 2,
              (_source.height - size.height / s) / 2,
            );
            // Title and bubble follow the art; the footnote and actions keep
            // their distance from the bottom edge, so a short viewport that
            // crops the art vertically never pushes them off screen.
            Rect map(Rect r, {bool bottom = false}) {
              final dy = bottom ? _source.height - size.height / s : crop.dy;
              return Rect.fromLTRB(
                (r.left - crop.dx) * s,
                (r.top - dy) * s,
                (r.right - crop.dx) * s,
                (r.bottom - dy) * s,
              );
            }

            Widget fit(Rect r, Widget child, {bool bottom = false}) =>
                Positioned.fromRect(
                  rect: map(r, bottom: bottom),
                  child: Center(
                    child: FittedBox(fit: BoxFit.scaleDown, child: child),
                  ),
                );
            final button = map(_button, bottom: true);
            return Stack(
              children: [
                Positioned.fill(
                  child: ReferenceArt(
                    ArtRegion(
                      'gap-super-trial',
                      Rect.fromLTWH(
                        crop.dx,
                        crop.dy,
                        size.width / s,
                        size.height / s,
                      ),
                    ),
                    width: size.width,
                    height: size.height,
                  ),
                ),
                fit(
                  _title,
                  SizedBox(
                    width: map(_title).width,
                    child: Text(
                      offer.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 66 * s,
                        height: 84 / 66,
                      ),
                    ),
                  ),
                ),
                fit(
                  _bubble,
                  SizedBox(
                    width: map(_bubble).width,
                    child: Semantics(
                      label: offer.bubbleText,
                      child: ExcludeSemantics(
                        child: Text.rich(
                          TextSpan(
                            text: offer.bubbleLead,
                            children: [
                              TextSpan(
                                text: offer.bubbleHighlight,
                                style: const TextStyle(
                                  color: _highlight,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: offer.bubbleTail),
                            ],
                          ),
                          key: const ValueKey('super-trial-bubble'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 57 * s,
                            height: 84 / 57,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                fit(
                  _footnote,
                  Text(
                    offer.footnote,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 45 * s),
                  ),
                  bottom: true,
                ),
                Positioned(
                  left: button.left,
                  top: button.top,
                  width: button.width,
                  child: ReferenceButton(
                    key: const ValueKey('super-trial-accept'),
                    label: offer.acceptLabel,
                    backgroundColor: Colors.white,
                    edgeColor: _ctaEdge,
                    foregroundColor: _ctaInk,
                    minHeight: button.height,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    textStyle: TextStyle(fontSize: 50 * s),
                    onPressed: () =>
                        _answer(context, ref, SuperTrialChoice.accepted),
                  ),
                ),
                Positioned.fromRect(
                  rect: map(_decline, bottom: true),
                  child: Center(
                    child: TextButton(
                      key: const ValueKey('super-trial-decline'),
                      onPressed: () =>
                          _answer(context, ref, SuperTrialChoice.declined),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        minimumSize: const Size(120, 48),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          offer.declineLabel,
                          style: TextStyle(
                            fontSize: 47 * s,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
