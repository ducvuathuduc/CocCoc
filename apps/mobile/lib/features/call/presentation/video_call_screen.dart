import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../application/call_controller.dart';
import '../domain/call_models.dart';
import 'call_visuals.dart';
import 'call_widgets.dart';

const _title = TextStyle(
  fontFamily: 'DuolingoSans',
  fontWeight: FontWeight.w700,
  color: CallColors.white,
);

/// Reference frame height (1180×2556 @ 430 wide) used to place elements by
/// fraction so the layout follows the refs on any phone height.
const _refHeight = 931.0;

/// Max video call with Lily: ringing → in-call → XP → review → upsell.
class VideoCallScreen extends ConsumerStatefulWidget {
  const VideoCallScreen({
    this.partnerId = 'lily',
    this.onExit,
    this.onUpgrade,
    super.key,
  });
  final String partnerId;
  final VoidCallback? onExit;
  final VoidCallback? onUpgrade;

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref
            .read(callControllerProvider.notifier)
            .start(partnerId: widget.partnerId);
      }
    });
  }

  void _exit() {
    if (widget.onExit != null) return widget.onExit!();
    final router = GoRouter.maybeOf(context);
    if (router == null) {
      Navigator.maybePop(context);
    } else if (router.canPop()) {
      router.pop();
    } else {
      router.go('/practice');
    }
  }

  void _upgrade() {
    if (widget.onUpgrade != null) return widget.onUpgrade!();
    final router = GoRouter.maybeOf(context);
    if (router == null) return _exit();
    router.push('/max');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(callControllerProvider);
    final controller = ref.read(callControllerProvider.notifier);
    final reduced = CallMotion.reduced(context);
    final session = state.session;
    final Widget body;
    if (state.error != null) {
      body = _CallError(message: state.error!, onClose: _exit);
    } else if (session == null) {
      body = const SizedBox.expand(key: ValueKey('call-loading'));
    } else {
      body = switch (state.phase) {
        CallPhase.idle || CallPhase.ringing => _RingingView(
          key: const ValueKey('phase-ringing'),
          session: session,
          onHangUp: controller.hangUp,
        ),
        CallPhase.connected => _InCallView(
          key: const ValueKey('phase-connected'),
          state: state,
          onMic: controller.pressMic,
          onHangUp: controller.hangUp,
        ),
        CallPhase.ended => _EndedView(
          key: const ValueKey('phase-ended'),
          session: session,
          onContinue: controller.advance,
        ),
        CallPhase.review => _ReviewView(
          key: const ValueKey('phase-review'),
          state: state,
          onContinue: controller.advance,
        ),
        CallPhase.upsell => _UpsellView(
          key: const ValueKey('phase-upsell'),
          session: session,
          onUpgrade: _upgrade,
          onNoThanks: _exit,
        ),
      };
    }
    return Scaffold(
      backgroundColor: CallColors.night,
      body: AnimatedSwitcher(
        duration: reduced ? Duration.zero : CallMotion.page,
        switchInCurve: CallMotion.pageCurve,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: .96, end: 1.0).animate(animation),
            child: child,
          ),
        ),
        child: body,
      ),
    );
  }
}

/// Positions [child] with its top at [refTop] (in 430×931 ref units).
class _At extends StatelessWidget {
  const _At({required this.refTop, required this.child});
  final double refTop;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => Padding(
      padding: EdgeInsets.only(top: c.maxHeight * refTop / _refHeight),
      child: Align(alignment: Alignment.topCenter, child: child),
    ),
  );
}

class _RingingView extends StatelessWidget {
  const _RingingView({
    required this.session,
    required this.onHangUp,
    super.key,
  });
  final CallSession session;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const _At(
        refTop: 129,
        child: ReferenceArt(CallArt.maxWordmark, width: 162, height: 86),
      ),
      const Positioned(left: 37, top: 185, child: GlowBars(heights: [57])),
      const Positioned(
        right: 37,
        top: 173,
        child: GlowBars(heights: [20, 48]),
      ),
      const _At(
        refTop: 369 - 47,
        child: RingingAvatar(art: CallArt.ringingAvatar),
      ),
      _At(
        refTop: 586,
        child: Semantics(
          liveRegion: true,
          child: Text(
            session.copy.callingLabel,
            style: _title.copyWith(fontSize: 30),
          ),
        ),
      ),
      _At(refTop: 804, child: HangUpButton(onPressed: onHangUp)),
    ],
  );
}

class _InCallView extends StatelessWidget {
  const _InCallView({
    required this.state,
    required this.onMic,
    required this.onHangUp,
    super.key,
  });
  final CallState state;
  final VoidCallback onMic;
  final VoidCallback onHangUp;

  @override
  Widget build(BuildContext context) {
    final reduced = CallMotion.reduced(context);
    final copy = state.session!.copy;
    return LayoutBuilder(
      builder: (context, c) {
        final videoHeight = c.maxHeight * 777 / _refHeight;
        return Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: videoHeight,
              child: AnimatedSwitcher(
                duration: reduced ? Duration.zero : CallMotion.caption,
                child: ReferenceArt(
                  state.listening ? CallArt.videoListening : CallArt.videoTalking,
                  key: ValueKey(state.listening),
                  width: c.maxWidth,
                  height: videoHeight,
                ),
              ),
            ),
            Positioned(
              top: videoHeight,
              left: 0,
              right: 0,
              bottom: 0,
              child: const ColoredBox(color: CallColors.dock),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: c.maxHeight - videoHeight + 16,
              child: Center(
                child: state.listening
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: CallColors.dock.withValues(alpha: .82),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const ListeningWaveform(),
                            const SizedBox(width: 10),
                            Text(
                              copy.listeningLabel,
                              style: _title.copyWith(
                                fontSize: 17,
                                color: CallColors.cyan,
                              ),
                            ),
                          ],
                        ),
                      )
                    : CallCaption(line: state.caption),
              ),
            ),
            Positioned(
              top: c.maxHeight * 804 / _refHeight,
              left: 0,
              right: 0,
              child: Center(child: HangUpButton(onPressed: onHangUp)),
            ),
            Positioned(
              top: c.maxHeight * 804 / _refHeight + 3,
              left: 40,
              child: CallMicButton(
                enabled: state.awaitingLearner && !state.listening,
                listening: state.listening,
                onPressed: onMic,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EndedView extends StatelessWidget {
  const _EndedView({
    required this.session,
    required this.onContinue,
    super.key,
  });
  final CallSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const Positioned(left: 20, top: 395, child: GlowBars(heights: [57])),
      const Positioned(
        right: 37,
        top: 360,
        child: GlowBars(heights: [20, 48]),
      ),
      const _At(
        refTop: 329,
        child: ClipOval(
          child: ReferenceArt(CallArt.earnedAvatar, width: 165, height: 169),
        ),
      ),
      _At(
        refTop: 518,
        child: Text(
          session.copy.earnedLabel,
          style: _title.copyWith(fontSize: 30),
        ),
      ),
      Positioned(
        left: 12,
        right: 12,
        bottom: 49,
        child: GlowButton(
          label: session.copy.continueLabel,
          onPressed: onContinue,
        ),
      ),
    ],
  );
}

class _ReviewView extends StatelessWidget {
  const _ReviewView({required this.state, required this.onContinue, super.key});
  final CallState state;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final session = state.session!;
    final lines = state.spoken;
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 62, 20, 36),
            child: Text(
              session.copy.reviewTitle,
              textAlign: TextAlign.center,
              style: _title.copyWith(fontSize: 28),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const ValueKey('review-list'),
              padding: const EdgeInsets.fromLTRB(17, 0, 17, 16),
              itemCount: lines.length,
              itemBuilder: (context, i) => ReviewBubble(
                line: lines[i],
                learnerInitial: session.learnerInitial,
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: CallColors.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 22, 12, 43),
            child: GlowButton(
              label: session.copy.continueLabel,
              onPressed: onContinue,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsellView extends StatelessWidget {
  const _UpsellView({
    required this.session,
    required this.onUpgrade,
    required this.onNoThanks,
    super.key,
  });
  final CallSession session;
  final VoidCallback onUpgrade;
  final VoidCallback onNoThanks;

  @override
  Widget build(BuildContext context) {
    final copy = session.copy;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: 73,
          right: 26,
          child: Semantics(
            label: copy.maxBadge,
            child: const ReferenceArt(CallArt.maxBadge, width: 75, height: 26),
          ),
        ),
        _At(
          refTop: 142,
          child: _PhoneMock(
            kicker: copy.phoneKicker,
            name: session.partnerName,
          ),
        ),
        _At(
          refTop: 646,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: copy.upsellLead),
                  TextSpan(
                    text: copy.upsellHighlight,
                    style: const TextStyle(color: CallColors.lily),
                  ),
                  TextSpan(text: copy.upsellTail),
                ],
              ),
              textAlign: TextAlign.center,
              style: _title.copyWith(fontSize: 23, height: 1.35),
            ),
          ),
        ),
        Positioned(
          left: 17,
          right: 17,
          bottom: 116,
          child: CallSolidButton(label: copy.upgradeLabel, onPressed: onUpgrade),
        ),
        Positioned(
          left: 17,
          right: 17,
          bottom: 58,
          child: CallSolidButton(
            label: copy.noThanksLabel,
            filled: false,
            onPressed: onNoThanks,
          ),
        ),
      ],
    );
  }
}

class _PhoneMock extends StatelessWidget {
  const _PhoneMock({required this.kicker, required this.name});
  final String kicker;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: 256,
    height: 466,
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: CallColors.phoneScreen,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: CallColors.phoneFrame, width: 4),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: CallColors.lily,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Text(kicker, style: _title.copyWith(fontSize: 14)),
            Text(name, style: _title.copyWith(fontSize: 34, height: 1.1)),
            const Spacer(),
            const ReferenceArt(CallArt.phoneFace, width: 236, height: 336),
          ],
        ),
      ),
    ),
  );
}

class _CallError extends StatelessWidget {
  const _CallError({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message, style: _title.copyWith(fontSize: 18)),
        const SizedBox(height: 24),
        HangUpButton(onPressed: onClose),
      ],
    ),
  );
}
