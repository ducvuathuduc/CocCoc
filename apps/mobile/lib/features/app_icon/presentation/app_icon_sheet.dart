import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_theme.dart';
import '../../learning/presentation/learning_visuals.dart';
import '../application/app_icon_controller.dart';
import '../domain/app_icon_choice.dart';

// Colors sampled from Gummble "Changing app icon" refs.
const _ink = Color(0xFF4B4B4B);
const _border = Color(0xFFE5E5E5);
const _blue = Color(0xFF1CB0F6);
const _streakBand = Color(0xFFFF9700);
const _maxBandStart = Color(0xFF33F0ED);
const _maxBandEnd = Color(0xFF2DF2C0);
const _alertFill = Color(0xFFEDEEEE);
const _alertButton = Color(0xFFCACBCB);

abstract final class AppIconArt {
  static const streakSociety = ArtRegion(
    'app-icon-select',
    Rect.fromLTWH(148, 1742, 318, 318),
  );
  static const max = ArtRegion(
    'app-icon-select',
    Rect.fromLTWH(713, 1742, 320, 320),
  );
  // Default Duo launcher: the green splash face.
  static const original = ArtRegion('01', Rect.fromLTWH(330, 974, 520, 520));

  static ArtRegion of(AppIconChoice c) => switch (c) {
    AppIconChoice.original => original,
    AppIconChoice.streakSociety => streakSociety,
    AppIconChoice.max => max,
  };
}

/// "Select an app icon!" sheet (ref Changing_app_icon/01).
Future<void> showAppIconSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => AppIconSheet(
        onChosen: (choice) {
          Navigator.pop(sheet);
          showAppIconChangedDialog(context, choice);
        },
      ),
    );

class AppIconSheet extends ConsumerWidget {
  const AppIconSheet({required this.onChosen, super.key});
  final ValueChanged<AppIconChoice> onChosen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(appIconControllerProvider);
    final vm = ref.read(appIconControllerProvider.notifier);
    Future<void> pick(AppIconChoice c) async {
      await vm.select(c);
      onChosen(c);
    }

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: ReferenceColors.disabled,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 46),
            Text(
              'Select an app icon!',
              textAlign: TextAlign.center,
              style: headingStyle.copyWith(fontSize: 23, color: _ink),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IconCard(
                    choice: AppIconChoice.streakSociety,
                    selected: selected == AppIconChoice.streakSociety,
                    band: const BoxDecoration(color: _streakBand),
                    label: const Text(
                      'STREAK SOCIETY',
                      maxLines: 1,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    onTap: () => pick(AppIconChoice.streakSociety),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _IconCard(
                    choice: AppIconChoice.max,
                    selected: selected == AppIconChoice.max,
                    band: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_maxBandStart, _maxBandEnd],
                      ),
                    ),
                    label: Transform(
                      transform: Matrix4.skewX(-0.25),
                      alignment: Alignment.center,
                      child: const Text(
                        'MAX',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    onTap: () => pick(AppIconChoice.max),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 50),
            TextButton(
              key: const ValueKey('restore-original-icon'),
              onPressed: () => pick(AppIconChoice.original),
              child: const Text(
                'RESTORE ORIGINAL ICON',
                style: TextStyle(
                  color: _blue,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _IconCard extends StatefulWidget {
  const _IconCard({
    required this.choice,
    required this.selected,
    required this.band,
    required this.label,
    required this.onTap,
  });
  final AppIconChoice choice;
  final bool selected;
  final BoxDecoration band;
  final Widget label;
  final VoidCallback onTap;
  @override
  State<_IconCard> createState() => _IconCardState();
}

class _IconCardState extends State<_IconCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final border = widget.selected ? _blue : _border;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${widget.choice.label} app icon',
      child: GestureDetector(
        key: ValueKey('app-icon-${widget.choice.name}'),
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedPadding(
          duration: motionDuration(context, 100),
          padding: EdgeInsets.only(top: _pressed ? 3 : 0),
          child: AnimatedContainer(
            duration: motionDuration(context, 120),
            height: 222,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border(
                top: BorderSide(color: border, width: 2),
                left: BorderSide(color: border, width: 2),
                right: BorderSide(color: border, width: 2),
                bottom: BorderSide(color: border, width: _pressed ? 2 : 4),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 35,
                  width: double.infinity,
                  decoration: widget.band,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: FittedBox(fit: BoxFit.scaleDown, child: widget.label),
                ),
                Expanded(
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ReferenceArt(
                          AppIconArt.of(widget.choice),
                          width: 115,
                          height: 115,
                        ),
                        if (widget.selected)
                          const Positioned(
                            right: -8,
                            top: -8,
                            child: _SelectedBadge(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();
  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(
      color: _blue,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
    ),
    child: const Icon(Icons.check_rounded, color: Colors.white, size: 17),
  );
}

/// iOS-style confirmation the OS shows after an alternate icon is applied
/// (ref Changing_app_icon/02).
Future<void> showAppIconChangedDialog(
  BuildContext context,
  AppIconChoice choice,
) => showDialog<void>(
  context: context,
  barrierColor: Colors.black.withValues(alpha: .2),
  builder: (dialog) =>
      AppIconChangedDialog(choice: choice, onOk: () => Navigator.pop(dialog)),
);

class AppIconChangedDialog extends StatelessWidget {
  const AppIconChangedDialog({
    required this.choice,
    required this.onOk,
    super.key,
  });
  final AppIconChoice choice;
  final VoidCallback onOk;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: _alertFill,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 40),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(8, 22, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ReferenceArt(
                  AppIconArt.of(choice),
                  width: 66,
                  height: 66,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'You have changed the icon for “Duolingo”.',
                    style: TextStyle(
                      fontSize: 18.5,
                      height: 1.3,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: TextButton(
              onPressed: onOk,
              style: TextButton.styleFrom(
                backgroundColor: _alertButton.withValues(alpha: .55),
                foregroundColor: Colors.black,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                'OK',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
