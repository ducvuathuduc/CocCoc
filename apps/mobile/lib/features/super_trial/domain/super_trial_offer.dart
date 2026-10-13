/// Copy for the Super free-trial interstitial shown after a Free user's ad
/// (Gummble sc_e4a392e0 / earn_heart_08). The bubble line is split so the
/// reminder lead time can be highlighted.
class SuperTrialOffer {
  const SuperTrialOffer({
    this.title = 'Get a 7-day free trial of Super Duolingo',
    this.bubbleLead = 'We’ll notify you ',
    this.bubbleHighlight = '2 days',
    this.bubbleTail = ' before your trial ends',
    this.footnote = 'Easy to cancel, no penalties or fees',
    this.acceptLabel = r'TRY FOR $0.00',
    this.declineLabel = 'NO THANKS',
  });
  final String title,
      bubbleLead,
      bubbleHighlight,
      bubbleTail,
      footnote,
      acceptLabel,
      declineLabel;
  String get bubbleText => '$bubbleLead$bubbleHighlight$bubbleTail';
}

enum SuperTrialChoice { accepted, declined }
