import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/streak_widget.dart';

final streakWidgetsProvider =
    NotifierProvider<StreakWidgetsController, StreakWidgetMood>(
      StreakWidgetsController.new,
    );

class StreakWidgetsController extends Notifier<StreakWidgetMood> {
  @override
  StreakWidgetMood build() => StreakWidgetMood.ready;
  void select(StreakWidgetMood value) => state = value;
}
