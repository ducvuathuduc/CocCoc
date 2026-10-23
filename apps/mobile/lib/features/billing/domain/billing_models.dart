class BillingProduct {
  const BillingProduct(
    this.id,
    this.selection,
    this.title,
    this.price,
    this.days,
  );
  final String id, selection, title, price;
  final int days;
  bool get isMax => id.startsWith('max');
  static const catalog = [
    BillingProduct(
      'super_family',
      'family',
      'Super Family Annual',
      '\$119.99 / year',
      365,
    ),
    BillingProduct(
      'max_family',
      'max-family',
      'Max Family Annual',
      '\$239.99 / year',
      365,
    ),
    BillingProduct(
      'super_monthly',
      'monthly',
      'Super Monthly',
      '\$12.99 / month',
      30,
    ),
    BillingProduct(
      'super_annual',
      'individual',
      'Super Annual',
      '\$83.99 / year',
      365,
    ),
    BillingProduct(
      'max_annual',
      'max-individual',
      'Max Annual',
      '\$167.99 / year',
      365,
    ),
  ];
  static BillingProduct? forSelection(String? selection) {
    for (final product in catalog) {
      if (product.selection == selection) return product;
    }
    return null;
  }
}

enum DemoPaymentOutcome { success, pending, declined }

class BillingReceipt {
  const BillingReceipt({
    required this.id,
    required this.productId,
    required this.state,
    required this.expiresAt,
    required this.autoRenew,
  });
  final String id, productId, state;
  final DateTime? expiresAt;
  final bool autoRenew;
  bool activeAt(DateTime now) =>
      ['ACTIVE', 'GRACE', 'CANCELED'].contains(state) &&
      expiresAt != null &&
      now.isBefore(expiresAt!);
  Map<String, Object?> toJson() => {
    'id': id,
    'productId': productId,
    'state': state,
    'expiresAt': expiresAt?.toUtc().toIso8601String(),
    'autoRenew': autoRenew,
  };
  factory BillingReceipt.fromJson(Map<String, dynamic> json) => BillingReceipt(
    id: json['id'] as String,
    productId: json['productId'] as String,
    state: json['state'] as String,
    expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    autoRenew: json['autoRenew'] == true,
  );
}

class BillingSnapshot {
  const BillingSnapshot({this.selection, this.receipt, this.activeUntil});
  final String? selection;
  final BillingReceipt? receipt;
  final DateTime? activeUntil;
}
