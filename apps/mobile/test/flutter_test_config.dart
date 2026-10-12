import 'dart:async';

import 'package:cocenglish/core/design/duo_motion.dart';
import 'package:cocenglish/features/progress/data/league_repository.dart';

/// Global test setup. Idle mascots loop forever in the app; in widget tests
/// they hold their first frame so `pumpAndSettle` stays deterministic. Tests that
/// exercise looping itself reset [DuoMotion.debugSingleCycleLoops]. The
/// mock league is pinned to its 8-learner reference cohort the same way.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  DuoMotion.debugSingleCycleLoops = true;
  debugPinReferenceLeague = true;
  await testMain();
}
