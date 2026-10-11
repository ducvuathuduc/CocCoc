import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_icon_repository.dart';
import '../domain/app_icon_choice.dart';

/// Selected launcher icon; reads and writes through [AppIconRepository].
class AppIconController extends Notifier<AppIconChoice> {
  AppIconRepository get _repo => ref.read(appIconRepositoryProvider);

  @override
  AppIconChoice build() => _repo.current;

  Future<void> select(AppIconChoice choice) async {
    state = choice;
    await _repo.setIcon(choice);
  }

  Future<void> restoreOriginal() => select(AppIconChoice.original);
}

final appIconControllerProvider =
    NotifierProvider<AppIconController, AppIconChoice>(AppIconController.new);
