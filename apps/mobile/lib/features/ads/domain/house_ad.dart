class HouseAd {
  const HouseAd({
    this.title = "Here's a good one: Why did the chicken cross the playground?",
    this.body = 'Practice makes perfect.',
    this.cta = 'CONTINUE',
    this.skipAfter = const Duration(seconds: 5),
  });
  final String title, body, cta;
  final Duration skipAfter;
}
