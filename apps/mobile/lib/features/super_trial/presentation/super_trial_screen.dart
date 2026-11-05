import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/cocenglish_brand.dart';
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
class SuperTrialScreen extends ConsumerStatefulWidget {
  const SuperTrialScreen({super.key});
  static const route = '/super/trial';

  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  @override
  ConsumerState<SuperTrialScreen> createState() => _SuperTrialScreenState();
}

class _SuperTrialScreenState extends ConsumerState<SuperTrialScreen> {
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

  bool _submitting = false;

  Future<void> _answer(SuperTrialChoice choice) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await ref.read(superTrialRepositoryProvider).record(choice);
    if (!mounted) return;
    final accepted = choice == SuperTrialChoice.accepted;
    if (context.canPop()) {
      context.pop(accepted);
    } else {
      context.go(accepted ? '/super' : '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = ref.watch(superTrialOfferProvider);
    final platform =
        SuperTrialScreen.debugPlatformOverride ??
        (kIsWeb ? TargetPlatform.android : defaultTargetPlatform);
    if (platform == TargetPlatform.android) {
      return _buildAndroid(offer);
    }
    return _buildIos(offer);
  }

  Widget _popAware(Widget child) => PopScope(
    canPop: !_submitting,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop && result == null) {
        ref
            .read(superTrialRepositoryProvider)
            .record(SuperTrialChoice.declined);
      }
    },
    child: child,
  );

  Widget _buildAndroid(SuperTrialOffer offer) {
    return _popAware(
      Scaffold(
        backgroundColor: _ctaInk,
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF24504A), Color(0xFF183875), Color(0xFF4F2276)],
              stops: [0, .48, 1],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                final sourceSized = box.maxHeight >= 680 && textScale <= 1.3;
                final topSpace = sourceSized ? 125.0 : 24.0;
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(15, topSpace, 15, 20),
                        child: const Column(
                          children: [
                            Text(
                              'Progress faster in your English course with Super!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.08,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 28),
                            AndroidSuperComparison(),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: Color(0x38FFFFFF)),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ReferenceButton(
                            key: const ValueKey('super-trial-accept'),
                            label: offer.acceptLabel,
                            backgroundColor: Colors.white,
                            edgeColor: _ctaEdge,
                            foregroundColor: _ctaInk,
                            minHeight: 50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            onPressed: _submitting
                                ? null
                                : () => _answer(SuperTrialChoice.accepted),
                          ),
                          TextButton(
                            key: const ValueKey('super-trial-decline'),
                            onPressed: _submitting
                                ? null
                                : () => _answer(SuperTrialChoice.declined),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              minimumSize: const Size(120, 44),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                offer.declineLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: .6,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIos(SuperTrialOffer offer) {
    return _popAware(
      Scaffold(
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
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF0A484C),
                          Color(0xFF122D79),
                          Color(0xFF531972),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: map(_bubble),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2055A4),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                fit(
                  const Rect.fromLTRB(300, 1130, 950, 1800),
                  const CocEnglishMark(size: 220),
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
                    onPressed: _submitting
                        ? null
                        : () => _answer(SuperTrialChoice.accepted),
                  ),
                ),
                Positioned.fromRect(
                  rect: map(_decline, bottom: true),
                  child: Center(
                    child: TextButton(
                      key: const ValueKey('super-trial-decline'),
                      onPressed: _submitting
                          ? null
                          : () => _answer(SuperTrialChoice.declined),
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

class AndroidSuperComparison extends StatelessWidget {
  const AndroidSuperComparison({super.key});

  static const _features = [
    ('Learning content', true),
    ('Unlimited Hearts', false),
    ('Personalized Practice', false),
    ('Unlimited Legendary', false),
    ('No ads', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Free and Super feature comparison',
      child: Container(
        key: const ValueKey('android-super-comparison'),
        constraints: const BoxConstraints(maxWidth: 400),
        child: LayoutBuilder(
          builder: (context, box) {
            // Mobbin Super 01 (360 px): Free column centred at x 224, Super
            // column 82 px wide with a 14 % white tint from the 34 px header
            // to the last row, rows on a 48 px pitch with dividers only
            // between rows (none under the header or after the last row).
            const freeWidth = 78.0;
            final superWidth = (box.maxWidth * .25).clamp(72.0, 92.0);
            return Stack(
              children: [
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: superWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x24FFFFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                Column(
                  children: [
                    SizedBox(
                      height: 33,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(child: SizedBox()),
                          const SizedBox(
                            width: freeWidth,
                            child: Padding(
                              padding: EdgeInsets.zero,
                              child: Text(
                                textAlign: TextAlign.center,
                                'FREE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: superWidth,
                            child: Center(
                              heightFactor: 1,
                              child: Semantics(
                                label: 'Super',
                                image: true,
                                child: const ReferenceArt(
                                  ArtRegion(
                                    'android-super-offer',
                                    Rect.fromLTWH(268, 255, 72, 31),
                                  ),
                                  key: ValueKey('android-super-badge'),
                                  width: 72,
                                  height: 31,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (final (index, feature) in _features.indexed)
                      _ComparisonRow(
                        divider: index > 0,
                        label: feature.$1,
                        freeIncluded: feature.$2,
                        freeWidth: freeWidth,
                        superWidth: superWidth,
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  const _ComparisonRow({
    required this.divider,
    required this.label,
    required this.freeIncluded,
    required this.freeWidth,
    required this.superWidth,
  });

  final bool divider;
  final String label;
  final bool freeIncluded;
  final double freeWidth;
  final double superWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '$label: ${freeIncluded ? 'included' : 'not included'} with Free, included with Super',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            border: divider
                ? const Border(top: BorderSide(color: Color(0x2EFFFFFF)))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: freeWidth,
                child: freeIncluded ? const _Check() : null,
              ),
              SizedBox(width: superWidth, child: const _Check()),
            ],
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check();

  @override
  Widget build(BuildContext context) => const Center(
    child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
  );
}
