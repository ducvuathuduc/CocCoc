enum EnergyRefillKind { recharge, ad, free }

class EnergyOffer {
  const EnergyOffer(
    this.kind,
    this.amount,
    this.title,
    this.action, {
    this.cost = 0,
  });
  final EnergyRefillKind kind;
  final int amount, cost;
  final String title, action;
}
