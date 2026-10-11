import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../learning/presentation/learning_visuals.dart';
import '../domain/notification_models.dart';

/// Colors sampled from refs6/Customizing_reminders + Turning_off_notifications.
abstract final class NotifColors {
  static const ink = Color(0xFF4B4B4B);
  static const muted = Color(0xFF777777);
  static const line = Color(0xFFE5E5E5);
  static const chevron = Color(0xFFAFAFAF);
  static const blue = LearningColors.blue; // 1CB0F6
  static const chipFill = Color(0xFFDDF4FF);
  static const chipBorder = Color(0xFF85D8FF);
  static const pickerBand = Color(0xFFF4F4F5);
  static const disabledText = Color(0xFFAFAFAF);
}

const notifRowStyle = TextStyle(
  fontSize: 20,
  color: NotifColors.ink,
  height: 1.2,
  letterSpacing: 0.2,
);

/// Back-arrow header used by Notifications sub-pages (refs show an arrow,
/// not the close X of [LearningHeader]).
class NotifHeader extends StatelessWidget {
  const NotifHeader({required this.title, super.key});
  final String title;
  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsets.only(top: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: NotifColors.line, width: 2)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Back',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: const Icon(
            Icons.arrow_back,
            size: 28,
            color: NotifColors.chevron,
          ),
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: NotifColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 52),
      ],
    ),
  );
}

class NotifPage extends StatelessWidget {
  const NotifPage({
    required this.title,
    required this.children,
    this.dimmed = false,
    super.key,
  });
  final String title;
  final List<Widget> children;
  final bool dimmed;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      bottom: false,
      child: Column(
        children: [
          NotifHeader(title: title),
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 17, 16, 32),
                  children: children,
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: dimmed ? 1 : 0,
                      child: const ColoredBox(color: Color(0x33000000)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Rounded bordered card whose rows are separated by 2px lines.
class NotifCard extends StatelessWidget {
  const NotifCard({required this.rows, super.key});
  final List<Widget> rows;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: NotifColors.line, width: 2),
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0)
            const Divider(height: 2, thickness: 2, color: NotifColors.line),
          rows[i],
        ],
      ],
    ),
  );
}

/// Square Push / Email toggle with a Duolingo 3D bottom edge that presses
/// down on touch.
class ChannelChip extends StatefulWidget {
  const ChannelChip({
    required this.channel,
    required this.on,
    required this.onTap,
    super.key,
  });
  final NotificationChannel channel;
  final bool on;
  final VoidCallback onTap;
  @override
  State<ChannelChip> createState() => _ChannelChipState();
}

class _ChannelChipState extends State<ChannelChip> {
  bool down = false;
  static const _edge = 3.0;
  @override
  Widget build(BuildContext context) {
    final on = widget.on;
    final border = on ? NotifColors.chipBorder : NotifColors.line;
    final iconColor = on ? NotifColors.blue : NotifColors.line;
    final push = widget.channel == NotificationChannel.push;
    return Semantics(
      button: true,
      toggled: on,
      label: push ? 'Push' : 'Email',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => down = true),
        onTapCancel: () => setState(() => down = false),
        onTapUp: (_) => setState(() => down = false),
        onTap: widget.onTap,
        child: SizedBox(
          width: 30,
          height: 32,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: EdgeInsets.only(top: down ? _edge : 0),
            decoration: BoxDecoration(
              color: on ? NotifColors.chipFill : Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border(
                top: BorderSide(color: border, width: 2),
                left: BorderSide(color: border, width: 2),
                right: BorderSide(color: border, width: 2),
                bottom: BorderSide(color: border, width: down ? 2 : 2 + _edge),
              ),
            ),
            alignment: Alignment.center,
            child: push
                ? _PhoneGlyph(color: iconColor)
                : CustomPaint(
                    size: const Size(19, 14),
                    painter: _EnvelopePainter(iconColor),
                  ),
          ),
        ),
      ),
    );
  }
}

class _EnvelopePainter extends CustomPainter {
  const _EnvelopePainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(1.5),
    );
    canvas.drawRRect(r, Paint()..color = color);
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    final w = size.width, h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(1.5, 1.5)
        ..lineTo(w / 2, h * 0.58)
        ..lineTo(w - 1.5, 1.5),
      line,
    );
    canvas.drawLine(Offset(1.5, h - 1.5), Offset(w * 0.38, h * 0.48), line);
    canvas.drawLine(Offset(w - 1.5, h - 1.5), Offset(w * 0.62, h * 0.48), line);
  }

  @override
  bool shouldRepaint(_EnvelopePainter old) => old.color != color;
}

class _PhoneGlyph extends StatelessWidget {
  const _PhoneGlyph({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 12,
    height: 19,
    decoration: BoxDecoration(
      border: Border.all(color: color, width: 2),
      borderRadius: BorderRadius.circular(2.5),
    ),
    child: Column(
      children: [
        const SizedBox(height: 1),
        Container(width: 4, height: 1.5, color: color),
        const Spacer(),
        Container(
          width: 2,
          height: 2,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 1),
      ],
    ),
  );
}

/// Duolingo pill switch: rounded-square thumb sliding over a pill track.
class DuoSwitch extends StatelessWidget {
  const DuoSwitch({required this.value, required this.onChanged, super.key});
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Semantics(
    toggled: value,
    child: GestureDetector(
      key: const ValueKey('smart-scheduling-switch'),
      onTap: () => onChanged(!value),
      child: SizedBox(
        width: 56,
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 25,
              decoration: BoxDecoration(
                color: value ? NotifColors.blue : NotifColors.line,
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 30,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: value ? NotifColors.blue : NotifColors.line,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// iOS-style wheel sheet from Customizing_reminders/04-05: hour, :00/:30,
/// AM/PM with a light rounded selection band and a DONE action.
Future<ReminderTime?> showReminderTimePicker(
  BuildContext context,
  ReminderTime initial,
) => showModalBottomSheet<ReminderTime>(
  context: context,
  backgroundColor: Colors.white,
  // The page dims itself below its header (see NotifPage.dimmed), as in
  // Customizing_reminders/04 where the header stays white.
  barrierColor: Colors.transparent,
  shape: const RoundedRectangleBorder(),
  builder: (_) => _ReminderTimeSheet(initial: initial),
);

class _ReminderTimeSheet extends StatefulWidget {
  const _ReminderTimeSheet({required this.initial});
  final ReminderTime initial;
  @override
  State<_ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<_ReminderTimeSheet> {
  late int hour12 = widget.initial.hour % 12 == 0
      ? 12
      : widget.initial.hour % 12;
  late int half = widget.initial.minute >= 30 ? 1 : 0;
  late bool pm = widget.initial.hour >= 12;

  ReminderTime get value =>
      ReminderTime((hour12 % 12) + (pm ? 12 : 0), half * 30);

  static const _style = TextStyle(
    fontFamily: 'DuolingoSans',
    fontSize: 22,
    color: NotifColors.ink,
  );

  Widget _wheel({
    required Key key,
    required int count,
    required int initial,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
    bool looping = true,
  }) => SizedBox(
    width: 62,
    child: CupertinoPicker(
      key: key,
      itemExtent: 31,
      looping: looping,
      diameterRatio: 1.25,
      squeeze: 1.0,
      useMagnifier: true,
      magnification: 1.3,
      selectionOverlay: const SizedBox.shrink(),
      scrollController: FixedExtentScrollController(initialItem: initial),
      onSelectedItemChanged: onChanged,
      children: [
        for (var i = 0; i < count; i++)
          Center(child: Text(label(i), style: _style)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: 245,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey('reminder-time-done'),
              onPressed: () => Navigator.pop(context, value),
              child: const Text(
                'DONE',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: NotifColors.ink,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 33,
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: BoxDecoration(
                    color: NotifColors.pickerBand,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _wheel(
                      key: const ValueKey('picker-hour'),
                      count: 12,
                      initial: hour12 - 1,
                      label: (i) => '${i + 1}',
                      onChanged: (i) => setState(() => hour12 = i + 1),
                    ),
                    _wheel(
                      key: const ValueKey('picker-minute'),
                      count: 2,
                      initial: half,
                      label: (i) => i == 0 ? '00' : '30',
                      onChanged: (i) => setState(() => half = i % 2),
                    ),
                    _wheel(
                      key: const ValueKey('picker-period'),
                      count: 2,
                      initial: pm ? 1 : 0,
                      looping: false,
                      label: (i) => i == 0 ? 'AM' : 'PM',
                      onChanged: (i) => setState(() => pm = i == 1),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
