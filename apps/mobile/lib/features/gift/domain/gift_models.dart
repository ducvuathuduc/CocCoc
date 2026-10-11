class GiftPlan {
  const GiftPlan({
    required this.id,
    required this.name,
    required this.duration,
    required this.priceLabel,
  });
  final String id, name, duration, priceLabel;

  /// Footer line on the note screen, e.g.
  /// "$95.99 for 1 year of Super. No auto-renewal".
  String get footer => '$priceLabel for $duration of $name. No auto-renewal';
}

class GiftRecipient {
  const GiftRecipient({
    required this.id,
    required this.name,
    required this.username,
  });
  final String id, name, username;
  String get initial => name.isEmpty ? '?' : name[0].toUpperCase();
}

class GiftFaq {
  const GiftFaq(this.question, this.answer);
  final String question, answer;
}

class GiftOrder {
  const GiftOrder({
    required this.id,
    required this.plan,
    required this.recipient,
    required this.note,
  });
  final String id;
  final GiftPlan plan;
  final GiftRecipient recipient;
  final String note;
}
