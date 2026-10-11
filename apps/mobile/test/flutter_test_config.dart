import 'dart:async';

import 'package:cocenglish/core/design/duo_motion.dart';

/// Global test setup. Idle mascots loop forever in the app; in widget tests
/// they play one cycle so `pumpAndSettle` stays deterministic. Tests that
/// exercise looping itself reset [DuoMotion.debugSingleCycleLoops].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DuoMotion.debugSingleCycleLoops = true;
  await testMain();
}
