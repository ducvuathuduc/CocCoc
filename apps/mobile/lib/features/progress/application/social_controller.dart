import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'preview_controller.dart';

const statusIds = {
  'cool',
  'party',
  'flex',
  'eyes',
  'popcorn',
  'english',
  'angry',
  'hundred',
  'poop',
  'trophy',
  'fries',
  'cat',
};
const premiumStatusIds = {'cool', 'party', 'flex', 'eyes'};
const suggestedFriends = ['Alex', 'Sam Lee'];
const feedPostIds = {'stores', 'restaurant', 'first-friend'};

class StatusState {
  const StatusState({this.selected, this.draft});
  final String? selected, draft;
}

final statusControllerProvider =
    NotifierProvider<StatusController, StatusState>(StatusController.new);

class StatusController extends Notifier<StatusState> {
  @override
  StatusState build() => const StatusState();
  bool unlocked(String? id) =>
      id == null ||
      (statusIds.contains(id) &&
          (!premiumStatusIds.contains(id) ||
              ref
                  .read(previewControllerProvider)
                  .purchases
                  .contains('status-$id')));
  void begin() =>
      state = StatusState(selected: state.selected, draft: state.selected);
  void choose(String id) {
    if (statusIds.contains(id)) {
      state = StatusState(selected: state.selected, draft: id);
    }
  }

  void cancel() => begin();
  bool save() {
    if (!unlocked(state.draft)) return false;
    state = StatusState(selected: state.draft, draft: state.draft);
    return true;
  }

  void clear() => state = const StatusState();
  bool purchaseSelected() =>
      state.draft != null &&
      ref.read(previewControllerProvider.notifier).buyStatusIcon(state.draft!);
}

class FeedState {
  const FeedState({
    this.selectedSuggestions = const {'Alex', 'Sam Lee'},
    this.liked = const {},
    this.comments = const {},
  });
  final Set<String> selectedSuggestions, liked;
  final Map<String, List<String>> comments;
}

final feedControllerProvider = NotifierProvider<FeedController, FeedState>(
  FeedController.new,
);

// Local social fixtures; no network, authoritative rewards or external messages.
class FeedController extends Notifier<FeedState> {
  @override
  FeedState build() => const FeedState();
  void toggleSuggestion(String name) {
    if (!suggestedFriends.contains(name)) return;
    final selected = {...state.selectedSuggestions};
    selected.contains(name) ? selected.remove(name) : selected.add(name);
    state = FeedState(
      selectedSuggestions: Set.unmodifiable(selected),
      liked: state.liked,
      comments: state.comments,
    );
  }

  int addSuggested() {
    var added = 0;
    for (final name in state.selectedSuggestions) {
      if (!ref.read(previewControllerProvider).following.contains(name)) {
        ref.read(previewControllerProvider.notifier).follow(name);
        added++;
      }
    }
    return added;
  }

  void like(String id) {
    if (!feedPostIds.contains(id)) return;
    final liked = {...state.liked};
    liked.contains(id) ? liked.remove(id) : liked.add(id);
    state = FeedState(
      selectedSuggestions: state.selectedSuggestions,
      liked: Set.unmodifiable(liked),
      comments: state.comments,
    );
  }

  String? comment(String id, String text) {
    if (!feedPostIds.contains(id)) return 'This post is unavailable.';
    final content = text.trim();
    if (content.isEmpty || content.length > 280) {
      return 'Write a comment between 1 and 280 characters.';
    }
    final comments = {
      ...state.comments,
      id: List<String>.unmodifiable([...?state.comments[id], content]),
    };
    state = FeedState(
      selectedSuggestions: state.selectedSuggestions,
      liked: state.liked,
      comments: Map.unmodifiable(comments),
    );
    return null;
  }
}
