import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../super_trial/presentation/super_trial_screen.dart';
import '../application/ads_controller.dart';

// sc_fad12a43 at (10,10): PIL.convert('RGB').getpixel = (30,30,30).
const _adStage = Color(0xFF1E1E1E);
// sc_fad12a43 CONTINUE label #020638, snapped to palette navy #0F1845.
const _ctaInk = Color(0xFF0F1845);
// Existing archived creative, illustration only; native title/CTA overlaid.
const _houseStage = ArtRegion(
  'gap-house-ad',
  Rect.fromLTWH(0, 860, 1179, 1696),
);
const _openingStage = ArtRegion(
  'gap-house-ad-opening',
  Rect.fromLTWH(0, 860, 1179, 1696),
);

class AdScreen extends ConsumerStatefulWidget {
  const AdScreen({
    this.placement = 'LESSON_END_INTERSTITIAL',
    this.offerTrial = false,
    super.key,
  });
  final String placement;
  final bool offerTrial;
  @override
  ConsumerState<AdScreen> createState() => _AdScreenState();
}

class _AdScreenState extends ConsumerState<AdScreen>
    with WidgetsBindingObserver {
  bool muted = false;
  late final AdController _controller;
  @override
  void initState() {
    super.initState();
    _controller = ref.read(adControllerProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!ref.read(adsEligibleProvider)) {
        _leave(false);
        return;
      }
      ref.read(adControllerProvider.notifier).start(widget.placement);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(adControllerProvider.notifier);
    if (state == AppLifecycleState.resumed) {
      controller.resume();
    } else {
      controller.pause();
    }
  }

  @override
  void dispose() {
    _controller.pause();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _leave(bool rewarded) {
    if (context.canPop()) {
      context.pop(rewarded);
    } else {
      context.go('/home');
    }
  }

  Future<void> _finish() async {
    final rewarded = await ref.read(adControllerProvider.notifier).finish();
    if (!mounted || !rewarded) return;
    if (widget.offerTrial) {
      // Row 5: the Super trial interstitial (sc_e4a392e0); TRY opens the
      // existing plan screen, NO THANKS returns here.
      final accepted = await context.push<bool>(SuperTrialScreen.route);
      if (!mounted) return;
      if (accepted == true) {
        await context.push('/super');
        if (!mounted) return;
      }
    }
    _leave(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adControllerProvider);
    final ad = ref.watch(houseAdProvider);
    final eligible = ref.watch(adsEligibleProvider);
    final viewport = MediaQuery.sizeOf(context);
    final artHeight = viewport.height - MediaQuery.paddingOf(context).vertical;
    ref.listen(adsEligibleProvider, (_, next) {
      if (!next) _leave(false);
    });
    if (!eligible) return const Scaffold(backgroundColor: _adStage);
    return PopScope(
      canPop: state.seconds == 0 || state.error != null,
      child: Scaffold(
        backgroundColor: _adStage,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: artHeight * 860 / 2556,
                child: ClipPath(
                  clipper: _HouseCreativeClipper(hideCta: state.seconds == 0),
                  child: ReferenceArt(
                    state.seconds > 0 ? _openingStage : _houseStage,
                    width: viewport.width,
                    height: artHeight * 1696 / 2556,
                  ),
                ),
              ),
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        if (state.seconds > 0)
                          Semantics(
                            label: ad.countdownLabel(state.seconds),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: Center(
                                child: Text(
                                  '${state.seconds}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          // The final frame has no close X (sc_fad12a43);
                          // CONTINUE is the only way on.
                          const SizedBox(width: 48, height: 48),
                        const Spacer(),
                        IconButton(
                          tooltip: muted ? ad.unmuteLabel : ad.muteLabel,
                          onPressed: () => setState(() => muted = !muted),
                          icon: Icon(
                            muted
                                ? Icons.volume_off_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 98, 24, 16),
                      child: Column(
                        children: [
                          Text(
                            state.seconds > 0 ? ad.title : ad.body,
                            textAlign: TextAlign.center,
                            style: headingStyle.copyWith(
                              color: Colors.white,
                              fontSize: 25,
                              height: 1.2,
                            ),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 20),
                            Text(
                              state.error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                            TextButton(
                              onPressed: state.ready
                                  ? _finish
                                  : () => ref
                                        .read(adControllerProvider.notifier)
                                        .start(widget.placement),
                              child: Text(ad.retryLabel),
                            ),
                            TextButton(
                              onPressed: () => _leave(false),
                              child: Text(ad.closeLabel),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (state.seconds == 0 && state.ready)
                Positioned(
                  left: viewport.width * 48 / 1179,
                  right: viewport.width * 48 / 1179,
                  top: artHeight * 2286 / 2556,
                  child: ReferenceButton(
                    label: ad.cta,
                    backgroundColor: ReferenceColors.surface,
                    edgeColor: ReferenceColors.border,
                    foregroundColor: _ctaInk,
                    minHeight: 44,
                    onPressed: state.busy ? null : _finish,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Source CTA and OS chrome are cut out before painting the illustration.
/// Their source text is never drawn; the live CTA is a ReferenceButton.
class _HouseCreativeClipper extends CustomClipper<Path> {
  const _HouseCreativeClipper({required this.hideCta});
  final bool hideCta;
  @override
  Path getClip(Size size) {
    final sx = size.width / 1179;
    final sy = size.height / 1696;
    final art = Path()..addRect(Offset.zero & size);
    final controls = Path()
      ..addRect(Rect.fromLTWH(0, (2510 - 860) * sy, size.width, 46 * sy));
    if (hideCta) {
      controls.addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(48 * sx, (2286 - 860) * sy, 1083 * sx, 132 * sy),
          const Radius.circular(14),
        ),
      );
    }
    return Path.combine(PathOperation.difference, art, controls);
  }

  @override
  bool shouldReclip(_HouseCreativeClipper oldClipper) =>
      oldClipper.hideCta != hideCta;
}
