import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/avatar_configuration.dart';

class AvatarState {
  AvatarState({
    required Map<String, double> saved,
    required Map<String, double> draft,
    required this.catalog,
    this.hasAvatar = false,
    this.tabIndex = 0,
  }) : saved = UnmodifiableMapView(saved),
       draft = UnmodifiableMapView(draft);

  final Map<String, double> saved;
  final Map<String, double> draft;
  final bool hasAvatar;
  final int tabIndex;
  final AvatarCatalog catalog;
  bool get dirty => !mapEquals(saved, draft);

  AvatarState copyWith({
    Map<String, double>? saved,
    Map<String, double>? draft,
    bool? hasAvatar,
    int? tabIndex,
  }) => AvatarState(
    saved: saved ?? this.saved,
    draft: draft ?? this.draft,
    hasAvatar: hasAvatar ?? this.hasAvatar,
    tabIndex: tabIndex ?? this.tabIndex,
    catalog: catalog,
  );
}

final avatarControllerProvider =
    NotifierProvider<AvatarController, AvatarState>(AvatarController.new);

class AvatarController extends Notifier<AvatarState> {
  @override
  AvatarState build() => AvatarState(
    saved: const {},
    draft: const {},
    catalog: AvatarCatalog.empty(),
  );

  void attachCatalog(AvatarCatalog catalog) {
    if (identical(state.catalog, catalog)) return;
    if (state.catalog.tabs.isEmpty) {
      state = AvatarState(
        saved: catalog.defaults,
        draft: catalog.defaults,
        catalog: catalog,
        hasAvatar: state.hasAvatar,
      );
      return;
    }
    state = AvatarState(
      saved: state.saved,
      draft: state.draft,
      catalog: catalog,
      hasAvatar: state.hasAvatar,
      tabIndex: state.tabIndex.clamp(0, catalog.tabs.length - 1),
    );
  }

  void begin() {
    state = state.copyWith(draft: state.saved, tabIndex: 0);
  }

  void cancel() {
    state = state.copyWith(draft: state.saved, tabIndex: 0);
  }

  bool save() {
    if (!state.dirty) return false;
    state = state.copyWith(saved: state.draft, hasAvatar: true);
    return true;
  }

  void selectTab(int index) {
    if (index < 0 || index >= state.catalog.tabs.length) return;
    state = state.copyWith(tabIndex: index);
  }

  bool select(String stateName, double value) {
    if (!state.catalog.allows(stateName, value)) return false;
    if (state.draft[stateName] == value) return true;
    state = state.copyWith(
      draft: <String, double>{...state.draft, stateName: value},
    );
    return true;
  }
}
