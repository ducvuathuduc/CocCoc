class HouseAd {
  const HouseAd({
    this.title = "Here's a good one: Why did the chicken cross the playground?",
    this.body = 'Practice makes perfect.',
    this.cta = 'CONTINUE',
    this.retryLabel = 'TRY AGAIN',
    this.closeLabel = 'CLOSE',
    this.skipLabel = 'Skip ad',
    this.muteLabel = 'Mute ad',
    this.unmuteLabel = 'Unmute ad',
    this.skipAfter = const Duration(seconds: 5),
  });
  final String title,
      body,
      cta,
      retryLabel,
      closeLabel,
      skipLabel,
      muteLabel,
      unmuteLabel;
  String countdownLabel(int seconds) => 'Ad: $seconds seconds remaining';
  final Duration skipAfter;
}
