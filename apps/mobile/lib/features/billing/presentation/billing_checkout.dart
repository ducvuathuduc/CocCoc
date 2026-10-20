import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/reference_theme.dart';
import '../../../core/design/reference_widgets.dart';
import '../application/billing_controller.dart';
import '../domain/billing_models.dart';

Future<bool> showBillingCheckout(BuildContext context, String selection) async {
  final product = BillingProduct.forSelection(selection);
  if (product == null) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plan unavailable'),
        content: const Text(
          'Family checkout is not in the current billing catalog. Choose an individual plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }
  return await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) => BillingCheckout(product: product),
      ) ??
      false;
}

class BillingCheckout extends ConsumerStatefulWidget {
  const BillingCheckout({required this.product, super.key});
  final BillingProduct product;
  @override
  ConsumerState<BillingCheckout> createState() => _BillingCheckoutState();
}

class _BillingCheckoutState extends ConsumerState<BillingCheckout> {
  DemoPaymentOutcome _outcome = DemoPaymentOutcome.success;
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);
    final pending = state.snapshot.receipt?.state == 'PENDING';
    return PopScope(
      canPop: !state.busy,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.product.title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close checkout',
                    onPressed: state.busy
                        ? null
                        : () => Navigator.pop(context, false),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.product.price,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'DEMO PAYMENT • No real money is charged. Prices are illustrative. No store trial or real renewal is started.',
                style: TextStyle(color: ReferenceColors.muted),
              ),
              const SizedBox(height: 14),
              if (!pending) ...[
                const Text('Choose a demo payment result:'),
                for (final option in DemoPaymentOutcome.values)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(switch (option) {
                      DemoPaymentOutcome.success => 'Successful payment',
                      DemoPaymentOutcome.pending => 'Pending payment',
                      DemoPaymentOutcome.declined => 'Declined payment',
                    }),
                    leading: Icon(
                      _outcome == option
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    onTap: state.busy
                        ? null
                        : () => setState(() => _outcome = option),
                  ),
              ],
              if (state.message != null)
                Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(state.message!),
                  ),
                ),
              ReferenceButton(
                label: state.busy
                    ? 'VERIFYING…'
                    : pending
                    ? 'CHECK PAYMENT STATUS'
                    : 'CONFIRM DEMO PAYMENT',
                onPressed: state.busy || !state.loaded
                    ? null
                    : () async {
                        final ok = pending
                            ? await controller.checkPending()
                            : await controller.purchase(
                                widget.product,
                                _outcome,
                              );
                        if (!context.mounted || !ok) return;
                        final snapshot = ref
                            .read(billingControllerProvider)
                            .snapshot;
                        if (snapshot.selection != null &&
                            snapshot.receipt?.state != 'PENDING') {
                          Navigator.pop(context, true);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => Navigator.pop(context, false),
                child: const Text('NOT NOW'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BillingManagement extends ConsumerWidget {
  const BillingManagement({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(billingControllerProvider);
    final controller = ref.read(billingControllerProvider.notifier);
    final receipt = state.snapshot.receipt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Demo billing • No real charges',
          textAlign: TextAlign.center,
        ),
        if (receipt != null) ...[
          const SizedBox(height: 8),
          Text('Order: ${receipt.id}'),
          Text('Status: ${receipt.state}'),
          if (receipt.expiresAt != null)
            Text(
              'Access until: ${receipt.expiresAt!.toLocal().toIso8601String().split('T').first}',
            ),
          if (receipt.state != 'PENDING')
            Text(
              receipt.autoRenew ? 'Demo renewal enabled' : 'Renewal disabled',
            ),
        ],
        if (state.message != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Semantics(liveRegion: true, child: Text(state.message!)),
          ),
        if (receipt?.state == 'PENDING')
          ReferenceButton(
            label: 'CHECK PAYMENT STATUS',
            onPressed: state.busy ? null : controller.checkPending,
          ),
        const SizedBox(height: 12),
        ReferenceButton(
          label: state.busy ? 'CHECKING…' : 'RESTORE SUBSCRIPTION',
          outlined: true,
          onPressed: state.busy ? null : controller.restore,
        ),
      ],
    );
  }
}
