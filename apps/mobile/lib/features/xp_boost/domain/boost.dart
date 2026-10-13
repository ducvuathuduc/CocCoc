/// A presentation receipt; it never awards XP or computes an expiry locally.
class Boost {
  const Boost({required this.multiplier, required this.minutes});
  final int multiplier;
  final int minutes;
  String get multiplierLabel => 'x$multiplier';
  String get message =>
      'XP Boost activated! Earn ${multiplier == 2 ? 'double' : '$multiplier times'}\nXP for the next ';
  String get durationLabel => '$minutes ${minutes == 1 ? 'minute' : 'minutes'}';
  String get continueLabel => 'CONTINUE';
}

class BoostReward {
  const BoostReward({
    required this.itemId,
    required this.multiplier,
    required this.minutes,
  });
  final String itemId;
  final int multiplier;
  final int minutes;
}

class BoostCopy {
  const BoostCopy();
  String get emptyMessage => 'No XP Boost activated yet.';
  String get continueLabel => 'CONTINUE';
  String get failureMessage =>
      'We couldn’t activate your boost. Please try again.';
}
