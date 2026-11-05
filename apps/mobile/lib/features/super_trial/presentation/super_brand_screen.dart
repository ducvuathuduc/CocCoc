import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/reference_art.dart';
import '../../../core/design/reference_widgets.dart';
import 'super_trial_screen.dart';

/// The CONTINUE frame preceding the trial, Gummble sc_02a1e078 (1179×2556).
/// Only the original wordmark and muted glyph are raster art; the CTA is native.
class SuperBrandScreen extends StatefulWidget {
  const SuperBrandScreen({super.key});
  static const route = '/super/brand';
  @override
  State<SuperBrandScreen> createState() => _SuperBrandScreenState();
}

class _SuperBrandScreenState extends State<SuperBrandScreen> {
  bool _continuing = false;

  Future<void> _continue() async {
    if (_continuing) return;
    setState(() => _continuing = true);
    final accepted = await context.push<bool>(SuperTrialScreen.route);
    if (!mounted) return;
    if (context.canPop()) {
      context.pop(accepted ?? false);
    } else {
      context.go(accepted == true ? '/super' : '/home');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF34305A),
    body: LayoutBuilder(
      builder: (context, box) {
        final scale = box.maxWidth / 1179;
        return Stack(
          children: [
            Positioned(
              left: 190 * scale,
              top: box.maxHeight * (1030 / 2556),
              width: 800 * scale,
              height: 430 * scale,
              child: Semantics(
                label: 'Super Duolingo',
                image: true,
                child: ReferenceArt(
                  const ArtRegion(
                    'gap-super-brand',
                    Rect.fromLTWH(190, 1030, 800, 430),
                  ),
                  width: 800 * scale,
                  height: 430 * scale,
                ),
              ),
            ),
            Positioned(
              right: 39 * scale,
              top: box.maxHeight * (248 / 2556),
              width: 100 * scale,
              height: 74 * scale,
              child: Semantics(
                label: 'Sound muted',
                image: true,
                child: ReferenceArt(
                  const ArtRegion(
                    'gap-super-brand',
                    Rect.fromLTWH(1040, 248, 100, 74),
                  ),
                  width: 100 * scale,
                  height: 74 * scale,
                ),
              ),
            ),
            Positioned(
              left: 48 * scale,
              right: 48 * scale,
              bottom: MediaQuery.paddingOf(context).bottom + 127 * scale,
              child: ReferenceButton(
                key: const ValueKey('super-brand-continue'),
                label: 'CONTINUE',
                onPressed: _continuing ? null : _continue,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF000437),
                edgeColor: const Color(0xFFD5D4DF),
                minHeight: 132 * scale,
                cornerRadius: 30 * scale,
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
