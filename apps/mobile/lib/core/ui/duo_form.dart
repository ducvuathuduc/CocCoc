import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Form colours sampled with PIL getpixel from docs/design/references
/// (listed in docs/design/qa/palette_from_refs.json per_screen):
/// - blue/blueEdge: login/04.png (300,704)/(300,836)
/// - red/redEdge: delete/05.png (300,2096)/(300,2228)
/// - fieldFill/fieldBorder: signup/03.png (600,580)/(600,572)
/// - errorText: signup/07.png crop (40,870,500,920) (also used for the icon)
/// - check: signup/03.png crop (1020,630,1080,680)
/// - link: delete/02.png crop (520,1380,1020,1440) = #0B8AFB; nearest palette #1080FF
/// - countdown: delete/02.png crop (300,2300,900,2360)
abstract final class DuoFormColors {
  static const blue = Color(0xFF1CB0F6);
  static const blueEdge = Color(0xFF1899D6);
  static const red = Color(0xFFFF4B4C);
  static const redEdge = Color(0xFFC93A37);
  static const redText = Color(0xFFFB4D4E);
  static const fieldFill = Color(0xFFFAF7FA);
  static const fieldBorder = Color(0xFFE7E5E7);
  static const errorText = Color(0xFFE95357);
  static const errorIcon = errorText;
  static const check = Color(0xFF2AB1F5);
  static const link = Color(0xFF1080FF);
  static const countdown = Color(0xFFB2AFB2);
  static const ink = Color(0xFF4D4B4E);
  static const body = Color(0xFF7A777A);
  static const hint = Color(0xFFB0AEB0);
  static const surface = Color(0xFFFFFDFE);
}

/// Duolingo motion timings (ms) used by auth/account forms.
abstract final class DuoFormMotion {
  static const focus = Duration(milliseconds: 150);
  static const shake = Duration(milliseconds: 420);
  static const page = Duration(milliseconds: 260);
  static const sheet = Duration(milliseconds: 280);

  static Duration of(BuildContext context, Duration value) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true
      ? Duration.zero
      : value;
}

/// Horizontal error shake. Bump [trigger] to replay. Static when
/// animations are disabled.
class DuoShake extends StatefulWidget {
  const DuoShake({required this.trigger, required this.child, super.key});
  final int trigger;
  final Widget child;
  @override
  State<DuoShake> createState() => _DuoShakeState();
}

class _DuoShakeState extends State<DuoShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: DuoFormMotion.shake,
  );
  @override
  void didUpdateWidget(DuoShake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) {
      if (MediaQuery.maybeDisableAnimationsOf(context) == true) return;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = _c.value;
      final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// Rounded grey field container with animated focus border; children are
/// separated by dividers (single field = one child).
class DuoFieldGroup extends StatefulWidget {
  const DuoFieldGroup({
    required this.children,
    this.color = DuoFormColors.fieldFill,
    this.error = false,
    super.key,
  });
  final List<Widget> children;
  final Color color;
  final bool error;
  @override
  State<DuoFieldGroup> createState() => _DuoFieldGroupState();
}

class _DuoFieldGroupState extends State<DuoFieldGroup> {
  bool _focused = false;
  @override
  Widget build(BuildContext context) {
    final border = widget.error
        ? DuoFormColors.errorText
        : _focused
        ? DuoFormColors.blue
        : DuoFormColors.fieldBorder;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: DuoFormMotion.of(context, DuoFormMotion.focus),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: 2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 2,
                      thickness: 2,
                      color: DuoFormColors.fieldBorder,
                    ),
                  widget.children[i],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Borderless input row for use inside [DuoFieldGroup].
class DuoInput extends StatefulWidget {
  const DuoInput({
    required this.value,
    required this.hint,
    required this.onChanged,
    this.fieldKey,
    this.keyboardType,
    this.obscure = false,
    this.onToggleObscure,
    this.trailing,
    this.enabled = true,
    this.autofillHints,
    this.textInputAction,
    this.onSubmitted,
    this.autofocus = false,
    super.key,
  });
  final String value, hint;
  final ValueChanged<String> onChanged;
  final Key? fieldKey;
  final TextInputType? keyboardType;
  final bool obscure, enabled, autofocus;
  final VoidCallback? onToggleObscure;
  final Widget? trailing;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  @override
  State<DuoInput> createState() => _DuoInputState();
}

class _DuoInputState extends State<DuoInput> {
  late final TextEditingController _c = TextEditingController(
    text: widget.value,
  );
  @override
  void didUpdateWidget(DuoInput old) {
    super.didUpdateWidget(old);
    if (_c.text != widget.value) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    key: widget.fieldKey,
    controller: _c,
    onChanged: widget.onChanged,
    keyboardType: widget.keyboardType,
    obscureText: widget.obscure,
    autocorrect: false,
    enableSuggestions: false,
    enabled: widget.enabled,
    autofocus: widget.autofocus,
    autofillHints: widget.autofillHints,
    textInputAction: widget.textInputAction,
    onSubmitted: widget.onSubmitted,
    style: const TextStyle(fontSize: 19, height: 1.1, color: DuoFormColors.ink),
    decoration: InputDecoration(
      constraints: const BoxConstraints(minHeight: 54),
      hintText: widget.hint,
      hintStyle: const TextStyle(color: DuoFormColors.hint),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      suffixIcon:
          widget.trailing ??
          (widget.onToggleObscure == null
              ? null
              : IconButton(
                  tooltip: widget.obscure
                      ? 'Show ${widget.hint}'
                      : 'Hide ${widget.hint}',
                  onPressed: widget.onToggleObscure,
                  icon: Icon(
                    widget.obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: DuoFormColors.blue,
                    size: 26,
                  ),
                )),
    ),
  );
}

/// Inline red error text (Duolingo signup email error).
class DuoFieldError extends StatelessWidget {
  const DuoFieldError(this.message, {super.key});
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        message,
        style: const TextStyle(fontSize: 15, color: DuoFormColors.errorText),
      ),
    ),
  );
}

/// Bottom sheet that slides up with Duolingo grabber; zero-duration
/// when animations are disabled.
Future<T?> showDuoSheet<T>(BuildContext context, WidgetBuilder builder) {
  final reduce = MediaQuery.maybeDisableAnimationsOf(context) == true;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: DuoFormColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    sheetAnimationStyle: AnimationStyle(
      duration: reduce ? Duration.zero : DuoFormMotion.sheet,
      reverseDuration: reduce ? Duration.zero : DuoFormMotion.sheet,
      curve: Curves.easeOutCubic,
    ),
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: builder(context),
      ),
    ),
  );
}

/// Page slide transition (incoming from right, outgoing to left) for step
/// based flows. Respects reduced motion.
class DuoStepSwitcher extends StatelessWidget {
  const DuoStepSwitcher({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: DuoFormMotion.of(context, DuoFormMotion.page),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.topCenter,
      children: [...previous, ?current],
    ),
    transitionBuilder: (child, animation) {
      final incoming = child.key == this.child.key;
      final offset = Tween<Offset>(
        begin: Offset(incoming ? 1 : -1, 0),
        end: Offset.zero,
      ).animate(animation);
      return ClipRect(
        child: SlideTransition(
          position: offset,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );
    },
    child: child,
  );
}
