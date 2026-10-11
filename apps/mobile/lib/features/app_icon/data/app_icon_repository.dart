import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_icon_choice.dart';

/// Persists the launcher icon the learner picked. A platform implementation
/// (iOS `setAlternateIconName`, Android activity-alias) can replace the mock
/// by overriding [appIconRepositoryProvider].
abstract class AppIconRepository {
  AppIconChoice get current;
  Future<void> setIcon(AppIconChoice choice);
}

class MockAppIconRepository implements AppIconRepository {
  MockAppIconRepository({
    AppIconChoice initial = AppIconChoice.original,
    this.latency = Duration.zero,
  }) : _current = initial;

  final Duration latency;
  AppIconChoice _current;

  /// Every icon written, in order; lets tests assert persistence.
  final List<AppIconChoice> writes = [];

  @override
  AppIconChoice get current => _current;

  @override
  Future<void> setIcon(AppIconChoice choice) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    _current = choice;
    writes.add(choice);
  }
}

final appIconRepositoryProvider = Provider<AppIconRepository>(
  (ref) => MockAppIconRepository(),
);
