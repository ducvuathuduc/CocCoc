import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/connectivity_provider.dart';

class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({required this.offline, super.key});
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = offline
        ? Semantics(
            liveRegion: true,
            child: Container(
              width: double.infinity,
              // offline_banner.png (20,200), the flat banner background.
              color: const Color(0xFFCCCCCC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                  Text(
                    ref.watch(connectivityCopyProvider).offlineCaption,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          )
        : const SizedBox(width: double.infinity);
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

/// Washes inactive path art to the pale grey in offline_banner.png (350,1080).
class OfflinePathTint extends StatelessWidget {
  const OfflinePathTint({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColorFiltered(
    colorFilter: ColorFilter.mode(
      Colors.white.withValues(alpha: .65),
      BlendMode.srcATop,
    ),
    child: ColorFiltered(
      colorFilter: const ColorFilter.matrix([
        .2126,
        .7152,
        .0722,
        0,
        0,
        .2126,
        .7152,
        .0722,
        0,
        0,
        .2126,
        .7152,
        .0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: child,
    ),
  );
}
