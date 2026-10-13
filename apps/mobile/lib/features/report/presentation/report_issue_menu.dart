import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/design/reference_theme.dart';
import '../domain/issue_report.dart';

/// iOS-style "Report an issue" action list (Gummble sc_f2f569c1,
/// refs/gap/report_issue_menu.png; 1179 px = 393 dp).
///
/// Measured: panel x 33→1050 px (≈11 dp left, 340 dp wide), bottom 45 dp
/// above the screen edge, radius ≈24 dp; nine 48 dp pills 11 dp apart, black
/// 17 sp centred text; translucent frosted material over a washed screen.
/// The panel grows out of the report flag ([anchor]); without an anchor it
/// grows from its bottom-right corner.
Future<String?> showReportIssueMenu(
  BuildContext context, {
  required IssueReportContent content,
  Rect? anchor,
}) {
  final reduced = MediaQuery.disableAnimationsOf(context);
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: content.menuLabel,
    barrierColor: Colors.white.withValues(alpha: .45),
    transitionDuration: reduced ? Duration.zero : ReportMenuMotion.duration,
    pageBuilder: (_, _, _) => ReportIssueMenu(content: content, anchor: anchor),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: ReportMenuMotion.curve,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: .6, end: 1.0).animate(curved),
          alignment: Alignment.bottomRight,
          child: child,
        ),
      );
    },
  );
}

abstract final class ReportMenuMotion {
  // iOS context menus open with a short spring-like grow from their source.
  static const duration = Duration(milliseconds: 250);
  static const curve = Curves.easeOutBack;
}

class ReportIssueMenu extends StatelessWidget {
  const ReportIssueMenu({required this.content, this.anchor, super.key});
  final IssueReportContent content;
  final Rect? anchor;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 53).clamp(0.0, 340.0);
    const bottom = 45.0;
    return Stack(
      children: [
        Positioned(
          key: const ValueKey('report-issue-menu'),
          left: 11,
          width: width,
          bottom: bottom,
          top: MediaQuery.paddingOf(context).top + 16,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .9),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final category in content.categories)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 1,
                              vertical: 3.5,
                            ),
                            child: _Pill(
                              label: category,
                              onTap: () => Navigator.pop(context, category),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (anchor case final anchor?)
          Positioned(
            left: 11 + width - 1,
            top: anchor.center.dy - 9,
            child: CustomPaint(
              size: const Size(10, 18),
              painter: _ArrowPainter(),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: Colors.black.withValues(alpha: .06),
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17,
                  height: 1.25,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white.withValues(alpha: .8));
  }

  @override
  bool shouldRepaint(_ArrowPainter oldDelegate) => false;
}

/// "Issue successfully reported!" card (sc_2082f9ab): white, 2 dp #E5E5E5
/// border with a 4 dp bottom edge, radius 16, bold ink 17 sp, sitting just
/// above the feedback panel.
class IssueReportedToast extends StatelessWidget {
  const IssueReportedToast({required this.message, super.key});
  final String message;
  static const edge = Color(0xFFE5E5E5);
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      key: const ValueKey('issue-reported-toast'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      decoration: BoxDecoration(
        color: edge,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(bottom: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: ReferenceColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: edge, width: 2),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: ReferenceColors.ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}
