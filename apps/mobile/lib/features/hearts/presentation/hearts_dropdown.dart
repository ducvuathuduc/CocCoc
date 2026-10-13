import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../../progress/application/preview_controller.dart';
import '../application/hearts_controller.dart';
import 'hearts_visuals.dart';

/// Hearts dropdown under the home stats bar (Gummble sc_901080ed,
/// refs/gap/hearts_dropdown.png, 1179 px = 393 dp so 3 px = 1 dp).
///
/// [anchor] is the stats bar's global rect; the panel hangs from its bottom
/// edge and the path below is dimmed. Taps outside the panel close it.
Future<void> showHeartsDropdown(BuildContext context, {Rect? anchor}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  final top = anchor?.bottom ?? MediaQuery.paddingOf(context).top + 64;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: ProviderScope.containerOf(
      context,
      listen: false,
    ).read(heartsContentProvider).closeHeartsLabel,
    barrierColor: Colors.transparent,
    transitionDuration: reduced ? Duration.zero : HeartsDropdownMotion.duration,
    pageBuilder: (dialogContext, _, _) => HeartsDropdown(top: top),
    transitionBuilder: (context, animation, _, child) =>
        _DropdownTransition(animation: animation, top: top, child: child),
  );
}

abstract final class HeartsDropdownMotion {
  // Panel drops from behind the stats bar while the scrim fades in.
  static const duration = Duration(milliseconds: 250);
  static const curve = Curves.easeOutCubic;
}

abstract final class HeartsDropdownColors {
  // sc_901080ed samples: scrim (10,1500) #7F7F7F over white, refilling heart
  // (755,450) #FFDFE0 with outer ring (755,410) #FFECEC→#FFEEEC, empty heart
  // (930,450) #DEDEDE→#DDDDDD, Super button (60,790) #26C1B0→#2CC1A9,
  // (590,790) #3486FF→#3881FE, (1120,790) #C064FF→#B06FFF; edge (590,870)
  // #2D7CE7→#207AF3, (1120,860) #A85CEB→#B056F0; disabled text #B0B0B0.
  static const scrim = Color(0xFF7F7F7F);
  static const refilling = Color(0xFFFFDFE0);
  static const refillingRing = Color(0xFFFFEEEC);
  static const empty = Color(0xFFDDDDDD);
  static const superTeal = Color(0xFF2CC1A9);
  static const superBlue = Color(0xFF3881FE);
  static const superPurple = Color(0xFFB06FFF);
  static const superEdgeBlue = Color(0xFF207AF3);
  static const superEdgePurple = Color(0xFFB056F0);
  static const disabledInk = Color(0xFFB0B0B0);
  static const disabledFill = Color(0xFFE5E5E5);
}

class _DropdownTransition extends StatelessWidget {
  const _DropdownTransition({
    required this.animation,
    required this.top,
    required this.child,
  });
  final Animation<double> animation;
  final double top;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final t = CurvedAnimation(
      parent: animation,
      curve: HeartsDropdownMotion.curve,
    );
    return Stack(
      children: [
        Positioned.fill(
          top: top,
          child: FadeTransition(
            opacity: t,
            // The ref path behind the panel is greyscale and dimmed by half.
            child: IgnorePointer(
              child: ClipRect(
                child: BackdropFilter(
                  filter: const ColorFilter.matrix([
                    .2126, .7152, .0722, 0, 0, //
                    .2126, .7152, .0722, 0, 0, //
                    .2126, .7152, .0722, 0, 0, //
                    0, 0, 0, 1, 0, //
                  ]),
                  child: ColoredBox(
                    color: HeartsDropdownColors.scrim.withValues(alpha: .5),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(
          top: top,
          // The panel is clipped at the stats bar so it slides out from
          // behind it rather than over it.
          child: ClipRect(
            child: AnimatedBuilder(
              animation: t,
              builder: (context, child) => FractionalTranslation(
                translation: Offset(0, (t.value - 1) * .6),
                child: child,
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

class HeartsDropdown extends ConsumerStatefulWidget {
  const HeartsDropdown({required this.top, super.key});
  final double top;
  @override
  ConsumerState<HeartsDropdown> createState() => _HeartsDropdownState();
}

class _HeartsDropdownState extends ConsumerState<HeartsDropdown> {
  bool busy = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    final content = ref.watch(heartsContentProvider);
    final state = ref.watch(heartsControllerProvider);
    final gems = ref.watch(previewWalletProvider);
    final cost = content.homeRefillCost;
    final full = state.balance >= state.capacity;
    final canRefill = !full && gems >= cost;
    final canPractice = state.balance == 0 && !busy;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: constraints.maxHeight * .9),
            child: SingleChildScrollView(
              child: Material(
                key: const ValueKey('hearts-dropdown'),
                color: ReferenceColors.surface,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Hairline under the stats bar with the caret over Hearts
                    // (sc_901080ed y 328 px, caret centre x 1068 px).
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      child: Divider(
                        height: 2,
                        thickness: 2,
                        color: HeartsDropdownColors.disabledFill,
                      ),
                    ),
                    Positioned(
                      top: -7,
                      right: 30,
                      child: CustomPaint(
                        size: const Size(14, 8),
                        painter: _CaretPainter(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: content.heartsCount(
                              state.balance,
                              state.capacity,
                            ),
                            child: ExcludeSemantics(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var i = 0; i < state.capacity; i++)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: _HeartSlot(
                                        filled: i < state.balance,
                                        refilling: i == state.balance && !full,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text.rich(
                            TextSpan(
                              text: full
                                  ? content.fullHeartsLabel
                                  : '${content.nextHeartLabel} ',
                              children: [
                                if (!full)
                                  TextSpan(
                                    text: state.countdown,
                                    style: const TextStyle(
                                      color: LearningColors.red,
                                    ),
                                  ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ReferenceColors.ink,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _DropButton(
                            key: const ValueKey('hearts-dropdown-super'),
                            gradient: const LinearGradient(
                              colors: [
                                HeartsDropdownColors.superTeal,
                                HeartsDropdownColors.superBlue,
                                HeartsDropdownColors.superPurple,
                              ],
                            ),
                            edgeGradient: const LinearGradient(
                              colors: [
                                HeartsDropdownColors.superTeal,
                                HeartsDropdownColors.superEdgeBlue,
                                HeartsDropdownColors.superEdgePurple,
                              ],
                            ),
                            leading: const _InfinityHeart(),
                            label: content.unlimitedHeartsAction,
                            labelColor: Colors.white,
                            trailing: Text(
                              content.trialLabel,
                              style: _label.copyWith(color: Colors.white),
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              context.push('/super');
                            },
                          ),
                          const SizedBox(height: 16),
                          _DropButton(
                            key: const ValueKey('hearts-dropdown-refill'),
                            color: ReferenceColors.surface,
                            edge: ReferenceColors.border,
                            outlined: true,
                            leading: const _RefillHeart(),
                            label: content.refillAction,
                            labelColor: canRefill
                                ? ReferenceColors.ink
                                : HeartsDropdownColors.disabledInk,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GreyWhenDisabled(
                                  enabled: canRefill,
                                  child: const ReferenceArt(
                                    LearningArt.gem,
                                    width: 18,
                                    height: 21,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '$cost',
                                  style: _label.copyWith(
                                    color: canRefill
                                        ? LearningColors.blue
                                        : HeartsDropdownColors.disabledInk,
                                  ),
                                ),
                              ],
                            ),
                            onPressed: canRefill
                                ? () {
                                    if (ref
                                        .read(heartsControllerProvider.notifier)
                                        .refill(cost)) {
                                      Navigator.pop(context);
                                    }
                                  }
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _DropButton(
                            key: const ValueKey('hearts-dropdown-practice'),
                            color: canPractice
                                ? ReferenceColors.surface
                                : HeartsDropdownColors.disabledFill,
                            edge: canPractice
                                ? ReferenceColors.border
                                : HeartsDropdownColors.disabledFill,
                            outlined: canPractice,
                            leading: Icon(
                              Icons.favorite_rounded,
                              size: 24,
                              color: canPractice
                                  ? LearningColors.red
                                  : HeartsDropdownColors.disabledInk,
                            ),
                            label: content.practiceAction,
                            labelColor: canPractice
                                ? ReferenceColors.ink
                                : HeartsDropdownColors.disabledInk,
                            onPressed: canPractice ? _practice : null,
                          ),
                          if (error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(error!, textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(context),
              child: Semantics(
                button: true,
                label: content.closeHeartsLabel,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _practice() async {
    final content = ref.read(heartsContentProvider);
    setState(() => busy = true);
    final started = await ref
        .read(heartsControllerProvider.notifier)
        .startPractice();
    if (!mounted) return;
    if (started) {
      Navigator.pop(context);
      context.push('/lesson/practice');
    } else {
      setState(() {
        busy = false;
        error = content.practiceError;
      });
    }
  }
}

const _label = TextStyle(
  fontSize: 15,
  fontWeight: FontWeight.w700,
  letterSpacing: .4,
);

class _CaretPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height);
    canvas.drawPath(path, Paint()..color = ReferenceColors.surface);
    canvas.drawPath(
      path,
      Paint()
        ..color = HeartsDropdownColors.disabledFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_CaretPainter oldDelegate) => false;
}

class _HeartSlot extends StatelessWidget {
  const _HeartSlot({required this.filled, required this.refilling});
  final bool filled, refilling;
  @override
  Widget build(BuildContext context) {
    if (filled) {
      return const ReferenceArt(LearningArt.heart, width: 35, height: 30);
    }
    if (!refilling) {
      return const Icon(
        Icons.favorite_rounded,
        size: 38,
        color: HeartsDropdownColors.empty,
      );
    }
    return const SizedBox(
      width: 42,
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 46,
            color: HeartsDropdownColors.refillingRing,
          ),
          Icon(Icons.favorite_rounded, size: 41, color: Colors.white),
          Icon(
            Icons.favorite_rounded,
            size: 35,
            color: HeartsDropdownColors.refilling,
          ),
          Positioned(
            left: 10,
            top: 10,
            child: CircleAvatar(radius: 4, backgroundColor: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _InfinityHeart extends StatelessWidget {
  const _InfinityHeart();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28,
    height: 26,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.favorite_rounded, size: 28, color: Colors.white),
        Padding(
          padding: EdgeInsets.only(bottom: 3),
          child: Icon(
            Icons.all_inclusive_rounded,
            size: 15,
            color: HeartsDropdownColors.superTeal,
          ),
        ),
      ],
    ),
  );
}

class _RefillHeart extends StatelessWidget {
  const _RefillHeart();
  @override
  Widget build(BuildContext context) => const SizedBox(
    width: 28,
    height: 26,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Icon(
          Icons.favorite_rounded,
          size: 30,
          color: HeartsDropdownColors.refilling,
        ),
        Icon(Icons.favorite_rounded, size: 26, color: Colors.white),
        Icon(Icons.favorite_rounded, size: 20, color: LearningColors.red),
      ],
    ),
  );
}

/// Full-width 3D row button: 52 dp face + 4 dp edge (sc_901080ed 710–878 px).
class _DropButton extends StatefulWidget {
  const _DropButton({
    required this.leading,
    required this.label,
    required this.labelColor,
    this.trailing,
    this.color,
    this.edge,
    this.gradient,
    this.edgeGradient,
    this.outlined = false,
    this.onPressed,
    super.key,
  });
  final Widget leading;
  final Widget? trailing;
  final String label;
  final Color labelColor;
  final Color? color, edge;
  final Gradient? gradient, edgeGradient;
  final bool outlined;
  final VoidCallback? onPressed;
  @override
  State<_DropButton> createState() => _DropButtonState();
}

class _DropButtonState extends State<_DropButton> {
  bool _pressed = false;
  void _press(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _pressed ? 0.0 : 4.0;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 100);
    final radius = BorderRadius.circular(16);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: enabled ? (_) => _press(true) : null,
        onTapUp: enabled ? (_) => _press(false) : null,
        onTapCancel: () => _press(false),
        child: ExcludeSemantics(
          child: AnimatedContainer(
            duration: duration,
            margin: EdgeInsets.only(top: 4 - depth),
            padding: EdgeInsets.only(bottom: depth),
            decoration: BoxDecoration(
              borderRadius: radius,
              color: widget.edgeGradient == null ? widget.edge : null,
              gradient: widget.edgeGradient,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 52),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: radius,
                color: widget.gradient == null ? widget.color : null,
                gradient: widget.gradient,
                border: widget.outlined
                    ? Border.all(color: ReferenceColors.border, width: 2)
                    : null,
              ),
              child: Row(
                children: [
                  widget.leading,
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: _label.copyWith(color: widget.labelColor),
                    ),
                  ),
                  if (widget.trailing case final trailing?) ...[
                    const SizedBox(width: 8),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
