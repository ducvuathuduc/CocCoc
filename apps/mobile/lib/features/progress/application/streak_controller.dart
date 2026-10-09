import 'package:flutter_riverpod/flutter_riverpod.dart';

enum FriendStreakStatus { pending, active }

class StreakPerson {
  const StreakPerson(this.id, this.name);
  final String id, name;
}

const streakPeople = [
  StreakPerson('alex', 'Alex Smith'),
  StreakPerson('maria', 'Maria Garcia'),
  StreakPerson('lucas', 'Lucas Chen'),
  StreakPerson('anna', 'Anna Kim'),
  StreakPerson('samira', 'Samira Ali'),
];

final streakClockProvider = Provider<DateTime>((ref) => DateTime.now());

enum StreakAppearance { ordinary, frozen, perfect }

class StreakFixture {
  const StreakFixture({
    required this.days,
    required this.month,
    required this.practiced,
    this.frozen = const {},
    this.appearance = StreakAppearance.ordinary,
  });
  final int days;
  final DateTime month;
  final Set<int> practiced, frozen;
  final StreakAppearance appearance;
}

// Archive-only render fixtures; these never update the learning ledger.
final streakFixtureProvider = Provider<StreakFixture?>((ref) => null);

class StreakState {
  const StreakState({
    required this.month,
    this.friends = const {},
    this.incoming = const {'alex'},
    this.showFriends = false,
    this.editing = false,
  });
  final DateTime month;
  final Map<String, FriendStreakStatus> friends;
  final Set<String> incoming;
  final bool showFriends, editing;
  int get remaining => 5 - friends.length;
  StreakState copyWith({
    DateTime? month,
    Map<String, FriendStreakStatus>? friends,
    Set<String>? incoming,
    bool? showFriends,
    bool? editing,
  }) => StreakState(
    month: month ?? this.month,
    friends: Map.unmodifiable(friends ?? this.friends),
    incoming: Set.unmodifiable(incoming ?? this.incoming),
    showFriends: showFriends ?? this.showFriends,
    editing: editing ?? this.editing,
  );
}

final streakControllerProvider =
    NotifierProvider<StreakController, StreakState>(StreakController.new);

class StreakController extends Notifier<StreakState> {
  @override
  StreakState build() {
    final now =
        ref.read(streakFixtureProvider)?.month ??
        ref.read<DateTime>(streakClockProvider);
    return StreakState(month: DateTime(now.year, now.month));
  }

  bool accept(String id) {
    if (!state.incoming.contains(id) ||
        state.remaining <= 0 ||
        state.friends.containsKey(id)) {
      return false;
    }
    state = state.copyWith(
      friends: {...state.friends, id: FriendStreakStatus.active},
      incoming: {...state.incoming}..remove(id),
    );
    return true;
  }

  bool decline(String id) {
    if (!state.incoming.contains(id)) return false;
    state = state.copyWith(incoming: {...state.incoming}..remove(id));
    return true;
  }

  bool invite(String id) {
    if (!streakPeople.any((person) => person.id == id) ||
        state.remaining <= 0 ||
        state.incoming.contains(id) ||
        state.friends.containsKey(id)) {
      return false;
    }
    state = state.copyWith(
      friends: {...state.friends, id: FriendStreakStatus.pending},
    );
    return true;
  }

  bool remove(String id) {
    if (!state.friends.containsKey(id)) return false;
    state = state.copyWith(friends: {...state.friends}..remove(id));
    return true;
  }

  void changeMonth(int offset) {
    if (offset != -1 && offset != 1) return;
    final month = DateTime(state.month.year, state.month.month + offset);
    if (month.year < 2020 || month.year > 2035) return;
    state = state.copyWith(month: month);
  }

  void selectFriends(bool value) =>
      state = state.copyWith(showFriends: value, editing: false);
  void toggleEdit() {
    if (state.showFriends) state = state.copyWith(editing: !state.editing);
  }
}
